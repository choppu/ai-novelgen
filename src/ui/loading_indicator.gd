## LoadingIndicator — Center-screen animated three-dot indicator.
##
## Usage:
##   var loading = LoadingIndicator.new()
##   add_child(loading)
##   loading.show_loading()
##   # ... later ...
##   loading.hide_loading()

extends Control
class_name LoadingIndicator


# ── Input handling ──────────────────────────────────────────────
## Ignore mouse input so clicks pass through to buttons/input below.


func _unhandled_input(event: InputEvent) -> void:
	## Consume keyboard events while visible so they don't propagate
	## to _unhandled_input on parent nodes.
	if visible and event is InputEventKey:
		get_viewport().set_input_as_handled()


# ── Internal nodes ──────────────────────────────────────────────
var _dot1: Label
var _dot2: Label
var _dot3: Label
var _frame_counter: int = 0


# ── Public API ──────────────────────────────────────────────────

## Show the loading indicator.
func show_loading(_message: String = "") -> void:
	self.visible = true


## Hide the loading indicator.
func hide_loading() -> void:
	self.visible = false


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.visible = false
	_build_dots()


func _build_dots() -> void:
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	for i in range(3):
		var dot = Label.new()
		dot.text = "\u2022"
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_theme_color_override("font_color", VNTheme.get_loading_color())
		dot.add_theme_font_override("font", VNTheme.get_font_dialogue())
		dot.add_theme_font_size_override("font_size", VNTheme.get_font_size_dialogue() + 8)
		dot.visible = false
		hbox.add_child(dot)
		if i == 0:
			_dot1 = dot
		elif i == 1:
			_dot2 = dot
		else:
			_dot3 = dot


func _process(_delta: float) -> void:
	if not visible:
		return

	var t = float(_frame_counter) / 12.0
	_frame_counter += 1
	_dot1.visible = sin(t) > -0.3
	_dot2.visible = sin(t + 2.094) > -0.3
	_dot3.visible = sin(t + 4.189) > -0.3
