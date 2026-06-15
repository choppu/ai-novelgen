## SettingsManager — Singleton that manages game settings persistence.
##
## Autoloaded as "SettingsManager". Handles:
##   • Audio volumes (master, BGM, SFX, voice)
##   • Text speed (typewriter effect)
##   • Screen brightness
##   • Auto-save on quit
##
## Settings are persisted to user://settings.json.
##
## Usage:
##   SettingsManager.master_volume = 0.8
##   SettingsManager.brightness = 0.6
##   SettingsManager.apply()  # syncs to SoundManager + viewport

extends Node


const SETTINGS_PATH := "user://settings.json"

# ── Settings ────────────────────────────────────────────────────

var master_volume: float = 1.0
var bgm_volume: float = 0.2
var sfx_volume: float = 0.7
var voice_volume: float = 0.9
var text_speed: float = 1.0  # multiplier: 0.5 = slow, 1.0 = normal, 2.0 = fast
var brightness: float = 1.0  # 0.0 = very dark, 1.0 = full brightness


# ── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	_load_settings()
	apply_settings()


# ── Persistence ─────────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or data is not Dictionary:
		return

	master_volume = _clamp(data.get("master_volume", master_volume), 0.0, 1.0)
	bgm_volume = _clamp(data.get("bgm_volume", bgm_volume), 0.0, 1.0)
	sfx_volume = _clamp(data.get("sfx_volume", sfx_volume), 0.0, 1.0)
	voice_volume = _clamp(data.get("voice_volume", voice_volume), 0.0, 1.0)
	text_speed = _clamp(data.get("text_speed", text_speed), 0.25, 3.0)
	brightness = _clamp(data.get("brightness", brightness), 0.1, 1.0)

	print("[SettingsManager] Loaded settings from %s" % SETTINGS_PATH)


func save_settings() -> void:
	var data = {
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"text_speed": text_speed,
		"brightness": brightness,
	}

	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SettingsManager] Cannot write settings file")
		return

	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[SettingsManager] Settings saved")


# ── Apply ───────────────────────────────────────────────────────

## Apply current settings to SoundManager and viewport.
func apply_settings() -> void:
	_apply_audio()
	_apply_brightness()
	save_settings()


func apply_audio_only() -> void:
	_apply_audio()
	save_settings()


func _apply_audio() -> void:
	if SoundManager:
		SoundManager.set_master_volume(master_volume)
		SoundManager.set_bgm_volume(bgm_volume)
		SoundManager.set_sfx_volume(sfx_volume)
		SoundManager.set_voice_volume(voice_volume)


func _apply_brightness() -> void:
	# Brightness is applied via a dark overlay in each scene's root node.
	# No-op here — scenes that want brightness support add a ColorRect overlay
	# and connect to SettingsManager.brightness changes.
	pass


# ── Helpers ─────────────────────────────────────────────────────

func _clamp(value: float, min_val: float, max_val: float) -> float:
	return clampf(float(value), min_val, max_val)
