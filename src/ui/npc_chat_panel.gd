## NpcChatPanel — Full-screen IRC-style chat interface for NPC conversations.
##
## Layout:
##   Control (full screen, dark bg)
##   └── VBoxContainer (full screen)
##       ├── ScrollContainer + RichTextLabel (message history, expands)
##       └── HBoxContainer (bottom bar)
##           ├── Back button
##           ├── LineEdit (input)
##           └── Send button
##
## Usage:
##   var panel = NpcChatPanel.new()
##   panel.message_sent.connect(_on_message_sent)
##   panel.back_pressed.connect(_on_back_pressed)
##   add_child(panel)
##   panel.show_panel()
##   panel.append_message("Alice", "Hello there!")
##   panel.append_message("You", "Hi Alice!")

extends Control
class_name NpcChatPanel


# ── Signals ─────────────────────────────────────────────────────

## Emitted when the player sends a message.
signal message_sent(text: String)

## Emitted when the back button is pressed.
signal back_pressed()

## Emitted when the microphone button is pressed (toggle recording).
signal mic_pressed()


# ── Internal nodes ──────────────────────────────────────────────
var _bg: ColorRect
var _bg_texture: TextureRect  # story-specific background image
var _root_vbox: VBoxContainer
var _scroll_container: ScrollContainer
var _chat_rich_text: RichTextLabel
var _bottom_hbox: HBoxContainer
var _back_button: Button
var _input_line: LineEdit
var _send_button: Button
var _mic_button: TextureButton

# Mic button icon textures
var _mic_tex_idle: Texture2D = preload("res://assets/icons/mic.svg")
var _mic_tex_recording: Texture2D = preload("res://assets/icons/mic-recording.svg")
var _mic_tex_transcribing: Texture2D = preload("res://assets/icons/mic-transcribing.svg")

var _back_callback: Callable
var _typing_visible: bool = false
var _typing_speaker: String = ""
var _dot_phase: int = 0
var _typing_timer: Timer
var _messages: Array[String] = []  # stored bbcode for each message


# ── Public API ──────────────────────────────────────────────────

## Show the chat panel.
func show_panel() -> void:
	self.visible = true
	_scroll_container.scroll_vertical = 0


## Hide the chat panel.
func hide_panel() -> void:
	self.visible = false


## Build bbcode for a single chat message.
func _make_message_bbcode(speaker: String, text: String, is_player: bool) -> String:
	var color = VNTheme.get_player_color() if is_player else VNTheme.get_speaker_color()
	var color_hex = _color_to_html(color)
	var align = "right" if is_player else "left"
	var name_size = VNTheme.get_font_size_chat_name()
	var label = "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [name_size, color_hex, speaker] if not speaker.is_empty() else ""
	var bbcode = ""
	if not label.is_empty():
		bbcode += "[%s]%s[/%s]\n" % [align, label, align]
	bbcode += "[%s]%s[/%s]\n\n" % [align, text, align]
	return bbcode


## Rebuild the RichTextLabel from the stored messages (+ typing indicator if active).
func _rebuild_text() -> void:
	var full = ""
	for msg in _messages:
		full += msg
	if _typing_visible:
		full += _make_typing_bbcode()
	_chat_rich_text.text = full
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


## Build the animated typing indicator bbcode.
func _make_typing_bbcode() -> String:
	var color_hex = _color_to_html(VNTheme.get_loading_color())
	var name_size = VNTheme.get_font_size_chat_name()
	var label = "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [name_size, color_hex, _typing_speaker] if not _typing_speaker.is_empty() else ""
	var dots = ["•", "•  •", "•  •  •", "  •", "•  •", "•"]
	var dot_text = dots[_dot_phase % dots.size()]
	var bbcode = ""
	if not label.is_empty():
		bbcode += "[left]%s[/left]\n" % label
	bbcode += "[left]%s[/left]\n\n" % dot_text
	return bbcode


## Append a chat message. Use [code]is_player=true[/code] for player messages.
func append_message(speaker: String, text: String, is_player: bool = false) -> void:
	_typing_visible = false
	_messages.append(_make_message_bbcode(speaker, text, is_player))
	_rebuild_text()


## Append a system/narration message (grey, centered).
func append_system(text: String) -> void:
	_typing_visible = false
	var color_hex = _color_to_html(VNTheme.get_narration_color())
	var bbcode = "[indent][center][color=%s][i]%s[/i][/color][/center][/indent]\n\n" % [color_hex, text]
	_messages.append(bbcode)
	_rebuild_text()


## Show an animated three-dot typing indicator as a chat message.
func show_typing_indicator(speaker_name: String) -> void:
	_typing_speaker = speaker_name
	_typing_visible = true
	_dot_phase = 0
	if not is_instance_valid(_typing_timer):
		_typing_timer = Timer.new()
		_typing_timer.wait_time = 0.4
		_typing_timer.one_shot = false
		_typing_timer.timeout.connect(_on_typing_timer)
		add_child(_typing_timer)
	_typing_timer.start()
	_rebuild_text()


## Hide the typing indicator.
func hide_typing_indicator() -> void:
	_typing_visible = false
	if is_instance_valid(_typing_timer):
		_typing_timer.stop()
	_rebuild_text()


func _on_typing_timer() -> void:
	_dot_phase += 1
	if _typing_visible:
		_rebuild_text()


## Enable/disable the input controls.
func set_input_enabled(enabled: bool) -> void:
	_input_line.editable = enabled
	_send_button.disabled = not enabled
	if enabled:
		_input_line.grab_focus()


## Clear the input text field.
func clear_input() -> void:
	_input_line.clear()


## Clear all chat messages.
func clear_messages() -> void:
	_messages.clear()
	_typing_visible = false
	if is_instance_valid(_typing_timer):
		_typing_timer.stop()
	_rebuild_text()


## Set the microphone button visual state.
func set_mic_state(state: String) -> void:
	if not is_instance_valid(_mic_button):
		return
	match state:
		"recording":
			_mic_button.texture_normal = _mic_tex_recording
		"transcribing":
			_mic_button.texture_normal = _mic_tex_transcribing
		"idle":
			_mic_button.texture_normal = _mic_tex_idle


## Store a callable to be connected to the back button press.
func connect_back_button(callable: Callable) -> void:
	_back_callback = callable
	if is_instance_valid(_back_button):
		_back_button.pressed.connect(callable)


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	self.visible = false
	_build_background()
	_build_root()
	_build_message_area()
	_build_bottom_bar()
	if not _back_callback.is_null() and is_instance_valid(_back_button):
		_back_button.pressed.connect(_back_callback)


func _build_background() -> void:
	_bg = ColorRect.new()
	_bg.color = VNTheme.get_bg_color()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# ── Story-specific background texture ──
	_bg_texture = TextureRect.new()
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture.visible = false
	add_child(_bg_texture)

	var chat_bg = VNTheme.load_ui_bg_texture("npc_chat")
	if chat_bg:
		_bg_texture.texture = chat_bg
		_bg_texture.visible = true
		_bg.visible = false  # hide solid colour when image is present


func _build_root() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_vbox)


func _build_message_area() -> void:
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size = Vector2(0, 200)
	_root_vbox.add_child(_scroll_container)

	_chat_rich_text = RichTextLabel.new()
	_chat_rich_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_rich_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_rich_text.bbcode_enabled = true
	_chat_rich_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_rich_text.scroll_following = true

	# Default text color and font
	_chat_rich_text.add_theme_color_override("default_color", VNTheme.get_text_color())
	_chat_rich_text.add_theme_font_override("normal_font", VNTheme.get_font_dialogue())
	_chat_rich_text.add_theme_font_size_override("normal_font_size", VNTheme.get_font_size_dialogue())
	# Name font for speaker labels
	_chat_rich_text.add_theme_font_override("bold_font", VNTheme.get_font_name())
	_chat_rich_text.add_theme_font_size_override("bold_font_size", VNTheme.get_font_size_chat_name())

	# Margin around the message area
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(_chat_rich_text)

	_scroll_container.add_child(margin)


func _build_bottom_bar() -> void:
	# Margin around the bottom bar
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_top", 12)
	# Don't expand vertically — only take the space the bar needs.
	# SIZE_EXPAND_FILL would cover the whole screen and steal mouse events.
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_END
	_root_vbox.add_child(margin)

	_bottom_hbox = HBoxContainer.new()
	_bottom_hbox.add_theme_constant_override("separation", 8)
	_bottom_hbox.custom_minimum_size = Vector2(0, 50)
	margin.add_child(_bottom_hbox)

	# Back button
	_back_button = Button.new()
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(120, VNTheme.get_choice_button_min_height())
	_back_button.pressed.connect(func():
			SoundEvents.play("back_button")
			back_pressed.emit())
	VNTheme.style_choice_button(_back_button)
	_style_black_button(_back_button)
	_back_button.mouse_entered.connect(func(): SoundEvents.play("choice_hover"))
	_bottom_hbox.add_child(_back_button)

	# Input field
	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Type a message..."
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.text_submitted.connect(func(t): message_sent.emit(t))
	_input_line.add_theme_color_override("font_color", VNTheme.get_text_color())
	_input_line.add_theme_color_override("placeholder_font_color", VNTheme.get_loading_color())
	_input_line.add_theme_font_override("font", VNTheme.get_font_dialogue())
	_input_line.add_theme_font_size_override("font_size", VNTheme.get_font_size_input())
	var input_bg = StyleBoxFlat.new()
	input_bg.bg_color = VNTheme.get_input_bg()
	input_bg.set_corner_radius_all(6)
	input_bg.set_border_width_all(1)
	input_bg.border_color = VNTheme.get_input_border()
	_input_line.add_theme_stylebox_override("panel", input_bg)
	_bottom_hbox.add_child(_input_line)

	# Send button
	_send_button = Button.new()
	_send_button.focus_mode = Control.FOCUS_ALL
	_send_button.text = "Send"
	_send_button.custom_minimum_size = Vector2(120, VNTheme.get_choice_button_min_height())
	_send_button.pressed.connect(func(): message_sent.emit(_input_line.text))
	VNTheme.style_choice_button(_send_button)
	_style_black_button(_send_button)
	_send_button.mouse_entered.connect(func(): SoundEvents.play("choice_hover"))
	_bottom_hbox.add_child(_send_button)

	# Microphone button (voice input)
	_mic_button = TextureButton.new()
	_mic_button.focus_mode = Control.FOCUS_ALL
	_mic_button.texture_normal = _mic_tex_idle
	_mic_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_mic_button.custom_minimum_size = Vector2(60, VNTheme.get_choice_button_min_height())
	_mic_button.pressed.connect(func():
			SoundEvents.play("choice_click")
			mic_pressed.emit())
	VNTheme.style_choice_button(_mic_button)
	_style_black_button(_mic_button)
	_mic_button.mouse_entered.connect(func(): SoundEvents.play("choice_hover"))
	_bottom_hbox.add_child(_mic_button)


# ── Helpers ─────────────────────────────────────────────────────

## Override button stylebox colours: black normal, lighter on hover/focus.
func _style_black_button(btn) -> void:
	var cr = VNTheme.get_choice_button_corner_radius()
	var ph = VNTheme.get_choice_button_padding_horizontal()
	var pv = VNTheme.get_choice_button_padding_vertical()

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	normal.set_corner_radius_all(cr)
	normal.set_border_width_all(1)
	normal.border_color = VNTheme.get_dialogue_box_border()
	normal.content_margin_left = ph
	normal.content_margin_right = ph
	normal.content_margin_top = pv
	normal.content_margin_bottom = pv
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.20, 0.20, 1.0)
	hover.set_corner_radius_all(cr)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.20, 0.20, 0.20, 1.0)
	hover.content_margin_left = ph
	hover.content_margin_right = ph
	hover.content_margin_top = pv
	hover.content_margin_bottom = pv
	btn.add_theme_stylebox_override("hover", hover)

	var focus = StyleBoxFlat.new()
	focus.bg_color = Color(0.28, 0.28, 0.28, 1.0)
	focus.set_corner_radius_all(cr)
	focus.set_border_width_all(1)
	focus.border_color = Color(0.20, 0.20, 0.20, 1.0)
	focus.content_margin_left = ph
	focus.content_margin_right = ph
	focus.content_margin_top = pv
	focus.content_margin_bottom = pv
	btn.add_theme_stylebox_override("focus", focus)

func _color_to_html(color: Color) -> String:
	return "#%02X%02X%02X" % [
		int(color.r * 255),
		int(color.g * 255),
		int(color.b * 255)
	]
