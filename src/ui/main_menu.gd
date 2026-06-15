## MainMenu — Story-configurable title screen.
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
var _title_label: Label
var _subtitle_label: Label
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

	# ── Title (from story metadata) ──
	_title_label = Label.new()
	var story_title = _get_story_title()
	_title_label.text = story_title if not story_title.is_empty() else "AI Novelgen"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_label.anchor_top = style.get_menu_title_y()
	_title_label.anchor_bottom = style.get_menu_title_y()
	_title_label.offset_bottom = 0
	_title_label.add_theme_font_size_override("font_size", style.get_menu_title_size())
	_title_label.add_theme_color_override("font_color", style.get_menu_title_color())
	_title_label.add_theme_font_override("font", VNTheme.get_font_name())
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
	_button_container.offset_left = 0
	_button_container.offset_right = 0
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
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(style.get_menu_button_width(), style.get_menu_button_height())

	var normal = StyleBoxFlat.new()
	normal.bg_color = style.get_menu_button_bg()
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.25, 0.28, 0.38, 0.8)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12

	var hover = StyleBoxFlat.new()
	hover.bg_color = style.get_menu_button_hover()
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.40, 0.45, 0.60, 0.9)
	hover.content_margin_left = 20
	hover.content_margin_right = 20
	hover.content_margin_top = 12
	hover.content_margin_bottom = 12

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", style.get_menu_button_text())
	btn.add_theme_font_override("font", VNTheme.get_font_choice())
	btn.add_theme_font_size_override("font_size", style.get_menu_button_size())

	if callback:
		btn.pressed.connect(callback)
	btn.mouse_entered.connect(func():
			SoundEvents.play("choice_hover"))

	_button_container.add_child(btn)


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
	backdrop.color = Color(0.05, 0.05, 0.08, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(backdrop)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.anchor_top = 0.12
	container.anchor_bottom = 0.88
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.add_theme_constant_override("separation", 20)
	_settings_panel.add_child(container)

	var title = Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	container.add_child(title)

	_add_section_header(container, "Audio")
	_add_slider_row(container, "Master", SettingsManager.master_volume, func(v): SettingsManager.master_volume = v)
	_add_slider_row(container, "BGM", SettingsManager.bgm_volume, func(v): SettingsManager.bgm_volume = v)
	_add_slider_row(container, "SFX", SettingsManager.sfx_volume, func(v): SettingsManager.sfx_volume = v)
	_add_slider_row(container, "Voice", SettingsManager.voice_volume, func(v): SettingsManager.voice_volume = v)

	_add_section_header(container, "Display")
	_add_slider_row(container, "Text Speed", SettingsManager.text_speed, func(v): SettingsManager.text_speed = v, 0.25)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	container.add_child(btn_row)

	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.custom_minimum_size = Vector2(110, 38)
	_apply_button_style(apply_btn)
	apply_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			SettingsManager.apply_settings()
			_show_menu())
	btn_row.add_child(apply_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(110, 38)
	_apply_button_style(back_btn)
	back_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			_show_menu())
	btn_row.add_child(back_btn)

	_settings_panel.visible = true
	_active_panel = "settings"


func _add_section_header(parent: Container, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55, 1.0))
	parent.add_child(lbl)


func _add_slider_row(parent: Container, label_text: String, value: float, callback: Callable, min_val: float = 0.0) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.custom_minimum_size = Vector2(0, 28)
	parent.add_child(hbox)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82, 1.0))
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = 1.0
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 0)
	slider.value_changed.connect(callback)
	hbox.add_child(slider)

	var val_label = Label.new()
	val_label.text = "%d%%" % int(value * 100)
	val_label.custom_minimum_size = Vector2(42, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 1.0))
	slider.value_changed.connect(func(v): val_label.text = "%d%%" % int(v * 100))
	hbox.add_child(val_label)


func _apply_button_style(btn: Button) -> void:
	var style = StoryStyle.instance()
	var normal = StyleBoxFlat.new()
	normal.bg_color = style.get_menu_button_bg()
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.25, 0.28, 0.38, 0.8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover = StyleBoxFlat.new()
	hover.bg_color = style.get_menu_button_hover()
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.40, 0.45, 0.60, 0.9)
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", style.get_menu_button_text())
	btn.add_theme_font_size_override("font_size", 15)


# ── Load Game Panel ─────────────────────────────────────────────

func _show_load_panel() -> void:
	_hide_sub_panel()

	_load_panel = Control.new()
	_load_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_load_panel)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.08, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_panel.add_child(backdrop)

	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.anchor_top = 0.10
	container.anchor_bottom = 0.90
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.add_theme_constant_override("separation", 12)
	_load_panel.add_child(container)

	var title = Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", StoryStyle.instance().get_menu_title_color())
	container.add_child(title)

	for i in range(SaveManager.MAX_SLOTS):
		var slot_info = SaveManager.get_slot_info(i)
		_add_slot_row(container, i, slot_info)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(110, 38)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_button_style(back_btn)
	back_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			_show_menu())
	container.add_child(back_btn)

	_load_panel.visible = true
	_active_panel = "load"


func _add_slot_row(parent: Container, slot: int, info: Dictionary) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.custom_minimum_size = Vector2(0, 44)
	parent.add_child(hbox)

	var slot_lbl = Label.new()
	slot_lbl.text = "Slot %d" % (slot + 1)
	slot_lbl.custom_minimum_size = Vector2(65, 0)
	slot_lbl.add_theme_font_size_override("font_size", 15)
	slot_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 1.0))
	hbox.add_child(slot_lbl)

	var info_lbl = Label.new()
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if info.get("empty", true):
		info_lbl.text = "(empty)"
		info_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.40, 1.0))
	else:
		info_lbl.text = "Scene: %s  |  %s" % [info.get("scene", "?"), info.get("timestamp", "")]
		info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 1.0))
	info_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(info_lbl)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(75, 30)
	load_btn.disabled = info.get("empty", true)
	_apply_slot_button_style(load_btn)
	if info.get("empty", true):
		load_btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
	load_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			if SaveManager.load_slot(slot):
				SaveManager.queue_load(slot)
				_fade_to_game())
	hbox.add_child(load_btn)

	var del_btn = Button.new()
	del_btn.text = "Del"
	del_btn.custom_minimum_size = Vector2(55, 30)
	del_btn.disabled = info.get("empty", true)
	_apply_slot_button_style(del_btn)
	if info.get("empty", true):
		del_btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
	del_btn.pressed.connect(func():
			SoundEvents.play("choice_click")
			SaveManager.delete_slot(slot)
			_load_panel.queue_free()
			_show_load_panel())
	hbox.add_child(del_btn)


func _apply_slot_button_style(btn: Button) -> void:
	var style = StoryStyle.instance()
	var normal = StyleBoxFlat.new()
	normal.bg_color = style.get_menu_button_bg()
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.22, 0.25, 0.35, 0.7)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover = StyleBoxFlat.new()
	hover.bg_color = style.get_menu_button_hover()
	hover.set_corner_radius_all(4)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.38, 0.42, 0.55, 0.8)
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", style.get_menu_button_text())
	btn.add_theme_font_size_override("font_size", 13)
