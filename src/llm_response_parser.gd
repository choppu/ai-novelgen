## LlmResponseParser — Parses tool call arguments into structured LlmResponse.
##
## Validates and extracts fields from the LLM's structured tool call output.
extends RefCounted
const _EmotionalStatesScript = preload("res://src/emotional_states.gd")


## Structured response from the LLM.
class LlmResponse:
	var dialogue: String = ""
	## Maps clue_id → tier for each revealed clue (for tiered revelation)
	var revealed_clue_tiers: Dictionary = {}  # clue_id (String) → tier (int)
	var emotional_state: String = "neutral"

	## Derived list of revealed clue IDs (keys of revealed_clue_tiers).
	func get_revealed_clues() -> Array[String]:
		return Array(revealed_clue_tiers.keys())

	func is_valid() -> bool:
		return not dialogue.is_empty()

	func describe() -> String:
		return "LlmResponse(dialogue=\"%s\", clues=%s, emotion=\"%s\")" % [
			dialogue.substr(0, 60), get_revealed_clues(), emotional_state
		]


## Parse tool call arguments into an LlmResponse.
## tool_args: The parsed arguments dictionary from a tool call.
static func parse_from_tool_arguments(tool_args: Dictionary) -> LlmResponse:
	var response = LlmResponse.new()

	response.dialogue = _safe_string(tool_args.get("dialogue", ""))
	response.revealed_clue_tiers = _safe_tier_map(tool_args.get("revealed_clue_tiers", {}))
	response.emotional_state = _safe_emotional_state(tool_args.get("emotional_state", "neutral"))

	return response


static func _safe_string(value: Variant) -> String:
	if value is String:
		return value.strip_edges()
	return ""


static func _safe_emotional_state(value: Variant) -> String:
	if value is String:
		var lower = value.strip_edges().to_lower()
		if _EmotionalStatesScript.is_valid(lower):
			return lower
	push_warning("Invalid emotional state \"%s\", defaulting to neutral" % value)
	return "neutral"


## Parse revealed_clue_tiers map: { "clue_id": 2, ... } → Dictionary[String, int]
static func _safe_tier_map(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			var tier = value[key]
			if tier is int:
				result[key as String] = tier
			elif tier is float:
				result[key as String] = int(tier)
		return result
	return {}
