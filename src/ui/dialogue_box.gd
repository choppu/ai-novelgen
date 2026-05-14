## DialogueBox — Visual Novel dialogue panel (bottom of screen).
##
## Handles:
##   • NPC name display with player/NPC colour distinction
##   • Typewriter text animation with instant-skip on click
##   • Continue indicator (ContinueIndicator sub-component)
##
## Usage:
##   var box = DialogueBox.new()
##   add_child(box)
##   box.text_finished.connect(_on_text_finished)
##   box.set_speaker("Alice")
##   box.start_typing("Hello there!")

extends Control
class_name DialogueBox


## Preload UI sub-components
const _ContinueIndicatorScript := preload("res://src/ui/continue_indicator.gd")


# ── Signals ─────────────────────────────────────────────────────

## Emitted when typewriter finishes (or is skipped to the end).
signal text_finished()

## Emitted when the player clicks or presses Space/Enter to advance.
signal advance_requested()


# ── Internal nodes ──────────────────────────────────────────────
var _panel: PanelContainer
var _margin: MarginContainer
var _name_label: Label
var _text_label: Label
var _continue_indicator: ContinueIndicator

var _typewriter_timer: Timer

var _typewriter_text: String = ""
var _typewriter_char_index: int = 0
var _is_typing: bool = false


# ── Public API ──────────────────────────────────────────────────

## Show or hide the entire dialogue box.
func show_box() -> void:
	self.visible = true

func hide_box() -> void:
	self.visible = false
	_name_label.text = ""
	_text_label.text = ""
	_continue_indicator.stop_blinking()
	_typewriter_timer.stop()


## Set the speaker name. Use [code]is_player=true[/code] for player-colour text.
func set_speaker(speaker_name: String, is_player: bool = false) -> void:
	if speaker_name.is_empty():
		_name_label.text = ""
	else:
		_name_label.text = speaker_name
		_name_label.add_theme_color_override("font_color",
			VNTheme.get_player_color() if is_player else VNTheme.get_speaker_color())


## Start typewriter animation for [code]full_text[/code].
## Use [code]is_narration=true[/code] for narration-style (greyer) text.
func start_typing(full_text: String, is_narration: bool = false) -> void:
	_is_typing = true
	_typewriter_text = full_text
	_typewriter_char_index = 0
	_text_label.text = ""

	_text_label.add_theme_color_override("font_color",
		VNTheme.get_narration_color() if is_narration else VNTheme.get_text_color())

	_continue_indicator.stop_blinking()
	_typewriter_timer.start()


## Instantly finish the typewriter and show full text.
func finish_typing() -> void:
	_typewriter_timer.stop()
	_text_label.text = _typewriter_text
	_is_typing = false

	_continue_indicator.start_blinking()
	text_finished.emit()


## Check if the typewriter is currently animating.
func is_typing() -> bool:
	return _is_typing


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_dialogue_panel()
	_build_timers()


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
	_name_label.add_theme_color_override("font_color", VNTheme.get_speaker_color())
	_name_label.add_theme_font_size_override("font_size", VNTheme.get_font_size_name())
	_name_label.add_theme_font_override("font", VNTheme.get_font_name())
	_name_label.custom_minimum_size = Vector2(0, 32)
	inner_vbox.add_child(_name_label)

	# Text + continue indicator row
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(hbox)

	# Text wrapper with right margin so text never touches the continue indicator
	var text_margin = MarginContainer.new()
	text_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_margin.add_theme_constant_override("margin_right", 12)
	hbox.add_child(text_margin)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("font_color", VNTheme.get_text_color())
	_text_label.add_theme_font_override("font", VNTheme.get_font_dialogue())
	_text_label.add_theme_font_size_override("font_size", VNTheme.get_font_size_dialogue())
	text_margin.add_child(_text_label)

	_continue_indicator = _ContinueIndicatorScript.new()
	hbox.add_child(_continue_indicator)


func _build_timers() -> void:
	_typewriter_timer = Timer.new()
	_typewriter_timer.wait_time = VNTheme.get_typewriter_speed()
	_typewriter_timer.one_shot = false
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)


# ── Timer callbacks ─────────────────────────────────────────────

func _on_typewriter_tick() -> void:
	if _typewriter_char_index < _typewriter_text.length():
		_typewriter_char_index += 1
		_text_label.text = _typewriter_text.substr(0, _typewriter_char_index)
	else:
		finish_typing()


# ── Input ───────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _is_advance_event(event):
		if _is_typing:
			finish_typing()
		else:
			advance_requested.emit()


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			return true
	return false
