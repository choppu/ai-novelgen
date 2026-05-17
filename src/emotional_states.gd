## EmotionalStates — Canonical list of NPC emotional states and their relationship impact values.
##
## Used by the prompt builder (tool definition) and the response parser (validation).
## Each state has an associated value: positive states raise the NPC's
## emotional mood toward the player; negative states lower it.
## When the accumulated mood exceeds +10, relationship increases by 1.
## When it drops to -10, relationship decreases by 1.
extends RefCounted


## Relationship value assigned to each emotional state.
## Positive = the NPC feels better about the player.
## Negative = the NPC feels worse about the player.
const STATE_VALUES: Dictionary = {
	"curious":    2,
	"suspicious": -1,
	"nervous":    0,
	"defensive":  0,
	"helpful":    3,
	"evasive":    1,
	"angry":     -3,
	"sad":        0,
	"neutral":    1,
	"flattered":  4,
	"happy":      3,
	"friendly":   3,
	"relaxed":    2,
	"trusting":   4,
}

## Threshold for relationship change.
const RELATIONSHIP_THRESHOLD: int = 10


## Check whether a state string is valid.
static func is_valid(state: String) -> bool:
	return state.strip_edges().to_lower() in STATE_VALUES


## Get the relationship value for an emotional state.
static func get_value(state: String) -> int:
	var s = state.strip_edges().to_lower()
	return STATE_VALUES.get(s, 0)


## Get the JSON enum array for tool definitions.
static func get_enum_array() -> Array:
	return Array(STATE_VALUES.keys())
