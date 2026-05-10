## ResponseValidator — Validates LLM responses against engine state.
##
## Never trusts LLM output for game logic. Checks claimed clues against
## the engine-computed available set. Supports tiered clue revelation.
extends Node

const _LlmResponseParserScript := preload("res://src/llm_response_parser.gd")


## Validated response with accepted/rejected clues separated.
class ValidatedResponse:
	var dialogue: String = ""
	var accepted_clues: Array[String] = []
	var accepted_clue_tiers: Dictionary = {}  # clue_id → tier
	var rejected_clues: Array[String] = []
	var emotional_state: String = "neutral"

	func describe() -> String:
		return "ValidatedResponse(dialogue=\"%s\", accepted=%s, rejected=%s, emotional_state=%s)" % [
			dialogue.substr(0, 60), accepted_clues, rejected_clues, emotional_state
		]


## Validate an LLM response against available clues.
## response: The parsed LlmResponse from the LLM.
## available_clues: Engine-computed list of AvailableClue objects.
func validate(
	response: Variant,
	available_clues: Array
) -> ValidatedResponse:
	var validated = ValidatedResponse.new()
	validated.dialogue = response.dialogue
	validated.emotional_state = response.emotional_state

	# Build a lookup of available clue IDs and their max allowed tiers
	var available_ids: Dictionary = {}  # clue_id → max_available_tier
	for avail in available_clues:
		if avail is Object:
			# AvailableClue object
			available_ids[avail.clue_id] = avail.tier
		elif avail is String:
			# Legacy: plain string clue ID (tier 1 assumed)
			available_ids[avail] = 1

	# ── Validate claimed clues against available set ──
	for clue_id in response.revealed_clue_tiers:
		if clue_id in available_ids:
			# Determine the tier the LLM claims
			var claimed_tier = response.revealed_clue_tiers[clue_id]
			var max_available_tier = available_ids[clue_id]

			# Validate tier doesn't exceed available tier
			if claimed_tier <= max_available_tier:
				if not clue_id in validated.accepted_clues:
					validated.accepted_clues.append(clue_id)
					validated.accepted_clue_tiers[clue_id] = claimed_tier
			else:
				validated.rejected_clues.append(clue_id)
				push_warning(
					"LLM claimed clue \"%s\" at tier %d, but max available is tier %d — rejected"
					% [clue_id, claimed_tier, max_available_tier]
				)
		else:
			validated.rejected_clues.append(clue_id)
			push_warning("LLM claimed clue \"%s\" not in available set — rejected" % clue_id)

	return validated
