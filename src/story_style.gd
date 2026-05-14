## StoryStyle — Loads story-specific visual styles from JSON.
##
## Each story folder may contain a `styles.json` file with colours,
## typography, and timing settings. This class reads that file once
## on first access and provides typed accessors for all values.
##
## If no `styles.json` exists for the current story, sensible defaults
## are returned so the engine still works.
##
## Usage:
##   var c = StoryStyle.get_color("speaker")        # → Color
##   var s = StoryStyle.get_font_size("dialogue")    # → int
##   var t = StoryStyle.get_typewriter_speed()       # → float
##
## This is a utility class — attach nothing. Call static methods.

class_name StoryStyle


# ── Internal state ──────────────────────────────────────────────
var _loaded: bool = false
var _data: Dictionary = {}


# ── Singleton access ────────────────────────────────────────────

## Get the singleton instance, loading on first call.
static func instance() -> StoryStyle:
	var s: StoryStyle = StoryStyle.new()
	s._ensure_loaded()
	return s


# ── Loading ─────────────────────────────────────────────────────

func _ensure_loaded() -> void:
	if _loaded:
		return

	_loaded = true

	# Determine story name
	var story_name := ""
	if Engine.has_singleton("GameConfig"):
		var gc: Variant = Engine.get_singleton("GameConfig")
		story_name = gc.get_current_story()

	if story_name.is_empty():
		print("[StoryStyle] No story configured — using defaults.")
		_data = _make_defaults()
		return

	var style_path := "res://stories/%s/styles.json" % story_name
	var file: FileAccess = FileAccess.open(style_path, FileAccess.READ)

	if file == null:
		var err: Error = FileAccess.get_open_error()
		print("[StoryStyle] Could not open %s (error %d) — using defaults." % [style_path, err])
		_data = _make_defaults()
		return

	var raw: String = file.get_as_text()
	file.close()

	var parse_result: Variant = JSON.parse_string(raw)
	if parse_result is Dictionary:
		_data = parse_result as Dictionary
		print("[StoryStyle] Loaded styles for story '%s' from %s" % [story_name, style_path])
	else:
		print("[StoryStyle] Failed to parse %s — using defaults." % style_path)
		_data = _make_defaults()


func _make_defaults() -> Dictionary:
	## Mirror of the default values from VNTheme.
	return {
		"colors": {
			"bg":              [0.05, 0.05, 0.07, 1.0],
			"text":            [0.95, 0.95, 0.92, 1.0],
			"narration":       [0.80, 0.80, 0.78, 1.0],
			"speaker":         [0.936, 0.967, 1.0, 1.0],
			"player":          [0.70, 0.85, 1.00, 1.0],
			"description":     [0.85, 0.85, 0.80, 1.0],
			"dialogue_box_bg":       [0.06, 0.06, 0.10, 0.88],
			"dialogue_box_border":   [0.30, 0.35, 0.50, 0.9],
			"choice_bg":         [0.12, 0.16, 0.28, 0.92],
			"choice_hover":      [0.22, 0.30, 0.50, 0.95],
			"choice_focus":      [0.30, 0.40, 0.65, 0.95],
			"input_bg":           [0.12, 0.12, 0.15, 1.0],
			"input_border":       [0.25, 0.30, 0.40, 1.0],
			"error_bg":           [0.50, 0.15, 0.15, 0.9],
			"error_text":         [1.0, 0.8, 0.8, 1.0],
			"loading":            [0.50, 0.50, 0.55, 1.0],
		},
		"typography": {
			"font_size_name":         26,
			"font_size_dialogue":     22,
			"font_size_description":  22,
			"font_size_choice":       20,
			"font_size_error":        18,
			"font_size_continue":     20,
		},
		"timing": {
			"typewriter_speed":      0.035,
			"blink_interval":        0.6,
			"description_fade_in":   0.8,
			"description_fade_out":  1.0,
			"description_min_hold":  2.0,
			"description_max_hold":  6.0,
			"description_char_time": 0.03,
			"error_auto_dismiss":    5.0,
		},
	}


# ── Helpers ─────────────────────────────────────────────────────

func _get_colors() -> Dictionary:
	var c: Variant = _data.get("colors")
	return c if c is Dictionary else Dictionary()

func _get_typography() -> Dictionary:
	var t: Variant = _data.get("typography")
	return t if t is Dictionary else Dictionary()

func _get_timing() -> Dictionary:
	var t: Variant = _data.get("timing")
	return t if t is Dictionary else Dictionary()


func _get_color(key: String) -> Color:
	var colors_dict: Dictionary = _get_colors()
	var val: Variant = colors_dict.get(key)
	if val is Array and val.size() >= 3:
		return Color(float(val[0]), float(val[1]), float(val[2]), float(val[3] if val.size() > 3 else 1.0))
	return Color.WHITE


func _get_int(key: String, default: int = 0) -> int:
	var v: Variant = _get_typography().get(key)
	if v is int:
		return v
	return default


func _get_float(key: String, default: float = 0.0) -> float:
	var v: Variant = _get_timing().get(key)
	if v is float:
		return v
	if v is int:
		return float(v)
	return default


# ── Colour accessors ───────────────────────────────────────────

func get_bg_color()            -> Color: return _get_color("bg")
func get_text_color()          -> Color: return _get_color("text")
func get_narration_color()     -> Color: return _get_color("narration")
func get_speaker_color()       -> Color: return _get_color("speaker")
func get_player_color()        -> Color: return _get_color("player")
func get_description_color()   -> Color: return _get_color("description")

func get_dialogue_box_bg()     -> Color: return _get_color("dialogue_box_bg")
func get_dialogue_box_border() -> Color: return _get_color("dialogue_box_border")

func get_choice_bg()           -> Color: return _get_color("choice_bg")
func get_choice_hover()        -> Color: return _get_color("choice_hover")
func get_choice_focus()        -> Color: return _get_color("choice_focus")

func get_input_bg()            -> Color: return _get_color("input_bg")
func get_input_border()        -> Color: return _get_color("input_border")

func get_error_bg()            -> Color: return _get_color("error_bg")
func get_error_text()          -> Color: return _get_color("error_text")

func get_loading_color()       -> Color: return _get_color("loading")


# ── Typography accessors ────────────────────────────────────────

func get_font_size_name()         -> int: return _get_int("font_size_name")
func get_font_size_dialogue()     -> int: return _get_int("font_size_dialogue")
func get_font_size_description()  -> int: return _get_int("font_size_description")
func get_font_size_choice()       -> int: return _get_int("font_size_choice")
func get_font_size_error()        -> int: return _get_int("font_size_error")
func get_font_size_continue()     -> int: return _get_int("font_size_continue")


# ── Timing accessors ────────────────────────────────────────────

func get_typewriter_speed()      -> float: return _get_float("typewriter_speed")
func get_blink_interval()        -> float: return _get_float("blink_interval")
func get_description_fade_in()   -> float: return _get_float("description_fade_in")
func get_description_fade_out()  -> float: return _get_float("description_fade_out")
func get_description_min_hold()  -> float: return _get_float("description_min_hold")
func get_description_max_hold()  -> float: return _get_float("description_max_hold")
func get_description_char_time() -> float: return _get_float("description_char_time")
func get_error_auto_dismiss()    -> float: return _get_float("error_auto_dismiss")
