## ErrorBanner — Top-of-screen error message with auto-dismiss.
##
## Usage:
##   var banner = ErrorBanner.new()
##   add_child(banner)
##   banner.show_error("Connection failed")          # auto-dismisses after 5s
##   banner.show_error("Custom error", 10.0)         # custom duration

extends Control
class_name ErrorBanner


# ── Input handling ──────────────────────────────────────────────
## Ignore mouse input so clicks pass through to buttons/input below.


func _unhandled_input(event: InputEvent) -> void:
	## Consume keyboard events while visible so they don't propagate
	## to _unhandled_input on parent nodes.
	if visible and event is InputEventKey:
		get_viewport().set_input_as_handled()


# ── Internal nodes ──────────────────────────────────────────────
var _label: Label


# ── Public API ──────────────────────────────────────────────────

## Show an error message. Auto-dismisses after [code]duration[/code] seconds.
func show_error(message: String, duration: float = VNTheme.get_error_auto_dismiss()) -> void:
	_label.text = message
	_label.visible = true

	if _label.get_parent():
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func(): _label.visible = false)


## Hide the error banner immediately.
func hide_error() -> void:
	_label.visible = false


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_label()


func _build_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", VNTheme.get_error_text())
	_label.add_theme_font_override("font", VNTheme.get_font_narration())
	_label.add_theme_font_size_override("font_size", VNTheme.get_font_size_error())
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.anchor_bottom = 0.08
	_label.visible = false
	_label.add_theme_stylebox_override("panel", VNTheme.create_filled_panel(VNTheme.get_error_bg()))
	add_child(_label)
