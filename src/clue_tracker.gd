## ClueTracker — Tracks which clues the player has discovered and at what tier.
##
## Manages revelation state: clue_id → highest tier revealed.
## Syncs with GameState for persistence.
extends RefCounted


## Internal map: clue_id → highest tier revealed
var _known_clues: Dictionary = {}  # clue_id (String) → tier (int)

## Track which scene each clue was first revealed at
var _revelation_scenes: Dictionary = {}  # clue_id (String) → scene_id (String)


## Record that a clue has been revealed at a given tier.
## Only records if this tier is higher than what was previously known.
## Returns true if the clue was newly revealed or upgraded.
func reveal_clue(clue_id: String, tier: int, scene_id: String = "") -> bool:
	var previous_tier = _known_clues.get(clue_id, 0)
	if tier > previous_tier:
		_known_clues[clue_id] = tier
		if previous_tier == 0:
			_revelation_scenes[clue_id] = scene_id
		print("Clue \"%s\" revealed at tier %d (was %d)" % [clue_id, tier, previous_tier])
		return true
	return false


## Check if a clue has been discovered at any tier.
func is_known(clue_id: String) -> bool:
	return get_tier(clue_id) > 0


## Get the highest tier revealed for a clue. Returns 0 if unknown.
func get_tier(clue_id: String) -> int:
	return _known_clues.get(clue_id, 0)


## Get the total number of unique clues the player has discovered.
func get_known_count() -> int:
	var count = 0
	for clue_id in _known_clues:
		if _known_clues[clue_id] > 0:
			count += 1
	return count


## Check if a specific clue at a specific tier has already been revealed.
func is_tier_revealed(clue_id: String, tier: int) -> bool:
	var current = _known_clues.get(clue_id, 0)
	return current >= tier


## Reset all clue tracking (e.g., for new game).
func reset() -> void:
	_known_clues.clear()
	_revelation_scenes.clear()


## Restore from GameState.
func sync_from_game_state() -> void:
	_known_clues = GameState.known_clues.duplicate() if GameState.known_clues is Dictionary else {}
