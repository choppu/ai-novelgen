## ServerLifecycle — Launches, monitors, and shuts down lemond as a managed subprocess.
##
## Handles cross-platform binary resolution, health-check polling, and graceful shutdown.
extends Node


## Emitted when health check passes and server is ready.
signal server_ready()

## Emitted on startup failure or health-check timeout.
signal server_error(error_msg: String)


var _pid: int = -1
var _is_running: bool = false
var _health_timer: Timer
var _startup_timer: Timer
var _http_client: HTTPRequest
var _health_check_count: int = 0


func _ready() -> void:
	_health_timer = Timer.new()
	_health_timer.wait_time = LlmConfig.get_health_check_interval_ms() / 1000.0
	_health_timer.one_shot = true
	_health_timer.timeout.connect(_on_health_timer_timeout)
	add_child(_health_timer)

	_startup_timer = Timer.new()
	_startup_timer.wait_time = float(LlmConfig.get_startup_timeout_s())
	_startup_timer.one_shot = true
	_startup_timer.timeout.connect(_on_startup_timeout)
	add_child(_startup_timer)

	_http_client = HTTPRequest.new()
	_http_client.request_completed.connect(_on_health_check_completed)
	add_child(_http_client)


## Start the lemond subprocess.
func start() -> void:
	if _is_running:
		push_warning("lemond is already running (PID %d)" % _pid)
		return

	var binary_name = LlmConfig.get_binary()
	var data_dir = LlmConfig.get_data_dir()
	var binary_path = data_dir.path_join(binary_name)

	print("Starting lemond: %s" % binary_path)

	# Check binary exists
	if not FileAccess.file_exists("%s" % binary_path):
		var err = "lemond binary not found at %s" % binary_path
		push_error(err)
		server_error.emit(err)
		return

	var output = []
	var _stderr = []

	# Set environment variable for API key
	# OS.execute doesn't directly support env vars, so we use a wrapper approach
	# For Linux we can prepend the env var in a shell command
	var platform = OS.get_name()

	if platform == "Linux":
		var launch_cmd = "%s %s > /dev/null 2>&1 & echo \\$!" % [binary_path, data_dir]

		OS.execute("bash", ["-c", launch_cmd], output)
		if output.size() > 0:
			_pid = int(output[0].strip_edges())
	else:
		# Windows: use PowerShell
		var ps_cmd = 'Start-Process -FilePath "%s" -ArgumentList "%s" -NoNewWindow -PassThru | Select-Object -ExpandProperty Id' % [binary_path, data_dir]
		OS.execute("powershell", ["-Command", ps_cmd], output)
		if output.size() > 0:
			_pid = int(output[0].strip_edges())

	if _pid <= 0:
		var err = "Failed to start lemond process"
		push_error(err)
		server_error.emit(err)
		return

	_is_running = true
	print("lemond started with PID: %d" % _pid)

	# Begin health check polling
	_start_health_polling()


## Check if the server is currently running.
func is_running() -> bool:
	return _is_running


## Stop the lemond subprocess gracefully.
func stop() -> void:
	if not _is_running or _pid <= 0:
		return

	_health_timer.timeout.disconnect(_on_health_timer_timeout)

	print("Stopping lemond (PID %d) ..." % _pid)
	var platform = OS.get_name()

	if platform == "Linux":
		OS.execute("kill", ["-2", str(_pid)], [])
		print("lemond stopped.")
	else:
		# Windows: taskkill
		OS.execute("taskkill", ["/F", "/PID", str(_pid)], [])

	_is_running = false
	_pid = -1


# ── Health check polling ──

func _start_health_polling() -> void:
	_health_check_count = 0
	_startup_timer.start()
	_health_timer.start()


func _on_health_timer_timeout() -> void:
	_health_check_count += 1
	var url = "%s/v1/health" % LlmConfig.get_base_url()
	var headers = ["Authorization: Bearer %s" % LlmConfig.get_api_key()]
	var error = _http_client.request(url, headers, HTTPClient.METHOD_GET, "")
	if error != OK:
		push_warning("Health check request failed: %d" % error)


func _on_health_check_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		_startup_timer.timeout.disconnect(_on_startup_timeout)
		_startup_timer.stop()
		_health_timer.timeout.disconnect(_on_health_timer_timeout)
		_health_timer.stop()
		print("lemond health check passed after %d attempts." % _health_check_count)
		server_ready.emit()
	elif response_code == 0:
		# Connection refused — server not ready yet
		if _startup_timer.is_stopped():
			# Timeout already fired
			pass
		else:
			# Retry
			_health_timer.start()
	else:
		push_warning("Health check returned: %d" % response_code)
		# Retry on non-200 non-connection-refused
		_health_timer.start()


func _on_startup_timeout() -> void:
	_health_timer.timeout.disconnect(_on_health_timer_timeout)
	_health_timer.stop()
	var err = "lemond did not become ready within %ds" % LlmConfig.get_startup_timeout_s()
	push_error(err)
	server_error.emit(err)
	_is_running = false
