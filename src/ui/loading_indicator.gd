## LoadingIndicator — Center-screen "Thinking..." label.
##
## Usage:
##   var loading = LoadingIndicator.new()
##   add_child(loading)
##   loading.show_loading("Thinking")
##   # ... later ...
##   loading.hide_loading()

extends Control
class_name LoadingIndicator


# ── Internal nodes ──────────────────────────────────────────────
var _label: Label


# ── Public API ──────────────────────────────────────────────────

## Show the loading indicator with the given message.
func show_loading(message: String = "Thinking") -> void:
	_label.text = "%s..." % message
	_label.visible = true


## Hide the loading indicator.
func hide_loading() -> void:
	_label.text = ""
	_label.visible = false


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_label()


func _build_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", VNTheme.LOADING_COLOR)
	_label.add_theme_font_size_override("font_size", VNTheme.FONT_SIZE_DIALOGUE)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.visible = false
	add_child(_label)
