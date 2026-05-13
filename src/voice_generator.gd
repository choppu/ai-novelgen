## VoiceGenerator — Generates and plays NPC voice lines via TTS.
##
## Handles:
##   • Async TTS generation via LlmHttpClient
##   • Audio playback with AudioStreamPlayer
##   • Queue management (one voice at a time)
##
## Usage:
##   voice_generator.generate_and_play("Hello there!", "NPC Name")

extends Node


## Emitted when voice generation starts.
signal generation_started()

## Emitted when voice generation finishes (success or error).
signal generation_finished(success: bool)


var _http_client: Node
var _voice_player: AudioStreamPlayer

## Queue of text to generate and play
var _queue: Array[String] = []
var _is_processing: bool = false
var _is_generating: bool = false


func _ready() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "SFX"
	_voice_player.volume_db = _db_from_linear(0.9)  # slightly quieter than SFX default
	add_child(_voice_player)
	_voice_player.finished.connect(_on_voice_finished)


func set_http_client(client: Node) -> void:
	_http_client = client
	_http_client.speech_generated.connect(_on_speech_generated)


## Queue a voice line for generation and playback.
## If already playing/generating, adds to queue.
func generate_and_play(text: String, speaker_name: String = "") -> void:
	if text.is_empty():
		return

	# Skip narration (empty speaker)
	if speaker_name.is_empty():
		return

	_queue.append(text)
	_process_queue()


## Cancel all queued voice lines and stop playback.
func clear() -> void:
	_queue.clear()
	_is_processing = false
	_is_generating = false
	_voice_player.stop()


## Check if the voice system is currently active.
func is_active() -> bool:
	return _is_processing or _is_generating or _voice_player.playing


# ── Queue processing ──

func _process_queue() -> void:
	if _is_processing or _queue.is_empty():
		return

	_is_processing = true
	var text = _queue.pop_front()
	_generate(text)


func _generate(text: String) -> void:
	if _http_client == null:
		_is_processing = false
		_process_queue()
		return

	_is_generating = true
	generation_started.emit()
	_http_client.generate_speech(text)


func _on_speech_generated(audio_buffer: PackedByteArray, error: String) -> void:
	_is_generating = false

	if not error.is_empty():
		push_warning("[VoiceGenerator] TTS failed: %s" % error)
		generation_finished.emit(false)
		_is_processing = false
		_process_queue()
		return

	if audio_buffer.is_empty():
		push_warning("[VoiceGenerator] TTS returned empty audio buffer")
		generation_finished.emit(false)
		_is_processing = false
		_process_queue()
		return

	call_deferred("_play_audio", audio_buffer)
	generation_finished.emit(true)


func _play_audio(audio_buffer: PackedByteArray) -> void:
	var stream = _load_stream(audio_buffer)
	if stream == null:
		push_warning("[VoiceGenerator] Failed to load audio buffer")
		_is_processing = false
		_process_queue()
		return

	_voice_player.stream = stream
	_voice_player.play()


func _on_voice_finished() -> void:
	_is_processing = false
	_process_queue()


# ── Helpers ──

func _load_stream(audio_buffer: PackedByteArray) -> AudioStream:
	return AudioStreamMP3.load_from_buffer(audio_buffer)


func _db_from_linear(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
