## PromptBuilder — Assembles LLM prompts from templates and runtime context.
##
## Loads template files from prompts/ and substitutes placeholders.
extends RefCounted


const _DIALOGUE_SYSTEM_PATH = "res://prompts/dialogue_system.txt"
const _EmotionalStatesScript = preload("res://src/emotional_states.gd")


var _dialogue_system_template: String = ""


func _init() -> void:
	_dialogue_system_template = _load_file(_DIALOGUE_SYSTEM_PATH)


func _load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not load template: %s" % path)
		return ""
	var content = file.get_as_text()
	file.close()
	return content


## Build a dialogue generation prompt with tool calling.
## Returns a Dictionary with "messages" and "tools" keys for the HTTP client.
##
## npc_memory: Summary of past conversations with this NPC (empty string if none).
## conversation_history: Array[Dictionary] of {role, content} message pairs.
##   Scene dialogue is already included as assistant messages in this list.
## available_clues can be:
##   - Array[String] (legacy: plain clue IDs)
##   - Array of AvailableClue objects (with tier, description, etc.)
func build_dialogue_prompt(
	npc_name: String,
	appearance: String,
	background: String,
	temperament: String,
	mood: String,
	scene_context: String,
	available_clues: Array,
	npc_memory: String,
	conversation_history: Array[Dictionary],
	player_input: String,
	trust_level: int = 0
) -> Dictionary:
	# Build system prompt from template
	var system_prompt = _dialogue_system_template

	# Substitute placeholders
	var clues_block = _format_clues_list(available_clues)
	var trust_block = _format_trust_level(trust_level)
	var memory_block = _format_memory(npc_memory)

	system_prompt = system_prompt.replace("{npc_name}", npc_name)
	system_prompt = system_prompt.replace("{appearance}", appearance)
	system_prompt = system_prompt.replace("{background}", background)
	system_prompt = system_prompt.replace("{temperament}", temperament)
	system_prompt = system_prompt.replace("{mood}", mood)
	system_prompt = system_prompt.replace("{memory}", memory_block)
	system_prompt = system_prompt.replace("{scene_context}", scene_context)
	system_prompt = system_prompt.replace("{available_clues}", clues_block)
	system_prompt = system_prompt.replace("{trust_level}", trust_block)

	# Build messages array: system + history + current input
	var messages: Array[Dictionary] = []
	messages.append({"role": "system", "content": system_prompt})

	# Insert conversation history (flat message list with scene dialogue included)
	for msg in conversation_history:
		if msg is Dictionary and msg.get("role", "") in ["user", "assistant"]:
			messages.append(msg)

	# Append the current player input
	messages.append({"role": "user", "content": player_input})

	# Truncate messages to stay within context window
	messages = _truncate_messages(messages, LlmConfig.get_ctx_size())

	# Build tool definition for structured NPC response
	var tools = _build_npc_response_tool()

	return {"messages": messages, "tools": tools}


## Format available clues into a readable block for the prompt.
## Handles both legacy Array[String] and Array of AvailableClue objects.
func _format_clues_list(clues: Array) -> String:
	if clues.is_empty():
		return "No clues available to reveal at this time."

	var lines: Array[String] = []
	for clue in clues:
		if clue is Object:
			# AvailableClue object with tier info
			var id = clue.clue_id
			var tier = clue.tier
			var desc = clue.description
			var tier_text = clue.tier_text
			if not tier_text.is_empty():
				lines.append("- [%s] (tier %d): %s" % [id, tier, tier_text])
			elif not desc.is_empty():
				lines.append("- [%s] (tier %d): %s" % [id, tier, desc])
			else:
				lines.append("- [%s] (tier %d)" % [id, tier])
		elif clue is String:
			# Legacy: plain clue ID
			lines.append("- %s" % clue)
	return "\n".join(lines)


## Format trust level into guidance text for the LLM.
func _format_trust_level(trust: int) -> String:
	if trust <= 0:
		return "The NPC does not trust the player yet. Be guarded, evasive, or cold."
	elif trust <= 2:
		return "The NPC is cautiously curious about the player. Share small details but hold back important information."
	elif trust <= 4:
		return "The NPC is beginning to trust the player. Share meaningful information but keep secrets for higher trust."
	elif trust <= 6:
		return "The NPC trusts the player fairly well. Share most information willingly."
	else:
		return "The NPC fully trusts the player. Share everything, including secrets and sensitive information."


## Format past interaction memory for the system prompt.
func _format_memory(memory: String) -> String:
	if memory.is_empty():
		return "You have no previous interactions with the player."
	return memory


## Build the NPC response tool definition for tool calling.
## This enforces structured output without relying on JSON-in-text parsing.
func _build_npc_response_tool() -> Array[Dictionary]:
	return [{
		"type": "function",
		"function": {
			"name": "respond",
			"description": "Respond to the player as the NPC. Use this to provide dialogue, reveal clues, and set emotional state.",
			"strict": true,
			"parameters": {
				"type": "object",
				"properties": {
					"dialogue": {
						"type": "string",
						"description": "Your in-character spoken response (2-4 sentences)."
					},
					"revealed_clue_tiers": {
						"type": "object",
						"additionalProperties": {"type": "integer"},
						"description": "Map of clue_id to tier number for each revealed clue. The keys are the revealed clue IDs."
					},
					"emotional_state": {
						"type": "string",
						"enum": _EmotionalStatesScript.get_enum_array(),
						"description": "Your current emotional state."
					}
				},
				"required": ["dialogue", "revealed_clue_tiers", "emotional_state"]
			}
		}
	}]


## Truncate messages to stay within context window limits.
## Keeps system prompt and most recent messages, dropping oldest user/assistant turns.
func _truncate_messages(messages: Array[Dictionary], ctx_size: int) -> Array[Dictionary]:
	# Rough estimate: 4 chars ≈ 1 token
	var estimated_tokens = 0
	for msg in messages:
		estimated_tokens += msg.get("content", "").length() / 4

	# Leave 20% headroom
	var max_tokens = int(ctx_size * 0.8)

	if estimated_tokens <= max_tokens:
		return messages

	# Keep system message (index 0) and last user message, drop middle history
	var truncated: Array[Dictionary] = [messages[0]]  # system
	# Keep last few messages
	var keep_from_back = max(1, messages.size() - 2)
	for i in range(keep_from_back, messages.size()):
		truncated.append(messages[i])

	return truncated
