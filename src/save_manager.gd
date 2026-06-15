## SaveManager — Singleton that handles saving and loading game state.
##
## Autoloaded as "SaveManager". Persists game state to user://save_slot_N.json.
## Supports up to MAX_SLOTS save slots.
##
## Usage:
##   SaveManager.save_slot(0)
##   SaveManager.load_slot(0)
##   SaveManager.get_slot_info(0)  # { "scene": "foo", "timestamp": "2025-01-01 12:00", "empty": false }
##   SaveManager.delete_slot(0)

extends Node


const SAVE_DIR := "user://"
const SAVE_PREFIX := "save_slot_"
const SAVE_EXTENSION := ".json"
const MAX_SLOTS := 5

## Slot index that main_controller should load after scene transition.
## Set by main menu before changing scene; consumed by main_controller in _ready().
var pending_load_slot: int = -1


## Save the current game state to the given slot (0-indexed).
## Returns true on success.
func save_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[SaveManager] Invalid slot: %d" % slot)
		return false

	var data = {
		"current_scene": GameState.current_scene,
		"flags": GameState.flags.duplicate(true),
		"scene_history": GameState.scene_history.duplicate(),
		"known_clues": GameState.known_clues.duplicate(),
		"relationships": GameState.relationships.duplicate(),
		"memories": GameState.memories.duplicate(),
		"timestamp": Time.get_datetime_string_from_system(),
	}

	var path = _get_slot_path(slot)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot write save file: %s" % path)
		return false

	file.store_string(JSON.stringify(data, "  "))
	file.close()

	print("[SaveManager] Saved to slot %d (%s)" % [slot, data["timestamp"]])
	return true


## Load a game state from the given slot.
## Returns true on success, false if slot is empty.
func load_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[SaveManager] Invalid slot: %d" % slot)
		return false

	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Cannot read save file: %s" % path)
		return false

	var raw = file.get_as_text()
	file.close()

	var data = JSON.parse_string(raw)
	if data == null or data is not Dictionary:
		push_error("[SaveManager] Invalid save data in slot %d" % slot)
		return false

	# Restore game state
	GameState.current_scene = data.get("current_scene", "")
	GameState.flags.clear()
	var saved_flags = data.get("flags", {})
	if saved_flags is Dictionary:
		for k: String in saved_flags:
			GameState.flags[k] = saved_flags[k]
	GameState.scene_history.clear()
	var saved_history = data.get("scene_history", [])
	if saved_history is Array:
		for item in saved_history:
			GameState.scene_history.append(str(item))
	GameState.known_clues.clear()
	var saved_clues = data.get("known_clues", {})
	if saved_clues is Dictionary:
		for k: String in saved_clues:
			GameState.known_clues[k] = saved_clues[k]
	GameState.relationships.clear()
	var saved_rels = data.get("relationships", {})
	if saved_rels is Dictionary:
		for k: String in saved_rels:
			GameState.relationships[k] = saved_rels[k]
	GameState.memories.clear()
	var saved_mems = data.get("memories", {})
	if saved_mems is Dictionary:
		for k: String in saved_mems:
			GameState.memories[k] = saved_mems[k]

	print("[SaveManager] Loaded from slot %d (scene: %s, saved: %s)" % [
		slot, GameState.current_scene, data.get("timestamp", "unknown")
	])
	return true


## Get metadata about a save slot without loading it.
## Returns a Dictionary with keys: "scene", "timestamp", "empty".
func get_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS:
		return {"empty": true}

	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"empty": true}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"empty": true}

	var raw = file.get_as_text()
	file.close()

	var data = JSON.parse_string(raw)
	if data == null or data is not Dictionary:
		return {"empty": true}

	return {
		"empty": false,
		"scene": data.get("current_scene", ""),
		"timestamp": data.get("timestamp", ""),
	}


## Delete a save slot.
func delete_slot(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return

	var path = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] Deleted slot %d" % slot)


## Check if any save slots exist.
func has_any_saves() -> bool:
	for i in range(MAX_SLOTS):
		if not get_slot_info(i).get("empty", true):
			return true
	return false

## Queue a slot to be loaded after a scene transition.
## Call this from the main menu before changing to the game scene.
func queue_load(slot: int) -> void:
	pending_load_slot = slot

## Consume the pending load slot. Returns slot index or -1 if none.
func consume_pending_load() -> int:
	var slot = pending_load_slot
	pending_load_slot = -1
	return slot


## Get the path for a save slot.
func _get_slot_path(slot: int) -> String:
	return "%s%s%d%s" % [SAVE_DIR, SAVE_PREFIX, slot, SAVE_EXTENSION]
