## GameState — Singleton that tracks all game state.
##
## Autoloaded as "GameState". Provides access to current scene,
## boolean flags, scene visitation history, clue revelations,
## and NPC relationship values.
extends Node


## Current scene ID
var current_scene: String = ""

## Boolean flags (string → bool)
var flags: Dictionary = {}

## Ordered list of visited scene IDs
var scene_history: Array[String] = []

## Known clues: clue_id → highest tier revealed (int)
var known_clues: Dictionary = {}

## NPC relationships: npc_name → trust/karma value (int)
var relationships: Dictionary = {}

## NPC conversation memories: npc_name → summary string
var memories: Dictionary = {}


## Reset all state to defaults.
func reset() -> void:
	current_scene = ""
	flags.clear()
	scene_history.clear()
	known_clues.clear()
	relationships.clear()
	memories.clear()


## Set a flag value.
func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value


## Get a flag value. Returns null if the flag does not exist.
func get_flag(flag_name: String) -> Variant:
	return flags.get(flag_name)


## Check if a flag is true.
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false) == true


## Apply a batch of flag changes from a dictionary.
func apply_flags(changes: Dictionary) -> void:
	for key: String in changes:
		flags[key] = changes[key]


## Record entering a scene (appended to history).
func record_scene_visit(scene_id: String) -> void:
	scene_history.append(scene_id)

## Get relationship value for an NPC. Returns 0 if not set.
func get_relationship(npc_name: String) -> int:
	return relationships.get(npc_name, 0)

## Set relationship value for an NPC.
func set_relationship(npc_name: String, value: int) -> void:
	relationships[npc_name] = value

## Modify relationship value for an NPC (additive).
func modify_relationship(npc_name: String, delta: int) -> void:
	relationships[npc_name] = relationships.get(npc_name, 0) + delta

## Record a clue revelation.
func record_clue(clue_id: String, tier: int) -> void:
	var previous = known_clues.get(clue_id, 0)
	if tier > previous:
		known_clues[clue_id] = tier

## Check if a clue is known at any tier.
func is_clue_known(clue_id: String) -> bool:
	return known_clues.get(clue_id, 0) > 0

## Get the highest tier revealed for a clue.
func get_clue_tier(clue_id: String) -> int:
	return known_clues.get(clue_id, 0)

## Apply a batch of relationship changes from a dictionary.
func apply_relationships(changes: Dictionary) -> void:
	for npc_name: String in changes:
		relationships[npc_name] = changes[npc_name]

## Get the stored memory summary for an NPC.
func get_memory(npc_name: String) -> String:
	return memories.get(npc_name, "")

## Set the memory summary for an NPC.
func set_memory(npc_name: String, summary: String) -> void:
	memories[npc_name] = summary
