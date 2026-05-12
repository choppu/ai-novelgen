## DialogueBox — Visual Novel dialogue panel (bottom of screen).
##
## Handles:
##   • NPC name display with player/NPC colour distinction
##   • Typewriter text animation with instant-skip on click
##   • Blinking "▼" continue indicator
##   • Optional LLM input bar (back button + LineEdit + send button)
##
## Usage:
##   var box = DialogueBox.new()
##   box.connect_back_button(_exit_dialogue)
##   add_child(box)
##   box.text_finished.connect(_on_text_finished)
##   box.input_submitted.connect(_on_input_submitted)
##   box.set_speaker("Alice")
##   box.start_typing("Hello there!")
##   # ... later ...
##   box.set_input_mode(true)  # show LLM input bar

extends Control
class_name DialogueBox


# ── Signals ─────────────────────────────────────────────────────

## Emitted when typewriter finishes (or is skipped to the end).
signal text_finished()

## Emitted when the player submits text via the input bar.
signal input_submitted(text: String)


# ── Internal nodes ──────────────────────────────────────────────
var _panel: PanelContainer
var _margin: MarginContainer
var _name_label: Label
var _text_label: Label
var _continue_indicator: Label

var _input_hbox: HBoxContainer
var _back_button: Button
var _input_line: LineEdit
var _send_button: Button

var _typewriter_timer: Timer
var _blink_timer: Timer

var _typewriter_text: String = ""
var _typewriter_char_index: int = 0
var _is_typing: bool = false
var _back_callback: Callable


# ── Public API ──────────────────────────────────────────────────

## Show or hide the entire dialogue box.
func show_box() -> void:
	self.visible = true

func hide_box() -> void:
	self.visible = false
	_name_label.text = ""
	_text_label.text = ""
	_stop_blinking()
	_typewriter_timer.stop()


## Set the speaker name. Use [code]is_player=true[/code] for player-colour text.
func set_speaker(speaker_name: String, is_player: bool = false) -> void:
	if speaker_name.is_empty():
		_name_label.text = ""
	else:
		_name_label.text = speaker_name
		_name_label.add_theme_color_override("font_color",
			VNTheme.PLAYER_COLOR if is_player else VNTheme.SPEAKER_COLOR)


## Start typewriter animation for [code]full_text[/code].
## Use [code]is_narration=true[/code] for narration-style (greyer) text.
func start_typing(full_text: String, is_narration: bool = false) -> void:
	_is_typing = true
	_typewriter_text = full_text
	_typewriter_char_index = 0
	_text_label.text = ""

	_text_label.add_theme_color_override("font_color",
		VNTheme.NARRATION_COLOR if is_narration else VNTheme.TEXT_COLOR)

	_continue_indicator.visible = false
	_stop_blinking()
	_typewriter_timer.start()


## Instantly finish the typewriter and show full text.
func finish_typing() -> void:
	_typewriter_timer.stop()
	_text_label.text = _typewriter_text
	_is_typing = false

	_continue_indicator.visible = true
	_blink_timer.start()
	text_finished.emit()


## Check if the typewriter is currently animating.
func is_typing() -> bool:
	return _is_typing


## Show or hide the LLM input bar (back + text + send).
func set_input_mode(enabled: bool) -> void:
	_input_hbox.visible = enabled
	_back_button.visible = enabled
	if enabled:
		_input_line.grab_focus()


## Enable/disable the input controls.
func set_input_enabled(enabled: bool) -> void:
	_input_line.editable = enabled
	_send_button.disabled = not enabled
	if enabled and _input_hbox.visible:
		_input_line.grab_focus()


## Clear the input text field.
func clear_input() -> void:
	_input_line.clear()


## Get the current input text.
func get_input_text() -> String:
	return _input_line.text


## Store a callable to be connected to the back button press.
## Safe to call before the node is added to the scene tree.
func connect_back_button(callable: Callable) -> void:
	_back_callback = callable
	if is_instance_valid(_back_button):
		_back_button.pressed.connect(callable)


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_dialogue_panel()
	_build_input_bar()
	_build_timers()
	if not _back_callback.is_null() and is_instance_valid(_back_button):
		_back_button.pressed.connect(_back_callback)


func _build_dialogue_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.anchor_top = 1.0
	_panel.offset_top = -220
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.add_theme_stylebox_override("panel", VNTheme.create_dialogue_box_style())
	add_child(_panel)

	_margin = MarginContainer.new()
	_margin.add_theme_constant_override("margin_top", 12)
	_margin.add_theme_constant_override("margin_bottom", 16)
	_margin.add_theme_constant_override("margin_left", 24)
	_margin.add_theme_constant_override("margin_right", 24)
	_panel.add_child(_margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 6)
	_margin.add_child(inner_vbox)

	# Name label
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.add_theme_color_override("font_color", VNTheme.SPEAKER_COLOR)
	_name_label.add_theme_font_size_override("font_size", VNTheme.FONT_SIZE_NAME)
	_name_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_name_label.custom_minimum_size = Vector2(0, 32)
	inner_vbox.add_child(_name_label)

	# Text + continue indicator row
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(hbox)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("font_color", VNTheme.TEXT_COLOR)
	_text_label.add_theme_font_size_override("font_size", VNTheme.FONT_SIZE_DIALOGUE)
	hbox.add_child(_text_label)

	_continue_indicator = Label.new()
	_continue_indicator.text = "▼"
	_continue_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_indicator.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_continue_indicator.add_theme_color_override("font_color", VNTheme.TEXT_COLOR)
	_continue_indicator.add_theme_font_size_override("font_size", VNTheme.FONT_SIZE_CONTINUE)
	_continue_indicator.custom_minimum_size = Vector2(30, 30)
	_continue_indicator.visible = false
	hbox.add_child(_continue_indicator)


func _build_input_bar() -> void:
	_input_hbox = HBoxContainer.new()
	_input_hbox.add_theme_constant_override("separation", 8)
	_input_hbox.custom_minimum_size = Vector2(0, 44)
	_input_hbox.visible = false
	_margin.add_child(_input_hbox)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "What do you want to say?"
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.text_submitted.connect(func(t): input_submitted.emit(t))
	_input_line.add_theme_color_override("font_color", VNTheme.TEXT_COLOR)
	_input_line.add_theme_color_override("placeholder_font_color", VNTheme.LOADING_COLOR)
	var input_bg = StyleBoxFlat.new()
	input_bg.bg_color = VNTheme.INPUT_BG_COLOR
	input_bg.set_corner_radius_all(6)
	input_bg.set_border_width_all(1)
	input_bg.border_color = VNTheme.INPUT_BORDER_COLOR
	_input_line.add_theme_stylebox_override("panel", input_bg)
	_input_hbox.add_child(_input_line)

	_back_button = Button.new()
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(80, 0)
	VNTheme.style_choice_button(_back_button)
	_input_hbox.add_child(_back_button)

	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.custom_minimum_size = Vector2(80, 0)
	_send_button.pressed.connect(func(): input_submitted.emit(_input_line.text))
	VNTheme.style_choice_button(_send_button)
	_input_hbox.add_child(_send_button)


func _build_timers() -> void:
	_typewriter_timer = Timer.new()
	_typewriter_timer.wait_time = VNTheme.TYPEWRITER_SPEED
	_typewriter_timer.one_shot = false
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)

	_blink_timer = Timer.new()
	_blink_timer.wait_time = VNTheme.BLINK_INTERVAL
	_blink_timer.one_shot = false
	_blink_timer.timeout.connect(_on_blink_tick)
	add_child(_blink_timer)


# ── Timer callbacks ─────────────────────────────────────────────

func _on_typewriter_tick() -> void:
	if _typewriter_char_index < _typewriter_text.length():
		_typewriter_char_index += 1
		_text_label.text = _typewriter_text.substr(0, _typewriter_char_index)
	else:
		finish_typing()


func _on_blink_tick() -> void:
	_continue_indicator.visible = not _continue_indicator.visible


func _stop_blinking() -> void:
	_blink_timer.stop()
	_continue_indicator.visible = false
