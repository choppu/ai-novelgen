## LlmConfig — Loads and provides typed access to LLM configuration.
##
## Autoloaded as "LlmConfig". Reads config/llm.json on startup.
extends Node


## Raw configuration dictionary
var _config: Dictionary = {}

## ── Server settings ──
var _server_host: String
var _server_port: int
var _server_api_key: String
var _health_check_interval_ms: int
var _startup_timeout_s: int

## ── Model settings ──
var _model_name: String
var _ctx_size: int
var _max_tokens: int

## ── Client settings ──
var _request_timeout_s: int
var _max_retries: int
var _retry_backoff_ms: int

## ── Server lifecycle ──
## When true (default), main_controller starts/stops the lemond subprocess.
## When false, the server is assumed to be managed externally.
var _manage_server_lifecycle: bool


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var path = "res://config/llm.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err = "Failed to open LLM config: %s (error %d)" % [path, FileAccess.get_open_error()]
		push_error(err)
		return

	var raw = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(raw)
	if parse_result is Dictionary:
		_config = parse_result as Dictionary
		_parse_config()
		_log_config()
	else:
		var err = "Failed to parse LLM config JSON"
		push_error(err)


func _parse_config() -> void:
	var server = _config.get("server", {})
	_server_host = server.get("host", "127.0.0.1")
	_server_port = server.get("port", 13305)
	_server_api_key = server.get("api_key", "novelgen-dev-key")
	_health_check_interval_ms = server.get("health_check_interval_ms", 2000)
	_startup_timeout_s = server.get("startup_timeout_s", 60)
	_manage_server_lifecycle = server.get("manage_server_lifecycle", true)

	var model = _config.get("model", {})
	_model_name = model.get("name", "Qwen3.5-9B-Q4_K_M")
	_ctx_size = model.get("ctx_size", 8192)
	_max_tokens = model.get("max_tokens", 1024)

	var client = _config.get("client", {})
	_request_timeout_s = client.get("request_timeout_s", 60)
	_max_retries = client.get("max_retries", 2)
	_retry_backoff_ms = client.get("retry_backoff_ms", 1000)


func _log_config() -> void:
	var platform = OS.get_name()
	print("=== LLM Configuration ===")
	print("  Platform: %s" % platform)
	print("  Server:   %s:%d" % [_server_host, _server_port])
	print("  Model:    %s" % _model_name)
	print("  Binary:   %s" % get_binary())
	print("  Data dir: %s" % get_data_dir())
	print("=========================")


# ── Server accessors ──

func get_api_key() -> String:
	return _server_api_key


func get_base_url() -> String:
	return "http://%s:%d" % [_server_host, _server_port]


func get_health_check_interval_ms() -> int:
	return _health_check_interval_ms


func get_startup_timeout_s() -> int:
	return _startup_timeout_s


func get_manage_server_lifecycle() -> bool:
	return _manage_server_lifecycle	


# ── Model accessors ──

func get_model_name() -> String:
	return _model_name


func get_ctx_size() -> int:
	return _ctx_size


func get_max_tokens() -> int:
	return _max_tokens


# ── Client accessors ──

func get_request_timeout_s() -> int:
	return _request_timeout_s


func get_max_retries() -> int:
	return _max_retries


# ── Platform-aware path resolution ──

func get_binary() -> String:
	var binary = _config.get("server", {}).get("binary_linux", "lemond")
	if OS.get_name() == "Windows":
		binary = _config.get("server", {}).get("binary_windows", "lemond.exe")
	return binary

func get_data_dir() -> String:
	var relative_dir = _config.get("server", {}).get("data_dir", "res://lemond/")
	return ProjectSettings.globalize_path(relative_dir)
