## MainMenu - Story-configurable title screen.
##
## Reads styling from the current story's styles.json "menu" section:
##   • Background image with dark overlay
##   • Title (from story metadata) and subtitle (from story author)
##   • Button labels, colors, sizes, positions
##   • Fade transition to game scene
##
## Falls back to sensible defaults if no menu config exists.

extends Control


# ── Internal nodes ──────────────────────────────────────────────
var _bg_texture: TextureRect
var _bg_overlay: ColorRect
var _logo_texture: TextureRect
var _title_label: Label          # fallback when no logo
var _subtitle_label: Label       # fallback when no logo
var _button_container: VBoxContainer
var _fade_rect: ColorRect

# ── State ───────────────────────────────────────────────────────
var _active_panel: String = "menu"  # "menu", "settings", "load"
var _settings_panel: Control
var _load_panel: Control


# ── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_show_menu()


# ── UI Construction ─────────────────────────────────────────────

func _build_ui() -> void:
	var style = StoryStyle.instance()

	# ── Background image ──
	var bg_path = style.get_menu_background_path()
	_bg_texture = TextureRect.new()
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bg_path.is_empty() and ResourceLoader.exists(bg_path):
		var tex = load(bg_path)
		if tex is Texture2D:
			_bg_texture.texture = tex
	add_child(_bg_texture)

	# ── Dark overlay ──
	_bg_overlay = ColorRect.new()
	_bg_overlay.color = style.get_menu_overlay_color()
	_bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_overlay)

	# ── Logo (from story's logo/logo.png) or title+subtitle fallback ──
	var logo_path = style.get_menu_logo_path()
	var has_logo = not logo_path.is_empty() and ResourceLoader.exists(logo_path)

	if has_logo:
		_logo_texture = TextureRect.new()
		_logo_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo_texture.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_logo_texture.custom_minimum_size = Vector2(650, 650)
		_logo_texture.anchor_top = style.get_menu_title_y()
		_logo_texture.anchor_bottom = style.get_menu_title_y()
		_logo_texture.offset_bottom = 200
		_logo_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo_texture.texture = load(logo_path)
		add_child(_logo_texture)

		# Create hidden fallback labels (kept for API compat)
		_title_label = Label.new()
		_title_label.visible = false
		add_child(_title_label)
		_subtitle_label = Label.new()
		_subtitle_label.visible = false
		add_child(_subtitle_label)
	else:
		_logo_texture = TextureRect.new()
		_logo_texture.visible = false
		add_child(_logo_texture)

		# ── Title (from story metadata) ──
		_title_label = Label.new()
		var story_title = _get_story_title()
		_title_label.text = story_title if not story_title.is_empty() else ""
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_title_label.anchor_top = style.get_menu_title_y()
		_title_label.anchor_bottom = style.get_menu_title_y()
		_title_label.offset_bottom = 30
		_title_label.add_theme_font_size_override("font_size", style.get_menu_title_size())
		_title_label.add_theme_color_override("font_color", style.get_menu_title_color())
		_title_label.add_theme_font_override("font", VNTheme.get_font_title())
		add_child(_title_label)

		# ── Subtitle (from story author) ──
		_subtitle_label = Label.new()
		var story_author = _get_story_author()
		_subtitle_label.text = story_author if not story_author.is_empty() else ""
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_subtitle_label.anchor_top = style.get_menu_subtitle_y()
		_subtitle_label.anchor_bottom = style.get_menu_subtitle_y()
		_subtitle_label.offset_bottom = 0
		_subtitle_label.add_theme_font_size_override("font_size", style.get_menu_subtitle_size())
		_subtitle_label.add_theme_color_override("font_color", style.get_menu_subtitle_color())
		_subtitle_label.add_theme_font_override("font", VNTheme.get_font_dialogue())
		add_child(_subtitle_label)

	# ── Button container (shrinks to content, centered horizontally) ──
	_button_container = VBoxContainer.new()
	_button_container.anchor_left = 0.5
	_button_container.anchor_right = 0.5
	_button_container.anchor_top = style.get_menu_button_top()
	_button_container.anchor_bottom = style.get_menu_button_bottom()
	_button_container.offset_left = -250
	_button_container.offset_right = 250
	_button_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_button_container.add_theme_constant_override("separation", style.get_menu_button_separation())
	add_child(_button_container)

	# ── Fade overlay (for transitions) ──
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func _get_story_title() -> String:
	# Read title from story.json metadata
	var story_name = ""
	if GameConfig != null:
		story_name = GameConfig.get_current_story()
	if story_name.is_empty():
		return ""
	var path = "res://stories/%s/story.json" % story_name
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var metadata = data.get("metadata", {})
		if metadata is Dictionary:
			return metadata.get("title", "")
	return ""


func _get_story_author() -> String:
	var story_name = ""
	if GameConfig != null:
		story_name = GameConfig.get_current_story()
	if story_name.is_empty():
		return ""
	var path = "res://stories/%s/story.json" % story_name
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		var metadata = data.get("metadata", {})
		if metadata is Dictionary:
			return metadata.get("author", "")
	return ""


# ── Menu Navigation ─────────────────────────────────────────────

func _show_menu() -> void:
	_hide_sub_panel()
	_button_container.visible = true
	_logo_texture.visible = true
	_title_label.visible = true
	_subtitle_label.visible = true
	_clear_buttons()
	_add_menu_buttons()
	_active_panel = "menu"


func _hide_sub_panel() -> void:
	_button_container.visible = false
	if _settings_panel:
		_settings_panel.visible = false
		_settings_panel = null
	if _load_panel:
		_load_panel.visible = false
		_load_panel = null


func _clear_buttons() -> void:
	for child in _button_container.get_children():
		child.queue_free()


func _add_menu_buttons() -> void:
	var style = StoryStyle.instance()
	var labels = style.get_menu_button_labels()
	var actions = [
		func(): _on_new_game(),
		func(): _on_load_game(),
		func(): _on_settings(),
		func(): _on_quit(),
	]

	for i in range(labels.size()):
		var label = labels[i]
		var action = actions[i] if i < actions.size() else null
		_add_menu_button(label, action)


func _add_menu_button(text: String, callback: Callable) -> void:
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

	_button_container.add_child(container)


# ── Actions ─────────────────────────────────────────────────────

func _on_new_game() -> void:
	SoundEvents.play("choice_click")
	_fade_to_game()


func _on_load_game() -> void:
	SoundEvents.play("choice_click")
	_show_load_panel()


func _on_settings() -> void:
	SoundEvents.play("choice_click")
	_show_settings_panel()


func _on_quit() -> void:
	SoundEvents.play("choice_click")
	get_tree().quit()


func _fade_to_game() -> void:
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/main.tscn"))


# ── Settings Panel ──────────────────────────────────────────────

func _show_settings_panel() -> void:
	_hide_sub_panel()

	_settings_panel = Control.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_panel)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0.12, 0.12, 0.12, 0.9)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(backdrop)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.offset_left = -650
	container.offset_right = 650
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_theme_constant_override("separation", 25)
	_settings_panel.add_child(container)

	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", VNTheme.get_font_name())
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	container.add_child(title)

	MenuUI.add_section_header(container, "Audio")
	MenuUI.add_slider_row(container, "Master", SettingsManager.master_volume, func(v): SettingsManager.master_volume = v)
	MenuUI.add_slider_row(container, "BGM", SettingsManager.bgm_volume, func(v): SettingsManager.bgm_volume = v)
	MenuUI.add_slider_row(container, "SFX", SettingsManager.sfx_volume, func(v): SettingsManager.sfx_volume = v)
	MenuUI.add_slider_row(container, "Voice", SettingsManager.voice_volume, func(v): SettingsManager.voice_volume = v)

	MenuUI.add_section_header(container, "Display")
	MenuUI.add_slider_row(container, "Text Speed", SettingsManager.text_speed, func(v): SettingsManager.text_speed = v, 0.25)

	var btn_row = MenuUI.create_centered_button_row(container)

	var apply_btn = MenuUI.create_button("Apply", Vector2(150, 60))
	apply_btn.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			SoundEvents.play("choice_click")
			SettingsManager.apply_settings()
			_show_menu())
	btn_row.add_child(apply_btn)

	var back_btn = MenuUI.create_button("Back", Vector2(150, 60))
	back_btn.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundEvents.play("choice_click")
				_show_menu())
	btn_row.add_child(back_btn)

	_logo_texture.visible = false
	_title_label.visible = false
	_subtitle_label.visible = false
	_settings_panel.visible = true
	_active_panel = "settings"


# ── Load Game Panel ─────────────────────────────────────────────

func _show_load_panel() -> void:
	_hide_sub_panel()

	_load_panel = Control.new()
	_load_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_load_panel)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0.12, 0.12, 0.12, 0.9)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_panel.add_child(backdrop)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.offset_left = -650
	container.offset_right = 650
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_theme_constant_override("separation", 25)
	_load_panel.add_child(container)

	var title = Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_font_override("font", VNTheme.get_font_name())
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	container.add_child(title)

	MenuUI.add_section_header(container, "Saves")

	for i in range(SaveManager.MAX_SLOTS):
		var slot_info = SaveManager.get_slot_info(i)
		MenuUI.add_slot_row(container, i, slot_info,
			func():
				if SaveManager.load_slot(i):
					SaveManager.queue_load(i)
					_fade_to_game(),
			func():
				SaveManager.delete_slot(i)
				_load_panel.queue_free()
				_show_load_panel())

	var btn_row = MenuUI.create_centered_button_row(container)

	var back_btn = MenuUI.create_button("Back", Vector2(150, 60))
	back_btn.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			SoundEvents.play("choice_click")
			_show_menu())
	btn_row.add_child(back_btn)

	_logo_texture.visible = false
	_title_label.visible = false
	_subtitle_label.visible = false
	_load_panel.visible = true
	_active_panel = "load"
