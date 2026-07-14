## VoiceInput — Speech-to-text via microphone recording + Lemonade whisper.cpp.
##
## Handles:
##   • Microphone recording (Godot 4 AudioStreamMicrophone + AudioEffectCapture)
##   • WAV encoding of captured PCM samples
##   • HTTP transcription request to Lemonade /v1/audio/transcriptions
##   • State management: idle → recording → transcribing → idle
##
## Usage:
##   var voice = VoiceInput.new()
##   add_child(voice)
##   voice.transcription_ready.connect(_on_transcription)
##   voice.error_occurred.connect(_on_error)
##   voice.start_recording()
##   voice.stop_and_transcribe()

extends Node


# ── Signals ─────────────────────────────────────────────────────

## Emitted when transcription succeeds with the transcribed text.
signal transcription_ready(text: String)

## Emitted when an error occurs (permission, recording, network, etc.).
signal error_occurred(message: String)

## Emitted when recording starts.
signal recording_started()

## Emitted when recording stops (before transcription).
signal recording_stopped()

## Emitted when transcription is in progress.
signal transcribing()

## Emitted when the system returns to idle state.
signal idle()


# ── States ──────────────────────────────────────────────────────
const STATE_IDLE := "idle"
const STATE_RECORDING := "recording"
const STATE_TRANSCRIBING := "transcribing"

var _state: String = STATE_IDLE


# ── Recording config ────────────────────────────────────────────
## Whisper expects 16000 Hz mono. We capture at the audio server's native
## sample rate and resample to 16kHz before encoding the WAV.
const TARGET_SAMPLE_RATE := 16000
const CHANNELS := 1
const BITS_PER_SAMPLE := 16

## Max recording duration in seconds (prevents runaway recordings)
const MAX_RECORDING_SECONDS := 30

## Minimum recording duration in seconds (skip if too short)
const MIN_RECORDING_SECONDS := 0.5


# ── Internal ────────────────────────────────────────────────────
var _http_client: Node
var _pcm_buffer: PackedFloat32Array = []
var _input_available: bool = false
var _microphone: AudioStreamMicrophone
var _audio_player: AudioStreamPlayer
var _capture_effect: AudioEffectCapture
var _capture_sample_rate: int = 48000


func _ready() -> void:
	_capture_sample_rate = AudioServer.get_mix_rate()

	# Add AudioEffectCapture to the Master bus so we can read mic samples.
	_capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, _capture_effect, 0)

	# Set up AudioStreamMicrophone + AudioStreamPlayer on the Master bus.
	_microphone = AudioStreamMicrophone.new()
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _microphone
	_audio_player.bus = "Master"
	add_child(_audio_player)

	_check_input_available()


## Check if audio input is available on this platform.
func _check_input_available() -> void:
	_input_available = true
	print("[VoiceInput] AudioStreamMicrophone initialized (capture rate: %d Hz)" % _capture_sample_rate)


## Whether voice input is supported on this platform/device.
func is_available() -> bool:
	return _input_available


## Current state string.
func get_state() -> String:
	return _state


## Set the HTTP client used for transcription requests.
func set_http_client(client: Node) -> void:
	_http_client = client
	if _http_client != null:
		_http_client.transcription_completed.connect(_on_transcription_completed)


# ── Public API ──────────────────────────────────────────────────

## Start recording from the microphone.
func start_recording() -> void:
	if not _input_available:
		error_occurred.emit("No microphone input available")
		return

	if _state == STATE_RECORDING:
		return

	_state = STATE_RECORDING
	_pcm_buffer.clear()
	# Drain any leftover frames from a previous session
	while _capture_effect.get_frames_available() > 0:
		_capture_effect.get_buffer(4096)
	recording_started.emit()

	_audio_player.play()
	print("[VoiceInput] Recording started")


func _process(_delta: float) -> void:
	if _state == STATE_RECORDING:
		_capture_frame()


## Stop recording and send audio for transcription.
func stop_and_transcribe() -> void:
	if _state != STATE_RECORDING:
		return

	_audio_player.stop()

	_state = STATE_TRANSCRIBING
	recording_stopped.emit()
	transcribing.emit()

	# Resample from capture rate to Whisper's expected 16kHz
	var resampled = _resample(_pcm_buffer, _capture_sample_rate, TARGET_SAMPLE_RATE)
	var duration = float(resampled.size()) / float(TARGET_SAMPLE_RATE)
	print("[VoiceInput] Recording stopped, %d samples at %d Hz (%.1fs)" % [resampled.size(), TARGET_SAMPLE_RATE, duration])

	if duration < MIN_RECORDING_SECONDS:
		error_occurred.emit("Recording too short (%.1fs)" % duration)
		_state = STATE_IDLE
		idle.emit()
		return

	# Convert PCM to WAV and send for transcription
	var wav_data = _encode_wav(resampled, TARGET_SAMPLE_RATE)
	if _http_client != null:
		_http_client.transcribe_audio(wav_data, TARGET_SAMPLE_RATE)
	else:
		error_occurred.emit("No HTTP client configured")
		_state = STATE_IDLE
		idle.emit()


## Cancel current operation (recording or transcription).
func cancel() -> void:
	if _state == STATE_RECORDING:
		_audio_player.stop()
		_pcm_buffer.clear()
		recording_stopped.emit()
	elif _state == STATE_TRANSCRIBING:
		pass  # transcription is in-flight, will be handled by callback

	_state = STATE_IDLE
	idle.emit()


# ── Recording (per-frame capture) ──────────────────────────────

## Poll the AudioEffectCapture buffer for new samples each frame.
func _capture_frame() -> void:
	if _state != STATE_RECORDING:
		return

	var max_samples = int(_capture_sample_rate * MAX_RECORDING_SECONDS)
	if _pcm_buffer.size() >= max_samples:
		print("[VoiceInput] Max recording duration reached")
		stop_and_transcribe()
		return

	var frames_available = _capture_effect.get_frames_available()
	if frames_available > 0:
		var samples_to_add = mini(frames_available, max_samples - _pcm_buffer.size())
		var stereo_buffer: PackedVector2Array = _capture_effect.get_buffer(samples_to_add)
		# Extract mono (left channel) from stereo frames
		for frame in stereo_buffer:
			_pcm_buffer.append(frame.x)


# ── Resampling (linear interpolation) ──────────────────────────

## Simple linear-interpolation resampler.
## Converts `samples` from `from_rate` to `to_rate`.
func _resample(samples: PackedFloat32Array, from_rate: int, to_rate: int) -> PackedFloat32Array:
	if from_rate == to_rate:
		return samples

	var output_count = int(float(samples.size()) * float(to_rate) / float(from_rate))
	if output_count <= 0:
		return PackedFloat32Array()

	var result: PackedFloat32Array = []
	result.resize(output_count)

	var ratio = float(from_rate) / float(to_rate)
	for i in range(output_count):
		var src_pos = i * ratio
		var src_idx = int(src_pos)
		var frac = src_pos - src_idx

		var s0 = samples[src_idx] if src_idx < samples.size() else 0.0
		var s1 = samples[src_idx + 1] if src_idx + 1 < samples.size() else s0
		result[i] = s0 + (s1 - s0) * frac

	return result


# ── WAV encoding ────────────────────────────────────────────────

## Encode PCM float32 samples into a WAV file (little-endian, 16-bit).
func _encode_wav(samples: PackedFloat32Array, sample_rate: int) -> PackedByteArray:
	var data = PackedByteArray()

	# WAV header (44 bytes)
	# RIFF header
	data.append_array(_string_to_le_bytes("RIFF"))
	data.append_array(_int32_to_le(36 + samples.size() * 2))  # file size - 8
	data.append_array(_string_to_le_bytes("WAVE"))

	# fmt chunk
	data.append_array(_string_to_le_bytes("fmt "))
	data.append_array(_int32_to_le(16))  # chunk size
	data.append_array(_int16_to_le(1))   # audio format (PCM)
	data.append_array(_int16_to_le(CHANNELS))
	data.append_array(_int32_to_le(sample_rate))
	data.append_array(_int32_to_le(sample_rate * CHANNELS * BITS_PER_SAMPLE / 8))  # byte rate
	data.append_array(_int16_to_le(CHANNELS * BITS_PER_SAMPLE / 8))  # block align
	data.append_array(_int16_to_le(BITS_PER_SAMPLE))

	# data chunk
	data.append_array(_string_to_le_bytes("data"))
	data.append_array(_int32_to_le(samples.size() * 2))  # data size

	# Convert float32 [-1.0, 1.0] to int16 little-endian
	for sample in samples:
		var clamped = clampf(sample, -1.0, 1.0)
		var int_sample = int(clamped * 32767.0)
		data.append_array(_int16_to_le(int_sample))

	return data


# ── Transcription callback ──────────────────────────────────────

func _on_transcription_completed(text: String, error: String) -> void:
	_state = STATE_IDLE
	_pcm_buffer.clear()

	if not error.is_empty():
		error_occurred.emit("Transcription failed: %s" % error)
		return

	if text.is_empty():
		error_occurred.emit("Transcription returned empty text (was silence?)")
		return

	print("[VoiceInput] Transcription: \"%s\"" % text)
	transcription_ready.emit(text)
	idle.emit()


# ── Helpers ─────────────────────────────────────────────────────

func _string_to_le_bytes(text: String) -> PackedByteArray:
	return text.to_utf8_buffer()

func _int16_to_le(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF])

func _int32_to_le(value: int) -> PackedByteArray:
	return PackedByteArray([
		value & 0xFF,
		(value >> 8) & 0xFF,
		(value >> 16) & 0xFF,
		(value >> 24) & 0xFF
	])
