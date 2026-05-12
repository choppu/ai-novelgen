## NPCMemory — Per-NPC memory summarization.
##
## Triggers LLM-based summarization of conversation history.
## Memory is stored in GameState for persistence.
extends Node


const _SUMMARIZATION_PROMPT_PATH = "res://prompts/summarization_system.txt"


var _http_client: Node
var _summarization_prompt: String = ""
var _current_npc_name: String = ""


func _init() -> void:
	_summarization_prompt = _load_file(_SUMMARIZATION_PROMPT_PATH)


func _load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not load summarization prompt: %s" % path)
		return ""
	var content = file.get_as_text()
	file.close()
	return content


## Set the HTTP client for making summarization calls.
func set_http_client(client: Node) -> void:
	_http_client = client
	_http_client.chat_completed.connect(_on_summary_response)


## Get the stored memory summary for an NPC (from GameState).
func get_memory(npc_name: String) -> String:
	return GameState.get_memory(npc_name)


## Build the tool definition for the summarization assistant.
func _build_summarize_tool() -> Array[Dictionary]:
	return [{
		"type": "function",
		"function": {
			"name": "summarize_memory",
			"description": "Summarize the NPC's memory of interactions with the player.",
			"strict": true,
			"parameters": {
				"type": "object",
				"properties": {
					"summary": {
						"type": "string",
						"description": "The updated memory summary (2-3 sentences)."
					}
				},
				"required": ["summary"]
			}
		}
	}]


## Trigger LLM-based summarization of the conversation history for an NPC.
## npc_name: The NPC's name.
## history: Array[Dictionary] of {role, content} messages.
## background: The NPC's background description (from character card).
## The result is stored directly in GameState.
func summarize(npc_name: String, history: Array[Dictionary], background: String = "") -> void:
	if _http_client == null:
		push_warning("Memory manager: HTTP client not set, cannot summarize")
		return

	if history.is_empty():
		return

	# Get current memory for this NPC (for merging)
	var current_memory = GameState.get_memory(npc_name)
	current_memory = current_memory if not current_memory.is_empty() else "No previous interactions."

	# Format conversation history as text
	var history_text = ""
	for msg in history:
		if msg is Dictionary:
			var role = msg.get("role", "")
			var content = msg.get("content", "")
			if not content.is_empty():
				if role == "user":
					history_text += "Player: %s\n" % content
				elif role == "assistant":
					history_text += "%s: %s\n" % [npc_name, content]

	# Build the system prompt with all placeholders
	var system_prompt = _summarization_prompt
	system_prompt = system_prompt.replace("{npc_name}", npc_name)
	system_prompt = system_prompt.replace("{background}", background if not background.is_empty() else "No background information available.")
	system_prompt = system_prompt.replace("{current_memory}", current_memory)
	system_prompt = system_prompt.replace("{conversation_history}", history_text if not history_text.is_empty() else "(No conversation history)")

	var messages: Array[Dictionary] = []
	messages.append({"role": "system", "content": system_prompt})

	# Track which NPC this summary is for
	_current_npc_name = npc_name

	_http_client.chat_completion(messages, "", {}, _build_summarize_tool())


## Internal handler for summarization responses.
func _on_summary_response(raw_response: Variant, error: String) -> void:
	# Ignore responses that aren't for us (e.g., dialogue responses)
	if raw_response is Dictionary and "tool_call" in raw_response:
		var tool_call = raw_response["tool_call"]
		if tool_call.get("name", "") != "summarize_memory":
			return

	if error.is_empty() == false or raw_response == null:
		push_error("Memory summarization failed for %s: %s" % [_current_npc_name, error])
		return

	# Strict tool calling — no fallbacks
	if not (raw_response is Dictionary and "tool_call" in raw_response):
		push_error("Memory summarization: LLM did not use the summarize_memory tool")
		return

	var tool_call_result = raw_response["tool_call"]
	var arguments = tool_call_result.get("arguments", {})

	if arguments is not Dictionary or arguments.is_empty():
		push_error("Memory summarization: summarize_memory tool called with empty arguments")
		return

	var summary = arguments.get("summary", "")
	summary = summary.strip_edges()

	if summary.is_empty():
		push_error("Memory summarization: summarize_memory returned empty summary")
		return

	# Store the summary in GameState
	GameState.set_memory(_current_npc_name, summary)
