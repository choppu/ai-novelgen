## LlmHttpClient — Async HTTP client for OpenAI-compatible chat completions.
##
## Handles auth headers, timeouts, and error classification.
extends Node


## Emitted when a chat completion request finishes.
signal chat_completed(raw_response: Variant, error: String)

## Emitted when a speech generation request finishes with the raw audio buffer.
signal speech_generated(audio_buffer: PackedByteArray, error: String)

## Emitted when a whisper transcription request finishes.
signal transcription_completed(text: String, error: String)


var _chat_request: HTTPRequest
var _speech_request: HTTPRequest

# Transcription uses HTTPClient directly for binary multipart/form-data
var _trans_client: HTTPClient
var _trans_state: String = "idle"  # idle, connecting, waiting
var _trans_url: String = ""
var _trans_headers: PackedStringArray = []
var _trans_body: PackedByteArray = []
var _trans_response: PackedByteArray = []


func _ready() -> void:
	_chat_request = HTTPRequest.new()
	_chat_request.timeout = LlmConfig.get_request_timeout_s()
	_chat_request.request_completed.connect(_on_chat_request_completed)
	add_child(_chat_request)

	_speech_request = HTTPRequest.new()
	_speech_request.timeout = LlmConfig.get_request_timeout_s()
	_speech_request.request_completed.connect(_on_speech_request_completed)
	add_child(_speech_request)

	_trans_client = HTTPClient.new()


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
	var url = "%s/api/v1/chat/completions" % base_url
	
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

	var error = _chat_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		chat_completed.emit(null, "HTTP request failed: %d" % error)


## Generate speech from text via the OpenAI-compatible /v1/audio/speech endpoint.
## Returns raw audio bytes (MP3) directly in speech_generated.
func generate_speech(text: String, voice: String = "") -> void:
	var base_url = LlmConfig.get_base_url()
	var url = "%s/v1/audio/speech" % base_url

	var body_dict = {
		"model": LlmConfig.get_voice_model_name(),
		"input": text,
		"voice": voice if not voice.is_empty() else "af_heart",
		"response_format": "mp3"
	}

	var body = JSON.stringify(body_dict)
	var headers = [
		"Authorization: Bearer %s" % LlmConfig.get_api_key(),
		"Content-Type: application/json"
	]

	# Force Connection: close to avoid keep-alive issues with streaming binary responses
	headers.append("Connection: close")

	var error = _speech_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		speech_generated.emit(PackedByteArray(), "HTTP request failed: %d" % error)


## Transcribe audio via the OpenAI-compatible /v1/audio/transcriptions endpoint.
## wav_data: Raw WAV file bytes (16-bit PCM, 16kHz mono).
func transcribe_audio(wav_data: PackedByteArray, _sample_rate: int = 16000) -> void:
	var base_url = LlmConfig.get_base_url()
	var url = "%s/v1/audio/transcriptions" % base_url

	# Build multipart/form-data body
	var boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
	var body = PackedByteArray()

	# Model field
	body.append_array(_build_multipart_field("model", LlmConfig.get_whisper_model_name(), boundary))

	# File field (WAV)
	body.append_array(_build_multipart_file("file", "recording.wav", "audio/wav", wav_data, boundary))
	body.append_array(_build_multipart_end(boundary))

	var headers = [
		"Authorization: Bearer %s" % LlmConfig.get_api_key(),
		"Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW"
	]

	# Use HTTPClient directly — HTTPRequest can't send PackedByteArray bodies
	_trans_url = url
	_trans_headers = headers
	_trans_body = body
	_trans_response = PackedByteArray()
	_trans_state = "connecting"

	var parsed = _parse_url(url)
	var error = _trans_client.connect_to_host(parsed.host, parsed.port)
	if error != OK:
		transcription_completed.emit("", "HTTP connect failed: %d" % error)
		_trans_state = "idle"


func _process(_delta: float) -> void:
	_poll_transcription()


# ── Transcription (HTTPClient state machine) ──

func _parse_url(url: String) -> Dictionary:
	var result = {"host": "", "port": 443, "path": ""}
	var scheme_end = url.find("//")
	if scheme_end < 0:
		return result
	var rest = url.substr(scheme_end + 2)
	var slash = rest.find("/")
	if slash < 0:
		result.host = rest
		return result
	result.host = rest.substr(0, slash)
	result.path = rest.substr(slash)
	var port_idx = result.host.find(":")
	if port_idx >= 0:
		result.port = result.host.substr(port_idx + 1).to_int()
		result.host = result.host.substr(0, port_idx)
	if url.begins_with("https"):
		result.port = 443 if result.port == 0 else result.port
	else:
		result.port = 80 if result.port == 0 else result.port
	return result


func _poll_transcription() -> void:
	if _trans_state == "idle":
		return

	match _trans_state:
		"connecting":
			_trans_client.poll()
			var status = _trans_client.get_status()
			if status == HTTPClient.STATUS_CONNECTED:
				var path = _parse_url(_trans_url).path
				var err = _trans_client.request_raw(HTTPClient.METHOD_POST, path, _trans_headers, _trans_body)
				if err != OK:
					transcription_completed.emit("", "Request failed: %d" % err)
					_trans_state = "idle"
					_trans_client.close()
				else:
					_trans_state = "waiting"
			elif status == HTTPClient.STATUS_CONNECTION_ERROR:
				transcription_completed.emit("", "Connection refused — server may not be running")
				_trans_state = "idle"
				_trans_client.close()

		"waiting":
			_trans_client.poll()
			var status = _trans_client.get_status()
			if status == HTTPClient.STATUS_BODY:
				var chunk = _trans_client.read_response_body_chunk()
				while chunk.size() > 0:
					_trans_response.append_array(chunk)
					chunk = _trans_client.read_response_body_chunk()
				_handle_transcription_response(_trans_client.get_response_code(), _trans_response)
				_trans_state = "idle"
				_trans_client.close()
			elif status == HTTPClient.STATUS_CONNECTION_ERROR:
				transcription_completed.emit("", "Connection lost during response")
				_trans_state = "idle"
				_trans_client.close()


func _handle_transcription_response(response_code: int, body: PackedByteArray) -> void:
	if response_code == 0:
		transcription_completed.emit("", "Connection refused — server may not be running")
		return

	if response_code == 401:
		transcription_completed.emit("", "Authentication failed — check API key")
		return

	if response_code >= 400:
		var err_text = body.get_string_from_utf8()
		transcription_completed.emit("", "Server error: HTTP %d — %s" % [response_code, err_text.substr(0, 200)])
		return

	# Parse JSON response: { "text": "transcribed text" }
	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		transcription_completed.emit("", "Malformed JSON response: %s" % text.substr(0, 200))
		return

	var transcribed = parsed.get("text", "")
	if transcribed is String:
		transcription_completed.emit(transcribed.strip_edges(), "")
	else:
		transcription_completed.emit("", "No text field in response")


# ── Chat response handler ──

func _on_chat_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK:
		chat_completed.emit(null, "HTTP request error %d (response_code=%d)" % [result, response_code])
		return

	if response_code == 0:
		chat_completed.emit(null, "Connection refused — server may not be running")
		return

	if response_code == 401:
		chat_completed.emit(null, "Authentication failed — check API key")
		return

	if response_code >= 400:
		chat_completed.emit(null, "Server error: HTTP %d" % response_code)
		return

	_handle_chat_response(body)


func _handle_chat_response(body: PackedByteArray) -> void:
	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)

	if parsed == null or not (parsed is Dictionary):
		chat_completed.emit(null, "Malformed JSON response: %s" % text.substr(0, 200))
		return

	var raw = _extract_raw_content(parsed)
	chat_completed.emit(raw, "")


# ── Speech response handler ──

func _on_speech_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != OK:
		speech_generated.emit(PackedByteArray(), "HTTP request error %d (response_code=%d)" % [result, response_code])
		return

	if response_code == 0:
		speech_generated.emit(PackedByteArray(), "Connection refused — server may not be running")
		return

	if response_code == 401:
		speech_generated.emit(PackedByteArray(), "Authentication failed — check API key")
		return

	if response_code >= 400:
		var err_text = body.get_string_from_utf8()
		speech_generated.emit(PackedByteArray(), "Server error: HTTP %d — %s" % [response_code, err_text.substr(0, 200)])
		return

	speech_generated.emit(body, "")


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


# ── Multipart helpers ──

func _build_multipart_field(field_name: String, field_value: String, boundary: String) -> PackedByteArray:
	var data = PackedByteArray()
	data.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	data.append_array(("Content-Disposition: form-data; name=\"" + field_name + "\"\r\n\r\n").to_utf8_buffer())
	data.append_array(field_value.to_utf8_buffer())
	data.append_array("\r\n".to_utf8_buffer())
	return data


func _build_multipart_file(field_name: String, filename: String, content_type: String, file_data: PackedByteArray, boundary: String) -> PackedByteArray:
	var data = PackedByteArray()
	data.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	data.append_array(("Content-Disposition: form-data; name=\"" + field_name + "\"; filename=\"" + filename + "\"\r\n").to_utf8_buffer())
	data.append_array(("Content-Type: " + content_type + "\r\n\r\n").to_utf8_buffer())
	data.append_array(file_data)
	data.append_array("\r\n".to_utf8_buffer())
	return data


func _build_multipart_end(boundary: String) -> PackedByteArray:
	return ("--" + boundary + "--\r\n").to_utf8_buffer()
