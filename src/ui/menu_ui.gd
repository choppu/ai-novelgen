## MenuUI — Shared factory functions for main menu and pause menu UI.
##
## Provides styled buttons, section headers, slider rows, and save slot
## rows so both menus look consistent. Attach nothing — use as a utility
## module via `preload` or `load`.

class_name MenuUI
extends RefCounted


# ── Full-width menu button (main menu style) ────────────────────
## Creates a full-width styled button matching the main menu's
## button style. Adds it directly to the given parent container.
## Uses story config for width, height, colors, fonts, borders.
##
## Usage:
##   MenuUI.add_menu_button(vbox_container, "New Game", func(): ...)

static func add_menu_button(parent: Container, text: String, callback: Callable) -> void:
	var style = StoryStyle.instance()
	var container = Control.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(style.get_menu_button_width(), style.get_menu_button_height())
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var normal_box = StyleBoxFlat.new()
	normal_box.bg_color = style.get_menu_button_bg()
	normal_box.set_corner_radius_all(4)
	normal_box.set_border_width_all(style.get_menu_button_border_width())
	normal_box.border_color = style.get_menu_button_border_color()
	normal_box.content_margin_left = 20
	normal_box.content_margin_right = 20
	normal_box.content_margin_top = 15
	normal_box.content_margin_bottom = 15

	var hover_box = StyleBoxFlat.new()
	hover_box.bg_color = style.get_menu_button_hover()
	hover_box.set_corner_radius_all(4)
	hover_box.set_border_width_all(style.get_menu_button_border_width())
	hover_box.border_color = style.get_menu_button_border_color()
	hover_box.content_margin_left = 20
	hover_box.content_margin_right = 20
	hover_box.content_margin_top = 15
	hover_box.content_margin_bottom = 15

	panel.add_theme_stylebox_override("panel", normal_box)
	container.add_child(panel)

	# Text label
	var label = Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", style.get_menu_button_text())
	label.add_theme_font_override("font", VNTheme.get_font_choice())
	label.add_theme_font_size_override("font_size", style.get_menu_button_size())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	var normal_text = style.get_menu_button_text()
	var hover_text = Color(0.3, 0.3, 0.3, 1.0)

	if callback:
		container.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: callback.call())
	container.mouse_entered.connect(func():
			SoundEvents.play("choice_hover")
			panel.add_theme_stylebox_override("panel", hover_box)
			label.add_theme_color_override("font_color", hover_text))
	container.mouse_exited.connect(func():
			panel.add_theme_stylebox_override("panel", normal_box)
			label.add_theme_color_override("font_color", normal_text))

	parent.add_child(container)


# ── Centered styled button (sub-menu style) ─────────────────────
## Creates a Control with a Panel + Label that matches the story's
## menu button style. Returns the Control (not a Button).
##
## Usage:
##   var btn = MenuUI.create_button("New Game", Vector2(150, 60))
##   btn.gui_input.connect(func(event): ...)
##   container.add_child(btn)

static func create_button(text: String, size: Vector2) -> Control:
	var style = StoryStyle.instance()
	var container = Control.new()
	container.custom_minimum_size = size
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var normal_box = StyleBoxFlat.new()
	normal_box.bg_color = style.get_menu_button_bg()
	normal_box.set_corner_radius_all(6)
	normal_box.set_border_width_all(3)
	normal_box.border_color = Color(1, 1, 1, 1)
	normal_box.content_margin_left = 14
	normal_box.content_margin_right = 14
	normal_box.content_margin_top = 8
	normal_box.content_margin_bottom = 8

	var hover_box = StyleBoxFlat.new()
	hover_box.bg_color = style.get_menu_button_hover()
	hover_box.set_corner_radius_all(6)
	hover_box.set_border_width_all(3)
	hover_box.border_color = Color(1, 1, 1, 1)
	hover_box.content_margin_left = 14
	hover_box.content_margin_right = 14
	hover_box.content_margin_top = 8
	hover_box.content_margin_bottom = 8

	panel.add_theme_stylebox_override("panel", normal_box)
	container.add_child(panel)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(center)

	var label = Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", style.get_menu_button_text())
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_font_override("font", VNTheme.get_font_name())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	var normal_text = style.get_menu_button_text()
	var hover_text = Color(0.3, 0.3, 0.3, 1.0)

	container.mouse_entered.connect(func():
			SoundEvents.play("choice_hover")
			panel.add_theme_stylebox_override("panel", hover_box)
			label.add_theme_color_override("font_color", hover_text))
	container.mouse_exited.connect(func():
			panel.add_theme_stylebox_override("panel", normal_box)
			label.add_theme_color_override("font_color", normal_text))

	return container


# ── Section header with underline ───────────────────────────────
## Adds an uppercase label with a separator line underneath to the
## given parent container. Shrink-to-fit horizontally.

static func add_section_header(parent: Container, text: String) -> void:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)

	var lbl = Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_font_override("font", VNTheme.get_font_choice())
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1.0))
	col.add_child(lbl)

	var line = ColorRect.new()
	line.color = Color(0.25, 0.25, 0.30, 1.0)
	line.custom_minimum_size = Vector2(0, 5)
	line.size_flags_horizontal = Control.SIZE_FILL
	col.add_child(line)


# ── Slider row ──────────────────────────────────────────────────
## Adds a label + slider + percentage label row to the parent.

static func add_slider_row(parent: Container, label_text: String, value: float, callback: Callable, min_val: float = 0.0) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.custom_minimum_size = Vector2(1200, 64)
	parent.add_child(hbox)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_font_override("font", VNTheme.get_font_name())
	label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
	hbox.add_child(label)

	var slider = CustomSlider.new()
	slider.set_min_value(min_val)
	slider.set_max_value(1.0)
	slider.set_value(value)
	slider.set_dimensions(15, 10)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(900, 48)
	slider.set_colors(
		Color(0.18, 0.18, 0.22, 1.0),
		Color(0.6, 0.15, 0.18, 1.0),
		Color(0.92, 0.92, 0.92, 1.0)
	)
	slider.value_changed.connect(callback)
	hbox.add_child(slider)

	var val_label = Label.new()
	val_label.text = "%d%%" % int(value * 100)
	val_label.custom_minimum_size = Vector2(42, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 32)
	val_label.add_theme_font_override("font", VNTheme.get_font_name())
	val_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
	slider.value_changed.connect(func(v): val_label.text = "%d%%" % int(v * 100))
	hbox.add_child(val_label)


# ── Save slot row ───────────────────────────────────────────────
## Adds a slot row (slot label + info + Load button + Del button) to
## the parent. Uses the same styled buttons as the main menu.
##
## on_load and on_delete are Callables invoked when the respective
## buttons are clicked (only connected if the slot is not empty).

static func add_slot_row(parent: Container, slot: int, info: Dictionary, on_load: Callable, on_delete: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	hbox.custom_minimum_size = Vector2(0, 56)
	parent.add_child(hbox)

	var slot_lbl = Label.new()
	slot_lbl.text = "Slot %d" % (slot + 1)
	slot_lbl.custom_minimum_size = Vector2(100, 0)
	slot_lbl.add_theme_font_size_override("font_size", 32)
	slot_lbl.add_theme_font_override("font", VNTheme.get_font_name())
	slot_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
	hbox.add_child(slot_lbl)

	var info_lbl = Label.new()
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if info.get("empty", true):
		info_lbl.text = "(empty)"
		info_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.40, 1.0))
	else:
		info_lbl.text = "Scene: %s  |  %s" % [info.get("scene", "?"), info.get("timestamp", "")]
		info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 1.0))
	info_lbl.add_theme_font_size_override("font_size", 28)
	info_lbl.add_theme_font_override("font", VNTheme.get_font_dialogue())
	hbox.add_child(info_lbl)

	var load_btn = create_button("Load", Vector2(100, 50))
	if info.get("empty", true):
		load_btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
		load_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		load_btn.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					SoundEvents.play("choice_click")
					on_load.call())
	hbox.add_child(load_btn)

	var del_btn = create_button("Del", Vector2(75, 50))
	if info.get("empty", true):
		del_btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
		del_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		del_btn.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					SoundEvents.play("choice_click")
					on_delete.call())
	hbox.add_child(del_btn)


# ── Centered button row ─────────────────────────────────────────
## Creates an HBoxContainer that shrinks to content and centers
## horizontally within its parent.

static func create_centered_button_row(parent: Container, separation: int = 100) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row
