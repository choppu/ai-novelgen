## CluePrerequisiteEvaluator — Computes available clues per NPC per scene.
##
## The engine decides what's available; the LLM delivers it naturally.
## This class evaluates flag, trust, prerequisite clue, and scene requirements
## for each clue tier.
extends RefCounted


## Result of availability check for a single clue tier.
class AvailableClue:
	var clue_id: String = ""
	var description: String = ""
	var tier: int = 0
	var tier_text: String = ""
	var source_npc: String = ""

	func _init(
		id: String, desc: String, t: int, text: String,
		npc: String
	) -> void:
		clue_id = id
		description = desc
		tier = t
		tier_text = text
		source_npc = npc

	func describe() -> String:
		return "AvailableClue(id=\"%s\", tier=%d, npc=\"%s\")" % [clue_id, tier, source_npc]


## All clue definitions loaded from story JSON.
var _clues: Dictionary = {}  # clue_id → clue definition dict

## The clue tracker for checking already-revealed clues.
var _clue_tracker

func _init(tracker) -> void:
	_clue_tracker = tracker


## Load clue definitions from story JSON data.
func load_clues(clue_data: Dictionary) -> void:
	_clues.clear()
	if not (clue_data is Dictionary):
		return
	for clue_id in clue_data:
		_clues[clue_id] = clue_data[clue_id]


## Check if all prerequisites for a specific clue tier are met.
## Returns true if the tier can be revealed right now.
func check_prerequisites(clue_id: String, tier_def: Dictionary, scene_id: String) -> bool:
	if not _clues.has(clue_id):
		return false

	# ── Check flag requirements ──
	var requires_flags = tier_def.get("requires_flags", [])
	if requires_flags is Array:
		for flag_name in requires_flags:
			if not GameState.has_flag(flag_name as String):
				return false
	elif requires_flags is Dictionary:
		for flag_name in requires_flags:
			var expected = requires_flags[flag_name]
			if GameState.get_flag(flag_name) != expected:
				return false

	# ── Check trust/relationship requirements ──
	var requires_trust = tier_def.get("requires_trust", 0)
	if requires_trust > 0:
		# Trust is tracked per-NPC in GameState.relationships
		# The tier_def should also specify which NPC's trust to check
		var trust_npc = tier_def.get("trust_npc", "")
		if not trust_npc.is_empty():
			var current_trust = GameState.get_relationship(trust_npc)
			if current_trust < requires_trust:
				return false

	# ── Check scene requirements (clue only available in certain scenes) ──
	var valid_scenes = tier_def.get("valid_scenes", [])
	if valid_scenes is Array and valid_scenes.size() > 0:
		if not (scene_id in valid_scenes):
			return false

	return true


## Compute the list of clues available for a specific NPC in the current scene.
## Uses the character card's can_reveal list as the authoritative source of
## which clues this NPC can ever reveal. Then filters by trust/flags/prerequisites.
##
## npc_id: The NPC name (for trust level lookup).
## scene_id: The current scene ID (for scene-gated clues).
## can_reveal: List of clue IDs from the character card — the NPC's full repertoire.
func get_available_clues(npc_id: String, scene_id: String, can_reveal: Array) -> Array[AvailableClue]:
	var available: Array[AvailableClue] = []

	for clue_id in can_reveal:
		var clue_def = _clues.get(clue_id, {})
		if clue_def.is_empty():
			continue

		# ── Find the lowest available unrevealed tier ──
		var tiers = clue_def.get("tiers", [])
		if not (tiers is Array) or tiers.is_empty():
			continue

		# Sort tiers ascending so we find the lowest unrevealed available tier
		var sorted_tiers: Array = tiers.duplicate()
		sorted_tiers.sort_custom(func(a, b): return a.get("tier", 0) < b.get("tier", 0))

		for tier_def in sorted_tiers:
			var tier_num = tier_def.get("tier", 1)

			# Skip already-revealed tiers
			if _clue_tracker.is_tier_revealed(clue_id, tier_num):
				continue

			# Check if this tier's prerequisites are met
			if check_prerequisites(clue_id, tier_def, scene_id):
				# This tier is available — return the lowest unrevealed tier
				var clue_desc = clue_def.get("description", "")
				var tier_text = tier_def.get("text", "")

				available.append(AvailableClue.new(
					clue_id, clue_desc, tier_num, tier_text, npc_id
				))
				break  # Only return the lowest available unrevealed tier per clue

	return available


## Get a clue definition by ID.
func get_clue_definition(clue_id: String) -> Dictionary:
	return _clues.get(clue_id, {})
