## SoundEvents — Dispatches sound effect playback by event name.
##
## All event-to-path mappings come from the story's "audio" config in story.json.
## This class holds no defaults — if a story omits a mapping, the sound is silently skipped.
##
## Usage:
##   SoundEvents.play("choice_click")
##   SoundEvents.play("tension_rise")

class_name SoundEvents


## Play a sound effect by event name.
## Path is looked up from the story's audio config and resolved relative to the story folder.
## Returns the AudioStreamPlayer used, or null if the event has no mapping or the file is missing.
static func play(event_name: String) -> Variant:
	if SoundManager == null:
		return null

	var paths = _get_instance()._event_paths
	var path = paths.get(event_name)
	if path == null or (path is String and path.is_empty()):
		return null

	var resolved = SoundManager.resolve_audio(path as String)
	return SoundManager.play_sfx(resolved)


## Set the audio path for a specific event.
static func set_event_path(event_name: String, path: String) -> void:
	_get_instance()._event_paths[event_name] = path


## Get the audio path for a specific event.
static func get_event_path(event_name: String) -> String:
	return _get_instance()._event_paths.get(event_name, "") as String


## Load event mappings from a story's "audio" config dictionary.
## Replaces all existing mappings.
##
## Expected format in story.json:
##   {
##     "audio": {
##       "choice_hover":       "sfx/hover.mp3",
##       "choice_click":       "sfx/click.mp3",
##       "scene_transition":   "sfx/scene_transition.mp3",
##       "tension_rise":       "sfx/tension_rise.mp3",
##       ...
##     }
##   }
static func load_from_config(audio_config: Dictionary) -> void:
	_get_instance()._event_paths.clear()
	for event_name: String in audio_config:
		var path = audio_config[event_name]
		if path is String:
			_get_instance()._event_paths[event_name] = path


## Play a scene's on-enter SFX (from scene data).
## Scene data can have:
##   "sfx": "sfx/door_creak.mp3"              — single sound
##   "sfx": ["sfx/rain.mp3", "sfx/door.mp3"]  — multiple simultaneous sounds
static func play_scene_sfx(scene_data: Dictionary) -> void:
	if SoundManager == null:
		return

	var sfx_data = scene_data.get("sfx")
	if sfx_data == null:
		return

	if sfx_data is String:
		_play_resolved_path(sfx_data)
	elif sfx_data is Array:
		for sound_path in sfx_data:
			if sound_path is String:
				_play_resolved_path(sound_path)


## Play a choice's SFX (from choice data).
## Choice data can have: "sfx": "sfx/door_creak.mp3"
static func play_choice_sfx(choice_data: Dictionary) -> void:
	if SoundManager == null:
		return

	var sfx = choice_data.get("sfx")
	if sfx is String and not sfx.is_empty():
		_play_resolved_path(sfx)


## Play a dialogue line's SFX (from dialogue line data).
## Dialogue line can have: "sfx": "sfx/tension_rise.mp3"
static func play_dialogue_sfx(line_data: Dictionary) -> void:
	if SoundManager == null:
		return

	var sfx = line_data.get("sfx")
	if sfx is String and not sfx.is_empty():
		_play_resolved_path(sfx)


## Play the clue revelation sound (safe — skips if not mapped).
static func play_clue_revealed() -> void:
	play("clue_revealed")


# ── Instance state ──────────────────────────────────────────────
## Event name → relative audio path. Populated by load_from_config().
var _event_paths: Dictionary = {}


# ── Singleton pattern for instance access ───────────────────────
static var _instance: SoundEvents = null

static func _get_instance() -> SoundEvents:
	if _instance == null:
		_instance = SoundEvents.new()
	return _instance


## Resolve a path and play it. Safely skips missing files (warning only).
static func _play_resolved_path(path: String) -> void:
	if SoundManager != null:
		var resolved = SoundManager.resolve_audio(path)
		SoundManager.play_sfx(resolved)
