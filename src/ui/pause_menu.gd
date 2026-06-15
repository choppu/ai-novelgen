## PauseMenu — In-game pause overlay with Save, Load, Settings, Exit to Menu.
##
## Created dynamically by MainController when player presses ESC.
## Blocks input to the game while open.
##
## Usage:
##   var pause = PauseMenu.new()
##   add_child(pause)
##   pause.show_pause_menu()
##   # ... later ...
##   pause.hide_pause_menu()
##   pause.queue_free()

extends Control


# ── Signals ─────────────────────────────────────────────────────

signal save_requested
signal exit_to_menu_requested
signal closed


# ── Internal nodes ──────────────────────────────────────────────
var _backdrop: ColorRect
var _container: VBoxContainer
var _settings_panel: Control


# ── Public API ──────────────────────────────────────────────────

## Show the pause menu.
func show_pause_menu() -> void:
	get_viewport().set_input_as_handled()
	_backdrop.visible = true
	_clear_buttons()
	_add_pause_buttons()


## Hide the pause menu.
func hide_pause_menu() -> void:
	_backdrop.visible = false
	_container.visible = false


## Hide and free this menu.
func close_menu() -> void:
	hide_pause_menu()
	closed.emit()
	queue_free()


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_build_container()


func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)


func _build_container() -> void:
	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_container.anchor_top = 0.25
	_container.anchor_bottom = 0.75
	_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_container.add_theme_constant_override("separation", 12)
	_container.visible = false
	add_child(_container)


func _clear_buttons() -> void:
	_container.visible = false
	# Collect children first (can't modify collection while iterating)
	var children = _container.get_children()
	for child in children:
		_container.remove_child(child)
		child.queue_free()
	if _settings_panel:
		_settings_panel.get_parent().remove_child(_settings_panel)
		_settings_panel.queue_free()
		_settings_panel = null


## Clear sub-panel content and show the main pause buttons.
## Used by Back buttons in settings/load panels.
func _show_main_buttons() -> void:
	_clear_buttons()
	_add_pause_buttons()


func _add_pause_buttons() -> void:
	_add_button("Save Game", func(): _on_save())
	_add_button("Load Game", func(): _on_load())
	_add_button("Settings", func(): _on_settings())
	_add_button("Exit to Menu", func(): _on_exit_to_menu())
	_add_button("Resume", func(): close_menu())
	_container.visible = true


func _add_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(260, 45)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.16, 0.95)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.22, 0.22, 0.32, 1.0)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.18, 0.28, 0.95)
	hover.set_corner_radius_all(8)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.38, 0.38, 0.55, 1.0)
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 10
	hover.content_margin_bottom = 10

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	btn.add_theme_font_size_override("font_size", 18)

	btn.pressed.connect(callback)
	btn.mouse_entered.connect(func():
			SoundEvents.play("choice_hover"))

	_container.add_child(btn)
	return btn


# ── Actions ─────────────────────────────────────────────────────

func _on_save() -> void:
	SoundEvents.play("choice_click")
	save_requested.emit()
	close_menu()


func _on_load() -> void:
	SoundEvents.play("choice_click")
	# Show load panel within pause menu
	_show_load_panel()


func _on_settings() -> void:
	SoundEvents.play("choice_click")
	_show_settings_panel()


func _on_exit_to_menu() -> void:
	SoundEvents.play("choice_click")
	exit_to_menu_requested.emit()


# ── Settings Panel (in pause context) ──────────────────────────

func _show_settings_panel() -> void:
	_clear_buttons()

	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	_container.add_child(title)

	# Audio
	var section = Label.new()
	section.text = "— Audio —"
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_font_size_override("font_size", 16)
	section.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
	_container.add_child(section)

	_add_slider_row("Master", SettingsManager.master_volume, func(v): SettingsManager.master_volume = v)
	_add_slider_row("BGM", SettingsManager.bgm_volume, func(v): SettingsManager.bgm_volume = v)
	_add_slider_row("SFX", SettingsManager.sfx_volume, func(v): SettingsManager.sfx_volume = v)
	_add_slider_row("Voice", SettingsManager.voice_volume, func(v): SettingsManager.voice_volume = v)

	# Display
	var section2 = Label.new()
	section2.text = "— Display —"
	section2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section2.add_theme_font_size_override("font_size", 16)
	section2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
	_container.add_child(section2)

	_add_slider_row("Brightness", SettingsManager.brightness, func(v): SettingsManager.brightness = v, 0.1)
	_add_slider_row("Text Speed", SettingsManager.text_speed, func(v): SettingsManager.text_speed = v, 0.25)

	# Buttons
	var apply_btn = Button.new()
	apply_btn.text = "Apply & Back"
	apply_btn.custom_minimum_size = Vector2(200, 40)
	_apply_small_button_style(apply_btn)
	apply_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			SettingsManager.apply_settings()
			_show_main_buttons())
	_container.add_child(apply_btn)

	# Back button (return without applying)
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(200, 40)
	_apply_small_button_style(back_btn)
	back_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			_show_main_buttons())
	_container.add_child(back_btn)

	_container.visible = true


func _add_slider_row(label: String, value: float, callback: Callable, min_val: float = 0.0) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size = Vector2(0, 25)
	_container.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1.0))
	hbox.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = 1.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	hbox.add_child(slider)

	var val_lbl = Label.new()
	val_lbl.text = "%d%%" % int(value * 100)
	val_lbl.custom_minimum_size = Vector2(40, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1.0))
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % int(v * 100))
	hbox.add_child(val_lbl)


func _apply_small_button_style(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.16, 0.95)
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.22, 0.22, 0.32, 1.0)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.18, 0.28, 0.95)
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.38, 0.38, 0.55, 1.0)
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	btn.add_theme_font_size_override("font_size", 16)


# ── Load Panel (in pause context) ──────────────────────────────

func _show_load_panel() -> void:
	_clear_buttons()

	var title = Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1.0))
	_container.add_child(title)

	for i in range(SaveManager.MAX_SLOTS):
		var slot_info = SaveManager.get_slot_info(i)
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.custom_minimum_size = Vector2(0, 40)
		_container.add_child(hbox)

		var slot_lbl = Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.custom_minimum_size = Vector2(60, 0)
		slot_lbl.add_theme_font_size_override("font_size", 14)
		slot_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
		hbox.add_child(slot_lbl)

		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot_info.get("empty", true):
			info_lbl.text = "(empty)"
			info_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 1.0))
		else:
			info_lbl.text = "%s  (%s)" % [slot_info.get("scene", "?"), slot_info.get("timestamp", "")]
			info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1.0))
		info_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(info_lbl)

		var load_btn = Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(70, 28)
		load_btn.disabled = slot_info.get("empty", true)
		_apply_small_button_style(load_btn)
		if slot_info.get("empty", true):
			load_btn.modulate = Color(0.4, 0.4, 0.4, 1.0)
		load_btn.pressed.connect(func():
				SoundEvents.play("choice_click")
				if SaveManager.load_slot(i):
					SaveManager.queue_load(i)
					get_tree().reload_current_scene())
		hbox.add_child(load_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 36)
	_apply_small_button_style(back_btn)
	back_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			_show_main_buttons())
	_container.add_child(back_btn)
	_container.visible = true
