## SceneManager — Loads a JSON story and drives scene transitions.
##
## Handles story data parsing, flag-based choice gating,
## clue definition loading, and scene entry state changes.
extends RefCounted


## Emitted when the story is fully loaded and ready.
signal story_loaded(success: bool, error_message: String)

## Emitted after a successful scene transition.
signal scene_changed(scene_id: String, scene_data: Dictionary)


var _story_data: Dictionary = {}
var _scenes: Dictionary = {}
var _clues: Dictionary = {}  # clue_id → clue definition dict
var _characters: Dictionary = {}  # npc_name → character card dict


## Load a story from a JSON file path.
## Returns true on success; emits story_loaded signal.
func load_story(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err = "Failed to open story file: %s (error %d)" % [path, FileAccess.get_open_error()]
		story_loaded.emit(false, err)
		push_error(err)
		return false

	var raw = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(raw)
	if parse_result is Dictionary:
		_story_data = parse_result as Dictionary
	elif parse_result == null:
		var err = "Failed to parse JSON from: %s" % path
		story_loaded.emit(false, err)
		push_error(err)
		return false
	else:
		var err = "Unexpected JSON root type: %s" % typeof(parse_result)
		story_loaded.emit(false, err)
		push_error(err)
		return false

	# Register scenes
	_scenes.clear()
	var scenes_raw = _story_data.get("scenes", {})
	if scenes_raw is Dictionary:
		_scenes = scenes_raw

	# Register clues
	_clues.clear()
	var clues_raw = _story_data.get("clues", {})
	if clues_raw is Dictionary:
		_clues = clues_raw
		print("Loaded %d clue definitions" % _clues.size())

	# Register characters
	_characters.clear()
	var characters_raw = _story_data.get("characters", {})
	if characters_raw is Dictionary:
		_characters = characters_raw
		print("Loaded %d character definitions" % _characters.size())

	# Load audio event mappings from story config
	var audio_config = _story_data.get("audio", {})
	if audio_config is Dictionary and audio_config.size() > 0:
		SoundEvents.load_from_config(audio_config)

	# Initialize GameState from story flags
	var initial_flags = _story_data.get("flags", {})
	GameState.reset()
	if initial_flags is Dictionary:
		for flag_name: String in initial_flags:
			var flag_data = initial_flags[flag_name]
			if flag_data is Dictionary:
				GameState.set_flag(flag_name, flag_data.get("initial", false))
			else:
				GameState.set_flag(flag_name, false if flag_data == 0 else bool(flag_data))

	# Initialize relationships from story data
	var initial_relationships = _story_data.get("relationships", {})
	if initial_relationships is Dictionary:
		GameState.apply_relationships(initial_relationships)

	# Enter the start scene
	var start_scene = _story_data.get("metadata", {}).get("start_scene", "")
	if start_scene.is_empty():
		var scene_keys = _scenes.keys()
		if scene_keys.size() > 0:
			start_scene = scene_keys[0]

	if not start_scene.is_empty():
		enter_scene(start_scene)

	story_loaded.emit(true, "")
	return true


## Enter a scene by ID. Validates existence, applies on_enter state changes,
## updates GameState, and emits scene_changed.
func enter_scene(scene_id: String) -> bool:
	if not _scenes.has(scene_id):
		push_warning("Scene not found: %s" % scene_id)
		return false

	var scene_data = _scenes[scene_id]

	# Apply on_enter flag changes
	var on_enter = scene_data.get("on_enter", {})
	if on_enter is Dictionary:
		var set_flags = on_enter.get("set_flags", {})
		if set_flags is Dictionary and set_flags.size() > 0:
			GameState.apply_flags(set_flags)

		# Apply on_enter relationship changes
		var set_relationships = on_enter.get("set_relationships", {})
		if set_relationships is Dictionary and set_relationships.size() > 0:
			GameState.apply_relationships(set_relationships)

	# Update game state
	GameState.current_scene = scene_id
	GameState.record_scene_visit(scene_id)

	scene_changed.emit(scene_id, scene_data)
	return true


## Get the current scene's data dictionary.
func get_current_scene() -> Dictionary:
	var sid = GameState.current_scene
	if _scenes.has(sid):
		return _scenes[sid]
	return {}


## Make a choice. Validates prerequisites, applies set_flags,
## transitions to the target scene.
func make_choice(choice_id: String) -> bool:
	var scene_data = get_current_scene()
	var choices = scene_data.get("choices", [])

	var selected_choice: Dictionary = {}
	var found = false

	for choice in choices:
		if choice is Dictionary and choice.get("id", "") == choice_id:
			# Check required flags
			var required = choice.get("requires_flags", {})
			if _check_flags(required):
				selected_choice = choice
				found = true
				break

	if not found:
		push_warning("Choice not available: %s" % choice_id)
		return false

	# Apply choice set_flags
	var set_flags = selected_choice.get("set_flags", {})
	if set_flags is Dictionary and set_flags.size() > 0:
		GameState.apply_flags(set_flags)

	# Apply choice relationship changes
	var set_relationships = selected_choice.get("set_relationships", {})
	if set_relationships is Dictionary and set_relationships.size() > 0:
		GameState.apply_relationships(set_relationships)

	# Transition
	var target = selected_choice.get("target", "")
	return enter_scene(target)


## Get available choices for the current scene (filtered by flag requirements).
func get_available_choices() -> Array[Dictionary]:
	var scene_data = get_current_scene()
	var choices = scene_data.get("choices", [])
	var available: Array[Dictionary] = []

	for choice in choices:
		if choice is Dictionary:
			var required = choice.get("requires_flags", {})
			if _check_flags(required):
				available.append(choice)

	return available


## Check if all required flags match current state.
func _check_flags(required: Variant) -> bool:
	if required == null or required is not Dictionary or required.size() == 0:
		return true

	for flag_name: String in required:
		var expected = required[flag_name]
		var actual = GameState.get_flag(flag_name)
		if actual != expected:
			return false

	return true


## Get the full clues dictionary from story data.
func get_clues() -> Dictionary:
	return _clues.duplicate()


## Get a specific character card by name.
func get_character(npc_name: String) -> Dictionary:
	return _characters.get(npc_name, {}).duplicate()

## Get all character cards.
func get_characters() -> Dictionary:
	return _characters.duplicate()
