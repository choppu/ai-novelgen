## PauseMenu — In-game pause overlay with Save, Load, Settings, Exit to Menu.
##
## Created dynamically by MainController when player presses ESC.
## Blocks input to the game while open.
##
## Shares UI components with MainMenu via MenuUI for consistent styling.
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
	# Release keyboard focus so Space/Enter advance dialogue instead of
	# activating a stale menu button after the pause menu is freed.
	get_viewport().gui_release_focus()


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
	_backdrop.color = Color(0.12, 0.12, 0.12, 0.9)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)


func _build_container() -> void:
	var style = StoryStyle.instance()
	_container = VBoxContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_container.anchor_left = 0.15
	_container.anchor_right = 0.85
	_container.anchor_top = 0.1
	_container.anchor_bottom = 0.9
	_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_container.add_theme_constant_override("separation", style.get_menu_button_separation())
	_container.visible = false
	add_child(_container)


func _clear_buttons() -> void:
	_container.visible = false
	var children = _container.get_children()
	for child in children:
		_container.remove_child(child)
		child.queue_free()


## Clear sub-panel content and show the main pause buttons.
func _show_main_buttons() -> void:
	_clear_buttons()
	_add_pause_buttons()


func _add_pause_buttons() -> void:
	var btn_wrapper = Control.new()
	btn_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_wrapper.custom_minimum_size = Vector2(StoryStyle.instance().get_menu_button_width(), 0)
	_container.add_child(btn_wrapper)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_vbox.grow_vertical = Control.GROW_DIRECTION_END
	btn_vbox.add_theme_constant_override("separation", StoryStyle.instance().get_menu_button_separation())
	btn_wrapper.add_child(btn_vbox)

	var title = Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", VNTheme.get_font_name())
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	btn_vbox.add_child(title)

	var buttons = [
		{"text": "Save", "action": func(): _on_save()},
		{"text": "Load", "action": func(): _on_load()},
		{"text": "Settings", "action": func(): _on_settings()},
		{"text": "Exit to Menu", "action": func(): _on_exit_to_menu()},
		{"text": "Resume", "action": func(): close_menu()},
	]

	for btn_data in buttons:
		MenuUI.add_menu_button(btn_vbox, btn_data["text"], btn_data["action"])

	_container.visible = true


# ── Actions ─────────────────────────────────────────────────────

func _on_save() -> void:
	SoundEvents.play("choice_click")
	save_requested.emit()
	close_menu()


func _on_load() -> void:
	SoundEvents.play("choice_click")
	_show_load_panel()


func _on_settings() -> void:
	SoundEvents.play("choice_click")
	_show_settings_panel()


func _on_exit_to_menu() -> void:
	SoundEvents.play("choice_click")
	exit_to_menu_requested.emit()


# ── Settings Panel ──────────────────────────────────────────────

func _show_settings_panel() -> void:
	_clear_buttons()

	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", VNTheme.get_font_name())
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	_container.add_child(title)

	MenuUI.add_section_header(_container, "Audio")
	MenuUI.add_slider_row(_container, "Master", SettingsManager.master_volume, func(v): SettingsManager.master_volume = v)
	MenuUI.add_slider_row(_container, "BGM", SettingsManager.bgm_volume, func(v): SettingsManager.bgm_volume = v)
	MenuUI.add_slider_row(_container, "SFX", SettingsManager.sfx_volume, func(v): SettingsManager.sfx_volume = v)
	MenuUI.add_slider_row(_container, "Voice", SettingsManager.voice_volume, func(v): SettingsManager.voice_volume = v)

	MenuUI.add_section_header(_container, "Display")
	MenuUI.add_slider_row(_container, "Text Speed", SettingsManager.text_speed, func(v): SettingsManager.text_speed = v, 0.25)

	var btn_row = MenuUI.create_centered_button_row(_container)

	var apply_btn = MenuUI.create_button("Apply", Vector2(150, 60))
	apply_btn.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundEvents.play("choice_click")
				SettingsManager.apply_settings()
				_show_main_buttons())
	btn_row.add_child(apply_btn)

	var back_btn = MenuUI.create_button("Back", Vector2(150, 60))
	back_btn.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundEvents.play("choice_click")
				_show_main_buttons())
	btn_row.add_child(back_btn)

	_container.visible = true


# ── Load Panel ──────────────────────────────────────────────────

func _show_load_panel() -> void:
	_clear_buttons()

	var title = Label.new()
	title.text = "Load"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", VNTheme.get_font_name())
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	_container.add_child(title)

	MenuUI.add_section_header(_container, "Saves")

	for i in range(SaveManager.MAX_SLOTS):
		var slot_info = SaveManager.get_slot_info(i)
		MenuUI.add_slot_row(_container, i, slot_info,
			func():
				if SaveManager.load_slot(i):
					SaveManager.queue_load(i)
					get_tree().reload_current_scene(),
			func():
				SaveManager.delete_slot(i)
				_clear_buttons()
				_show_load_panel())

	var btn_row = MenuUI.create_centered_button_row(_container)

	var back_btn = MenuUI.create_button("Back", Vector2(150, 60))
	back_btn.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundEvents.play("choice_click")
				_show_main_buttons())
	btn_row.add_child(back_btn)

	_container.visible = true
