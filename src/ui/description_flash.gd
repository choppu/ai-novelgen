## DescriptionFlash — Scene description label that fades in, holds, then fades out.
##
## Positioned at the top-center of the screen. Automatically computes
## a hold duration based on text length (min 2s, max 6s).
##
## Usage:
##   var flash = DescriptionFlash.new()
##   add_child(flash)
##   flash.show_text("You arrive at the old mansion...")

extends Control
class_name DescriptionFlash


# ── Internal nodes ──────────────────────────────────────────────
var _label: Label


# ── Public API ──────────────────────────────────────────────────

## Show the description text with fade-in / hold / fade-out animation.
## This is an async function — it yields until the animation completes.
func show_text(text: String) -> void:
	_label.text = text
	_label.visible = true
	_label.modulate = Color(1, 1, 1, 0)

	# Fade in
	var tween_in = create_tween()
	tween_in.tween_property(_label, "modulate", Color(1, 1, 1, 1), VNTheme.get_description_fade_in())

	# Hold for reading time
	var hold_time = clampf(
		VNTheme.get_description_min_hold() + text.length() * VNTheme.get_description_char_time(),
		VNTheme.get_description_min_hold(),
		VNTheme.get_description_max_hold()
	)

	await get_tree().create_timer(hold_time).timeout

	# Fade out
	var tween_out = create_tween()
	tween_out.tween_property(_label, "modulate", Color(1, 1, 1, 0), VNTheme.get_description_fade_out())
	tween_out.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	_label.visible = false
	_label.text = ""


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_label()


func _build_label() -> void:
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_color_override("font_color", VNTheme.get_description_color())
	_label.add_theme_font_override("font", VNTheme.get_font_narration())
	_label.add_theme_font_size_override("font_size", VNTheme.get_font_size_description())
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.anchor_bottom = 0.35
	_label.offset_top = 40
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.modulate = Color(1, 1, 1, 0)
	_label.visible = false
	add_child(_label)
