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


# ── Internal nodes ──────────────────────────────────────────────
var _bg: ColorRect
var _root_vbox: VBoxContainer
var _scroll_container: ScrollContainer
var _chat_rich_text: RichTextLabel
var _bottom_hbox: HBoxContainer
var _back_button: Button
var _input_line: LineEdit
var _send_button: Button

var _back_callback: Callable


# ── Public API ──────────────────────────────────────────────────

## Show the chat panel.
func show_panel() -> void:
	self.visible = true
	_scroll_container.scroll_vertical = 0


## Hide the chat panel.
func hide_panel() -> void:
	self.visible = false


## Append a chat message. Use [code]is_player=true[/code] for player messages.
func append_message(speaker: String, text: String, is_player: bool = false) -> void:
	var color = VNTheme.get_player_color() if is_player else VNTheme.get_speaker_color()
	var color_hex = _color_to_html(color)

	var align = "right" if is_player else "left"
	var label = "[b][color=%s]%s[/color][/b]" % [color_hex, speaker] if not speaker.is_empty() else ""

	var bbcode = ""
	if not label.is_empty():
		bbcode += "[%s]%s[/%s]\n" % [align, label, align]
	bbcode += "[%s]%s[/%s]\n\n" % [align, text, align]

	_chat_rich_text.append_text(bbcode)
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


## Append a system/narration message (grey, centered).
func append_system(text: String) -> void:
	var color_hex = _color_to_html(VNTheme.get_narration_color())
	var bbcode = "[indent][center][color=%s][i]%s[/i][/color][/center][/indent]\n\n" % [color_hex, text]
	_chat_rich_text.append_text(bbcode)
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


## Show a typing indicator (animated dots).
func show_typing_indicator(speaker_name: String) -> void:
	var color_hex = _color_to_html(VNTheme.get_loading_color())
	var bbcode = "[indent][left][b][color=%s]%s[/color][/b] [i]...[/i][/left][/indent]\n" % [color_hex, speaker_name]
	_chat_rich_text.append_text(bbcode)
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


## Remove the last appended text (e.g., to remove typing indicator).
func remove_last_append() -> void:
	_chat_rich_text.remove_paragraph(_chat_rich_text.get_paragraph_count() - 1)


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
	_chat_rich_text.clear()


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
	_chat_rich_text.add_theme_font_override("font", VNTheme.get_font_dialogue())
	_chat_rich_text.add_theme_font_size_override("normal_font_size", VNTheme.get_font_size_dialogue())

	# Margin inside the rich text
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
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
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(90, 0)
	_back_button.pressed.connect(func():
			SoundEvents.play("back_button")
			back_pressed.emit())
	VNTheme.style_choice_button(_back_button)
	_bottom_hbox.add_child(_back_button)

	# Input field
	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Type a message..."
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.text_submitted.connect(func(t): message_sent.emit(t))
	_input_line.add_theme_color_override("font_color", VNTheme.get_text_color())
	_input_line.add_theme_color_override("placeholder_font_color", VNTheme.get_loading_color())
	_input_line.add_theme_font_override("font", VNTheme.get_font_dialogue())
	var input_bg = StyleBoxFlat.new()
	input_bg.bg_color = VNTheme.get_input_bg()
	input_bg.set_corner_radius_all(6)
	input_bg.set_border_width_all(1)
	input_bg.border_color = VNTheme.get_input_border()
	_input_line.add_theme_stylebox_override("panel", input_bg)
	_bottom_hbox.add_child(_input_line)

	# Send button
	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.custom_minimum_size = Vector2(90, 0)
	_send_button.pressed.connect(func(): message_sent.emit(_input_line.text))
	VNTheme.style_choice_button(_send_button)
	_bottom_hbox.add_child(_send_button)


# ── Helpers ─────────────────────────────────────────────────────

func _color_to_html(color: Color) -> String:
	return "#%02X%02X%02X" % [
		int(color.r * 255),
		int(color.g * 255),
		int(color.b * 255)
	]
