## ConversationHistory — Tracks dialogue exchanges within a scene session.
##
## Stores messages as a flat list of {role, content} pairs.
## Token-aware: tracks approximate token count to stay within context window.
extends RefCounted


var _messages: Array[Dictionary] = []
var _approximate_token_count: int = 0
const _MAX_MESSAGES: int = 40  # ~20 exchanges worth
const _ESTIMATED_CHARS_PER_TOKEN: int = 4


## Add a user (player) message to the history.
func add_user_input(text: String) -> void:
	_messages.append({"role": "user", "content": text})
	@warning_ignore("INTEGER_DIVISION")
	_approximate_token_count += text.length() / _ESTIMATED_CHARS_PER_TOKEN
	_maybe_trim()


## Add an assistant (LLM/NPC) message to the history.
## Used for both NPC dialogue responses AND scene opening lines.
func add_llm_reply(text: String) -> void:
	_messages.append({"role": "assistant", "content": text})
	@warning_ignore("INTEGER_DIVISION")
	_approximate_token_count += text.length() / _ESTIMATED_CHARS_PER_TOKEN
	_maybe_trim()


## Get all stored messages.
func get_messages() -> Array[Dictionary]:
	return _messages.duplicate()


## Clear all history (e.g., on scene change).
func clear() -> void:
	_messages.clear()
	_approximate_token_count = 0


## Get approximate token count of stored history.
func get_token_count() -> int:
	return _approximate_token_count


## Trim oldest messages if we exceed the limit.
func _maybe_trim() -> void:
	while _messages.size() > _MAX_MESSAGES:
		var removed = _messages.pop_front()
		_approximate_token_count -= removed.get("content", "").length() / _ESTIMATED_CHARS_PER_TOKEN
