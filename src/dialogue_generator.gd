## DialogueGenerator — Generates character-appropriate NPC dialogue with metadata.
##
## Assembles persona + context + intent + clues → LLM call → parsed response.
extends Node

const _LlmResponseParserScript := preload("res://src/llm_response_parser.gd")
const _PromptBuilderScript := preload("res://src/prompt_builder.gd")
const _ConversationHistoryScript := preload("res://src/conversation_history.gd")

## Emitted when dialogue generation completes.
signal dialogue_generated(response: Variant)

## Emitted when generation fails.
signal generation_error(error_msg: String)


var _http_client: Node
var _prompt_builder
var _conversation_history
var _memory_manager
var _is_generating: bool = false
var _last_player_input: String = ""


func _ready() -> void:
	_prompt_builder = _PromptBuilderScript.new()
	_conversation_history = _ConversationHistoryScript.new()


func set_http_client(client: Node) -> void:
	_http_client = client
	_http_client.chat_completed.connect(_on_dialogue_response)

func set_memory_manager(manager) -> void:
	_memory_manager = manager


func get_conversation_history():
	return _conversation_history


## Generate dialogue for an NPC response.
## player_input: The raw player input text (directly directed at the NPC).
## npc_name: The NPC's name.
## appearance: Character appearance description from the character card.
## background: Character background from the character card.
## temperament: Character temperament from the character card.
## mood: Character current mood from the character card.
## scene_context: Current scene description and situation.
## available_clues: List of AvailableClue objects (or legacy Array[String]).
## target_npc: NPC name for trust level lookup.
func generate(
	player_input: String,
	npc_name: String,
	appearance: String,
	background: String,
	temperament: String,
	mood: String,
	scene_context: String,
	available_clues: Array,
	target_npc: String
) -> void:
	if _is_generating:
		push_warning("Dialogue generator is already processing a request")
		return

	if _http_client == null:
		generation_error.emit("HTTP client not set")
		return

	_is_generating = true
	_last_player_input = player_input

	# Get full conversation history (flat message list)
	var history = _conversation_history.get_messages()

	# Get trust level for this NPC
	var trust_level = 0
	if not target_npc.is_empty():
		trust_level = GameState.get_relationship(target_npc)

	# Get NPC's past interaction memory
	var npc_memory = ""
	if _memory_manager:
		npc_memory = _memory_manager.get_memory(target_npc)

	# Build dialogue prompt (returns {messages, tools})
	var prompt_data = _prompt_builder.build_dialogue_prompt(
		npc_name,
		appearance,
		background,
		temperament,
		mood,
		scene_context,
		available_clues,
		npc_memory,
		history,
		player_input,
		trust_level
	)

	# Send request with tool definitions
	_http_client.chat_completion(
		prompt_data.get("messages", []),
		"",
		{},
		prompt_data.get("tools", [])
	)


## Called when LLM response arrives.
func _on_dialogue_response(raw_response: Variant, error: String) -> void:
	_is_generating = false

	# Ignore tool calls that aren't for dialogue (e.g., summarization)
	if raw_response is Dictionary and "tool_call" in raw_response:
		var tool_call = raw_response["tool_call"]
		if tool_call.get("name", "") != "respond":
			return

	if error.is_empty() == false or raw_response == null:
		generation_error.emit("LLM generation failed: %s" % error)
		return

	# Strict tool calling — no fallbacks
	if not (raw_response is Dictionary and "tool_call" in raw_response):
		generation_error.emit("LLM did not use the respond tool")
		return

	var tool_call = raw_response["tool_call"]
	var arguments = tool_call.get("arguments", {})

	if arguments is not Dictionary or arguments.is_empty():
		generation_error.emit("LLM respond tool called with empty arguments")
		return

	var response = _LlmResponseParserScript.parse_from_tool_arguments(arguments)
	print("[LLM] Tool call received: name=%s, dialogue=%s" % [
		tool_call.get("name", "?"),
		response.dialogue.substr(0, 80)
	])

	if not response.is_valid():
		generation_error.emit("LLM respond tool returned empty dialogue")
		return

	# Add exchange to conversation history (flat message list)
	_conversation_history.add_user_input(_last_player_input)
	_conversation_history.add_llm_reply(response.dialogue)
	_last_player_input = ""

	dialogue_generated.emit(response)
