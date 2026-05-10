## LlmHttpClient — Async HTTP client for OpenAI-compatible chat completions.
##
## Handles auth headers, timeouts, and error classification.
extends Node


## Emitted when a chat completion request finishes.
signal chat_completed(raw_response: Variant, error: String)


var _http_request: HTTPRequest


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = LlmConfig.get_request_timeout_s()
	_http_request.request_completed.connect(_on_chat_request_completed)
	add_child(_http_request)


## Send a chat completion request.
## messages: Array of {role, content} dictionaries (OpenAI format).
## model: Model name to use.
## options: Optional override dict for max_tokens, etc.
## tools: Optional array of tool definitions for tool calling.
func chat_completion(
	messages: Array,
	model: String = "",
	options: Dictionary = {},
	tools: Array = []
) -> void:
	var base_url = LlmConfig.get_base_url()
	var url = "%s/v1/chat/completions" % base_url
	
	var body_dict = {
		"model": model if not model.is_empty() else LlmConfig.get_model_name(),
		"messages": messages,
		"max_tokens": options.get("max_tokens", LlmConfig.get_max_tokens()),
	}

	# Include tool definitions if provided
	if tools.size() > 0:
		body_dict["tools"] = tools
		body_dict["parallel_tool_calls"] = false

	var body = JSON.stringify(body_dict)
	var headers = [
		"Authorization: Bearer %s" % LlmConfig.get_api_key(),
		"Content-Type: application/json"
	]

	var error = _http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		chat_completed.emit(null, "HTTP request failed: %d" % error)


# ── Response handlers ──

func _on_chat_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 0:
		chat_completed.emit(null, "Connection refused — server may not be running")
		return

	if response_code == 401:
		chat_completed.emit(null, "Authentication failed — check API key")
		return

	if response_code >= 400:
		chat_completed.emit(null, "Server error: HTTP %d" % response_code)
		return

	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)

	if parsed == null or not (parsed is Dictionary):
		chat_completed.emit(null, "Malformed JSON response: %s" % text.substr(0, 200))
		return

	# Extract raw content (includes tool_call data if present)
	var raw = _extract_raw_content(parsed)
	chat_completed.emit(raw, "")


## Extract the raw LLM content from an OpenAI-style response.
## If the response contains a tool call, its arguments are included as "tool_call".
func _extract_raw_content(response: Dictionary) -> Dictionary:
	var result = {
		"content": "",
		"prompt_tokens": 0,
		"completion_tokens": 0,
		"model": ""
	}

	var choices = response.get("choices", [])
	if choices is Array and choices.size() > 0:
		var first_choice = choices[0]
		if first_choice is Dictionary:
			var finish_reason = first_choice.get("finish_reason", "")
			var message = first_choice.get("message", {})
			if message is Dictionary:
				result["content"] = message.get("content", "")

				# Check for tool calls
				if finish_reason == "tool_calls":
					var tool_calls = message.get("tool_calls", [])
					if tool_calls is Array and tool_calls.size() > 0:
						var tool_call = tool_calls[0]
						if tool_call is Dictionary:
							var args_str = tool_call.get("function", {}).get("arguments", "{}")
							var args = JSON.parse_string(args_str) if args_str is String else {}
							result["tool_call"] = {
								"name": tool_call.get("function", {}).get("name", ""),
								"arguments": args if args is Dictionary else {}
							}

	var usage = response.get("usage", {})
	if usage is Dictionary:
		result["prompt_tokens"] = usage.get("prompt_tokens", 0)
		result["completion_tokens"] = usage.get("completion_tokens", 0)

	result["model"] = response.get("model", "")

	return result
