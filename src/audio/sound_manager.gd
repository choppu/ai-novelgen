## SoundManager — Singleton that manages background music and sound effects.
##
## Autoloaded as "SoundManager". Handles:
##   • BGM playback with crossfade between tracks
##   • One-shot SFX playback (supports overlapping instances)
##   • Volume control (master, BGM, SFX)
##   • Audio state persistence
##
## Usage:
##   SoundManager.play_bgm("res://music/ambient.ogg")
##   SoundManager.play_sfx("res://sfx/click.ogg")
##   SoundManager.set_bgm_volume(0.8)

extends Node


# ── Audio busses (created at runtime if missing) ────────────────
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"


# ── Audio players ───────────────────────────────────────────────
var _bgm_player: AudioStreamPlayer
var _bgm_fade_player: AudioStreamPlayer  # for crossfading in new track

# Pool of reusable SFX players (for overlapping sounds)
var _sfx_pool: Array[AudioStreamPlayer] = []
const MAX_SFX_VOICES := 8

# Current BGM state
var _current_bgm_path: String = ""
var _pending_bgm_path: String = ""  # target path during crossfade
var _is_fading: bool = false

# Volume settings (0.0–1.0)
var master_volume: float = 1.0
var bgm_volume: float = 0.7
var sfx_volume: float = 0.8

# Crossfade duration in seconds
var crossfade_duration: float = 1.5


# ── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	_setup_audio_busses()
	_setup_bgm_players()
	_setup_sfx_pool()


func _setup_audio_busses() -> void:
	# Create BGM bus if it doesn't exist
	if AudioServer.get_bus_index(BUS_BGM) == -1:
		var bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, BUS_BGM)
		AudioServer.set_bus_send(bus_index, &"Master")

	# Create SFX bus if it doesn't exist
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, BUS_SFX)
		AudioServer.set_bus_send(bus_index, &"Master")

	_apply_volume()


func _setup_bgm_players() -> void:
	# Primary BGM player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	add_child(_bgm_player)

	# Fade-in player (for crossfading)
	_bgm_fade_player = AudioStreamPlayer.new()
	_bgm_fade_player.bus = BUS_BGM
	add_child(_bgm_fade_player)


func _setup_sfx_pool() -> void:
	for i in range(MAX_SFX_VOICES):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)


# ── Background Music ────────────────────────────────────────────

## Play a BGM track. If already playing the same track, does nothing.
## If playing a different track, crossfades from old to new.
func play_bgm(path: String) -> void:
	if path.is_empty():
		return

	if (path == _current_bgm_path and _bgm_player.playing) or path == _pending_bgm_path:
		return  # Already playing or queuing this track

	var stream = _load_stream(path)
	if stream == null:
		push_warning("[SoundManager] BGM not found: %s" % path)
		return

	if _bgm_player.playing:
		# Crossfade: fade out current, fade in new
		_crossfade_bgm(stream, path)
	else:
		# No current track — just play
		_bgm_player.stream = _enable_loop(stream)
		_bgm_player.play()
		_current_bgm_path = path


## Stop BGM immediately.
func stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_fade_player.stop()
	_current_bgm_path = ""
	_pending_bgm_path = ""
	_is_fading = false


## Stop BGM with a fade-out.
func fade_out_bgm(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(_bgm_player, "volume_db", -80.0, duration)
	tween.tween_callback(_bgm_player.stop)
	_bgm_player.volume_db = _db_from_linear(bgm_volume * master_volume)
	_current_bgm_path = ""


func _crossfade_bgm(new_stream: AudioStream, new_path: String) -> void:
	if _is_fading:
		return  # Already crossfading, ignore

	_is_fading = true
	_pending_bgm_path = new_path

	# Set up the fade-in player with the new track (start silent)
	_bgm_fade_player.stream = new_stream
	_bgm_fade_player.volume_db = -80.0
	_bgm_fade_player.play()

	# Tween: fade out old, fade in new
	var tween = create_tween()

	# Fade out current track
	tween.parallel().tween_property(_bgm_player, "volume_db", -80.0, crossfade_duration)

	# Fade in new track
	tween.parallel().tween_property(_bgm_fade_player, "volume_db",
		_db_from_linear(bgm_volume * master_volume), crossfade_duration)

	# When fade completes, swap players
	tween.tween_callback(_on_crossfade_complete.bind(new_path))


func _on_crossfade_complete(new_path: String) -> void:
	_bgm_player.stop()
	_bgm_player.stream = _bgm_fade_player.stream
	_bgm_player.volume_db = _db_from_linear(bgm_volume * master_volume)
	_bgm_player.play()

	_bgm_fade_player.stop()
	_current_bgm_path = new_path
	_pending_bgm_path = ""
	_is_fading = false


# ── Sound Effects ───────────────────────────────────────────────

## Play a one-shot sound effect (no looping).
func play_sfx(path: String) -> AudioStreamPlayer:
	var stream = _load_stream(path)
	if stream == null:
		push_warning("[SoundManager] SFX not found: %s" % path)
		return null

	# Find a free player in the pool
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = _db_from_linear(sfx_volume * master_volume)
			player.play()
			return player

	# All voices busy — steal the first one
	var player = _sfx_pool[0]
	player.stream = stream
	player.volume_db = _db_from_linear(sfx_volume * master_volume)
	player.play()
	return player


## Play an SFX with custom volume override (no looping).
func play_sfx_volumes(path: String, volume: float) -> AudioStreamPlayer:
	var stream = _load_stream(path)
	if stream == null:
		return null

	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = _db_from_linear(volume * master_volume)
			player.play()
			return player

	return null


# ── Volume Control ──────────────────────────────────────────────

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_volume()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume()


func _apply_volume() -> void:
	var bgm_db = _db_from_linear(bgm_volume * master_volume)

	if _bgm_player:
		if not _bgm_player.playing:
			_bgm_player.volume_db = bgm_db
	if _bgm_fade_player:
		if not _bgm_fade_player.playing or _is_fading:
			pass  # Let tweens control during crossfade
	# Update bus volumes for any currently playing sounds
	var bgm_bus = AudioServer.get_bus_index(BUS_BGM)
	if bgm_bus != -1:
		AudioServer.set_bus_volume_db(bgm_bus, _db_from_linear(master_volume))
	var sfx_bus = AudioServer.get_bus_index(BUS_SFX)
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, _db_from_linear(master_volume))


# ── Convenience ─────────────────────────────────────────────────

## Resolve an asset path relative to the current story's audio directory.
func resolve_audio(asset_path: String) -> String:
	if asset_path.begins_with("res://") or asset_path.begins_with("user://"):
		return asset_path
	# Relative paths are resolved via GameConfig
	if GameConfig != null:
		return GameConfig.resolve_asset_path(asset_path)
	return "res://audio/" + asset_path


## Check if BGM is currently playing.
func is_bgm_playing() -> bool:
	return _bgm_player.playing or _bgm_fade_player.playing


## Get the current BGM path.
func get_current_bgm() -> String:
	return _current_bgm_path


# ── Helpers ─────────────────────────────────────────────────────

func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[SoundManager] Resource not found: %s" % path)
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		push_warning("[SoundManager] Failed to load resource: %s" % path)
		return null
	if resource is AudioStream:
		return resource
	push_warning("[SoundManager] Loaded resource is not an AudioStream (%s): %s" % [resource.get_class(), path])
	return null


func _db_from_linear(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


## Ensure an AudioStream will loop. Returns a looping copy if needed.
## Loaded resources are cached/shared, so we duplicate before modifying.
func _enable_loop(stream: AudioStream) -> AudioStream:
	if not stream.loop:
		var copy: AudioStream = stream.duplicate()
		copy.loop = true
		return copy
	return stream
