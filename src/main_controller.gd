## MainController — Builds the UI and connects it to the SceneManager and LLM pipeline.
##
## Attached to the root Control node in main.tscn.
## All UI is created programmatically.
extends Control


## ── UI Nodes (created in _ready) ──────────────────────────────
var _description_label: Label
var _dialogue_container: VBoxContainer
var _dialogue_scroll: ScrollContainer
var _choices_container: VBoxContainer
var _root_box: VBoxContainer

## ── LLM UI ────────────────────────────────────────────────────
var _input_line: LineEdit
var _send_button: Button
var _loading_label: Label
var _error_banner: Label
var _npc_name_label: Label

## ── Engine ────────────────────────────────────────────────────
var _scene_manager
var _http_client: Node
var _server: Node
var _dialogue_generator: Node
var _response_validator: Node
var _memory_manager: Node

## ── Clue System ───────────────────────────────────────────────
var _clue_tracker
var _clue_evaluator

## ── Game Mode ─────────────────────────────────────────────────
## "explore" = showing scene choices, input hidden
## "dialogue" = chatting with NPC, input visible, only "End dialogue" choice
var _mode: String = "explore"

## NPC currently being talked to (set when entering dialogue mode, cleared on exit)
var _dialogue_npc: String = ""
## Accumulated emotional mood for the current dialogue NPC (triggers relationship changes).
var _npc_emotional_mood: int = 0

## Preload scripts
const _SceneManagerScript := preload("res://src/scene_manager.gd")
const _ServerLifecycleScript := preload("res://src/server_lifecycle.gd")
const _LlmHttpClientScript := preload("res://src/llm_http_client.gd")
const _DialogueGeneratorScript := preload("res://src/dialogue_generator.gd")
const _ResponseValidatorScript := preload("res://src/response_validator.gd")
const _ClueTrackerScript := preload("res://src/clue_tracker.gd")
const _CluePrerequisiteEvaluatorScript := preload("res://src/clue_prerequisite_evaluator.gd")
const _EmotionalStatesScript = preload("res://src/emotional_states.gd")
const _NPCMemoryScript = preload("res://src/npc_memory.gd")


## ── Colours / styling ─────────────────────────────────────────
var _bg_color := Color(0.08, 0.08, 0.10, 1.0)
var _text_color := Color(0.90, 0.90, 0.88, 1.0)
var _accent_color := Color(0.898, 0.923, 0.97, 1.0)
var _speaker_color := Color(0.936, 0.967, 1.0, 1.0)
var _narration_color := Color(0.70, 0.70, 0.68, 1.0)
var _button_color := Color(0.18, 0.25, 0.40, 1.0)
var _button_hover_color := Color(0.28, 0.38, 0.58, 1.0)
var _button_focus_color := Color(0.35, 0.48, 0.70, 1.0)
var _input_bg_color := Color(0.12, 0.12, 0.15, 1.0)
var _error_bg_color := Color(0.50, 0.15, 0.15, 0.9)
var _loading_color := Color(0.50, 0.50, 0.55, 1.0)


# ── Lifecycle ──────────────────────────────────────────────────

func _ready() -> void:
	_create_ui()
	_setup_scene_manager()
	_setup_clue_system()
	_setup_llm_pipeline()
	_load_story()
	# ScrollContainer sizes scrollable area from child's custom_minimum_size,
	# not from size flags. Set the VBox width after layout settles.
	call_deferred("_fix_dialogue_width")
	resized.connect(_fix_dialogue_width)

func _exit_tree() -> void:
	if _server != null:
		_server.stop()


## Set dialogue container width to fill the ScrollContainer.
func _fix_dialogue_width() -> void:
	# Account for scrollbar (~14px) and margin container padding (~8px each side)
	var available = _dialogue_scroll.get_rect().size.x
	_dialogue_container.custom_minimum_size.x = available


func _create_ui() -> void:
	# Root vertical layout
	_root_box = VBoxContainer.new()
	_root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_box.add_theme_constant_override("separation", 12)
	add_child(_root_box)

	# ── NPC name / portrait area ──
	_npc_name_label = Label.new()
	_npc_name_label.text = ""
	_npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_npc_name_label.add_theme_color_override("font_color", _speaker_color)
	_npc_name_label.add_theme_font_size_override("font_size", 24)
	_npc_name_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_npc_name_label.custom_minimum_size = Vector2(0, 30)
	_root_box.add_child(_npc_name_label)

	# ── Description area ──
	_description_label = Label.new()
	_description_label.text = ""
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.add_theme_color_override("font_color", _accent_color)
	_description_label.add_theme_font_size_override("font_size", 20)
	_description_label.custom_minimum_size = Vector2(0, 60)
	_root_box.add_child(_description_label)

	# ── Dialogue area (scrollable) ──
	_dialogue_scroll = ScrollContainer.new()
	_dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_scroll.custom_minimum_size = Vector2(0, 100)
	_root_box.add_child(_dialogue_scroll)

	_dialogue_container = VBoxContainer.new()
	_dialogue_container.add_theme_constant_override("separation", 8)
	_dialogue_scroll.add_child(_dialogue_container)

	# ── Loading indicator ──
	_loading_label = Label.new()
	_loading_label.text = ""
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_color_override("font_color", _loading_color)
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.visible = false
	_loading_label.custom_minimum_size = Vector2(0, 24)
	_root_box.add_child(_loading_label)

	# ── Error banner ──
	_error_banner = Label.new()
	_error_banner.text = ""
	_error_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_banner.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8, 1.0))
	_error_banner.add_theme_font_size_override("font_size", 17)
	_error_banner.visible = false
	_error_banner.custom_minimum_size = Vector2(0, 28)
	var err_bg = StyleBoxFlat.new()
	err_bg.bg_color = _error_bg_color
	err_bg.corner_radius_top_left = 4
	err_bg.corner_radius_top_right = 4
	err_bg.corner_radius_bottom_left = 4
	err_bg.corner_radius_bottom_right = 4
	_error_banner.add_theme_stylebox_override("normal", err_bg)
	_root_box.add_child(_error_banner)

	# ── Choices area ──
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 6)
	_choices_container.custom_minimum_size = Vector2(0, 40)
	_root_box.add_child(_choices_container)

	# ── Input area ──
	var input_hbox = HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 8)
	input_hbox.custom_minimum_size = Vector2(0, 44)
	_root_box.add_child(input_hbox)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "What do you want to say?"
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.text_submitted.connect(_on_input_submitted)
	_input_line.add_theme_color_override("font_color", _text_color)
	_input_line.add_theme_color_override("placeholder_font_color", _loading_color)
	var input_bg = StyleBoxFlat.new()
	input_bg.bg_color = _input_bg_color
	input_bg.corner_radius_top_left = 6
	input_bg.corner_radius_top_right = 6
	input_bg.corner_radius_bottom_left = 6
	input_bg.corner_radius_bottom_right = 6
	input_bg.set_border_width_all(1)
	input_bg.border_color = Color(0.25, 0.30, 0.40, 1.0)
	_input_line.add_theme_stylebox_override("panel", input_bg)
	input_hbox.add_child(_input_line)

	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.custom_minimum_size = Vector2(80, 0)
	_send_button.pressed.connect(_on_send_pressed)
	_style_button(_send_button)
	input_hbox.add_child(_send_button)

	# ── Background colour via StyleBox ──
	var bg = StyleBoxFlat.new()
	bg.bg_color = _bg_color
	add_theme_stylebox_override("panel", bg)


func _style_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = _button_color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4

	var hover = StyleBoxFlat.new()
	hover.bg_color = _button_hover_color
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4

	var focus = StyleBoxFlat.new()
	focus.bg_color = _button_focus_color
	focus.corner_radius_top_left = 4
	focus.corner_radius_top_right = 4
	focus.corner_radius_bottom_left = 4
	focus.corner_radius_bottom_right = 4

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", _text_color)


# ── SceneManager setup ─────────────────────────────────────────

func _setup_scene_manager() -> void:
	_scene_manager = _SceneManagerScript.new()
	_scene_manager.scene_changed.connect(_on_scene_changed)
	_scene_manager.story_loaded.connect(_on_story_loaded)


func _load_story() -> void:
	var story_path = GameConfig.get_story_path()
	_scene_manager.load_story(story_path)


# ── Clue system setup ──────────────────────────────────────────

func _setup_clue_system() -> void:
	_clue_tracker = _ClueTrackerScript.new()
	_clue_evaluator = _CluePrerequisiteEvaluatorScript.new(_clue_tracker)


## Reload clue definitions from the scene manager after story load.
func _reload_clue_definitions() -> void:
	var clues = _scene_manager.get_clues()
	_clue_evaluator.load_clues(clues)
	# Sync clue tracker from GameState (in case of save/load)
	_clue_tracker.sync_from_game_state()


# ── LLM pipeline setup ─────────────────────────────────────────

func _setup_llm_pipeline() -> void:
	if LlmConfig.get_manage_server_lifecycle():
		_server = _ServerLifecycleScript.new()
		add_child(_server)
		_server.start()

	_http_client = _LlmHttpClientScript.new()
	add_child(_http_client)

	_dialogue_generator = _DialogueGeneratorScript.new()
	add_child(_dialogue_generator)
	_dialogue_generator.set_http_client(_http_client)
	_dialogue_generator.dialogue_generated.connect(_on_dialogue_generated)
	_dialogue_generator.generation_error.connect(_on_generation_error)

	_response_validator = _ResponseValidatorScript.new()
	add_child(_response_validator)

	# Memory manager — shares the HTTP client for summarization
	_memory_manager = _NPCMemoryScript.new()
	add_child(_memory_manager)
	_memory_manager.set_http_client(_http_client)

	# Wire memory manager into dialogue generator
	_dialogue_generator.set_memory_manager(_memory_manager)


# ── Signal handlers ────────────────────────────────────────────

func _on_story_loaded(success: bool, error_message: String) -> void:
	if success:
		# Load clue definitions now that story data is available
		_reload_clue_definitions()
		# Don't overwrite description — _on_scene_changed -> _display_scene
		# already set it (scene_changed fires before story_loaded).
		# Just ensure input is enabled and focused.
		_set_input_enabled(true)
		_input_line.grab_focus()
	else:
		_description_label.text = "Error: %s" % error_message
		push_error(error_message)


func _on_scene_changed(_scene_id: String, scene_data: Dictionary) -> void:
	var exited_dialogue = false
	if _mode == "dialogue":
		_exit_dialogue_mode()
		exited_dialogue = true

	# Clear conversation history on scene change
	if _dialogue_generator:
		_dialogue_generator.get_conversation_history().clear()

	if not exited_dialogue:
		_npc_name_label.text = ""
		_display_scene(scene_data)



func _on_dialogue_generated(response: Variant) -> void:
	_show_loading(false)
	_set_input_enabled(true)

	# Use the NPC we're currently talking to
	var target_npc = _dialogue_npc

	var available_clues = []
	if not target_npc.is_empty():
		var character_card = {}
		character_card = _scene_manager.get_character(target_npc)
		available_clues = _clue_evaluator.get_available_clues(target_npc, GameState.current_scene, character_card.get("can_reveal", []))

	# Validate response (only checks LLM's claimed clues against available set)
	var validated = _response_validator.validate(response, available_clues)

	print("Validated response: %s" % validated.describe())

	# Record accepted clue revelations
	for clue_id in validated.accepted_clues:
		var tier = validated.accepted_clue_tiers.get(clue_id, 1)
		_clue_tracker.reveal_clue(clue_id, tier, GameState.current_scene)
		GameState.record_clue(clue_id, tier)
		print("Clue recorded: %s at tier %d" % [clue_id, tier])

		# Apply set_flags from the clue's tier definition (optional)
		var clue_def = _clue_evaluator.get_clue_definition(clue_id)
		var tiers = clue_def.get("tiers", [])
		if tiers is Array:
			for tier_def in tiers:
				if tier_def.get("tier", 0) == tier:
					var set_flags = tier_def.get("set_flags", {})
					if set_flags is Dictionary and set_flags.size() > 0:
						GameState.apply_flags(set_flags)
						print("Clue '%s' tier %d set flags: %s" % [clue_id, tier, set_flags.keys()])
					break

	# Process emotional state for relationship changes
	var emotion = validated.emotional_state
	if not target_npc.is_empty() and not emotion.is_empty():
		_npc_emotional_mood += _EmotionalStatesScript.get_value(emotion)
		if _npc_emotional_mood >= _EmotionalStatesScript.RELATIONSHIP_THRESHOLD:
			GameState.modify_relationship(target_npc, 1)
			_npc_emotional_mood = 0
			print("Relationship with %s increased to %d" % [target_npc, GameState.get_relationship(target_npc)])
		elif _npc_emotional_mood <= -_EmotionalStatesScript.RELATIONSHIP_THRESHOLD:
			GameState.modify_relationship(target_npc, -1)
			_npc_emotional_mood = 0
			print("Relationship with %s decreased to %d" % [target_npc, GameState.get_relationship(target_npc)])

	# Display NPC dialogue
	_add_npc_dialogue(validated.dialogue, _npc_name_label.text if not _npc_name_label.text.is_empty() else "NPC")

func _on_generation_error(error_msg: String) -> void:
	_show_loading(false)
	_set_input_enabled(true)
	_show_error("Generation error: %s" % error_msg)


# ── Player input handling ──────────────────────────────────────

func _on_input_submitted(text: String) -> void:
	if text.is_empty():
		return
	_process_player_input(text)


func _on_send_pressed() -> void:
	var text = _input_line.text
	if text.is_empty():
		return
	_process_player_input(text)


func _process_player_input(text: String) -> void:
	# Display player input
	_add_player_dialogue(text)
	_input_line.clear()

	# Disable input during processing
	_set_input_enabled(false)
	_show_loading(true, "Thinking…")

	# Get scene context
	var scene_data = _scene_manager.get_current_scene()
	var scene_context = scene_data.get("description", "")

	# Use the NPC we're currently talking to
	var target_npc = _dialogue_npc
	var character_card = {}
	if not target_npc.is_empty():
		character_card = _scene_manager.get_character(target_npc)

	# Compute available clues for this NPC in the current scene
	var available_clues = []
	if not target_npc.is_empty():
		available_clues = _clue_evaluator.get_available_clues(target_npc, GameState.current_scene, character_card.get("can_reveal", []))

	# Send player input directly to the dialogue generator (no intent parsing)
	_dialogue_generator.generate(
		text,
		character_card.get("name", target_npc),
		character_card.get("appearance", ""),
		character_card.get("background", ""),
		character_card.get("temperament", ""),
		character_card.get("mood", ""),
		scene_context,
		available_clues,
		target_npc
	)


# ── UI Update ──────────────────────────────────────────────────

func _display_scene(scene_data: Dictionary) -> void:
	# Clear previous dialogue content.
	var dialogue_children = _dialogue_container.get_children()
	for child in dialogue_children:
		child.queue_free()
	var choice_children = _choices_container.get_children()
	for child in choice_children:
		child.queue_free()

	# ── Description ──
	var desc = scene_data.get("description", "")
	_description_label.text = desc if desc else GameState.current_scene

	# ── Dialogue ──
	var dialogue = scene_data.get("dialogue", [])
	for line in dialogue:
		if line is Dictionary:
			var speaker = line.get("speaker", "")
			var text = line.get("text", "")
			_add_dialogue_line(speaker, text)

	# ── Mode-dependent UI ──
	if _mode == "dialogue":
		_display_dialogue_mode()
	else:
		_display_explore_mode()


## Show exploration UI: choices visible, input hidden.
func _display_explore_mode() -> void:
	_input_line.visible = false
	_send_button.visible = false

	# Synthesize "Talk to [NPC]" choices for every character in the scene
	var scene_data = _scene_manager.get_current_scene()
	var characters = scene_data.get("characters", [])
	if characters is Array:
		for npc_name in characters:
			var talk_choice = {
				"id": "__talk_to__",
				"label": "Talk to %s" % npc_name,
				"npc_name": npc_name
			}
			_add_choice_button(talk_choice)

	# Show story-defined choices
	var choices = _scene_manager.get_available_choices()
	if choices.size() == 0 and characters.is_empty():
		_add_end_message()
	else:
		for choice in choices:
			if choice is Dictionary:
				_add_choice_button(choice)


## Show dialogue UI: input visible, only "End dialogue" button.
func _display_dialogue_mode() -> void:
	_input_line.visible = true
	_send_button.visible = true

	# "End dialogue" button
	var end_btn = Button.new()
	end_btn.text = "End dialogue"
	end_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_btn.custom_minimum_size = Vector2(0, 36)
	_style_button(end_btn)
	end_btn.pressed.connect(_exit_dialogue_mode)
	_choices_container.add_child(end_btn)

	_input_line.grab_focus()


## Enter dialogue mode with a specific NPC.
func _enter_dialogue_mode(npc_name: String) -> void:
	_mode = "dialogue"
	_npc_emotional_mood = 0
	_dialogue_npc = npc_name

	# Show NPC name
	_npc_name_label.text = npc_name

	# Add NPC's opening lines from scene dialogue to conversation history
	# (so the NPC is aware of what they just said in the scene setup)
	var current_scene = _scene_manager.get_current_scene()
	var history = _dialogue_generator.get_conversation_history()
	var scene_dialogue = current_scene.get("dialogue", [])
	for line in scene_dialogue:
		if line is Dictionary and line.get("speaker", "") == npc_name:
			var text = line.get("text", "")
			if not text.is_empty():
				history.add_llm_reply(text)

	# Redisplay scene in dialogue mode (clears choices, shows input)
	_display_scene(_scene_manager.get_current_scene())


## Exit dialogue mode, return to exploration.
func _exit_dialogue_mode() -> void:
	# Capture NPC name before clearing (needed for summarization)
	var exiting_npc = _dialogue_npc

	_mode = "explore"
	_npc_emotional_mood = 0
	_dialogue_npc = ""
	_npc_name_label.text = ""

	# Trigger summarization of the conversation for this NPC
	if not exiting_npc.is_empty():
		var history = _dialogue_generator.get_conversation_history().get_messages()
		if not history.is_empty():
			var character = _scene_manager.get_character(exiting_npc)
			var background = character.get("background", "")
			_memory_manager.summarize(exiting_npc, history, background)

	_display_scene(_scene_manager.get_current_scene())


func _add_dialogue_line(speaker: String, text: String) -> void:
	if speaker.is_empty():
		# Narration — use a simple Label
		var label = Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_FILL
		label.add_theme_color_override("font_color", _narration_color)
		label.add_theme_font_size_override("font_size", 19)
		_dialogue_container.add_child(label)
	else:
		# Character dialogue — speaker name + text in a single HBox
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_FILL
		_dialogue_container.add_child(hbox)

		var name_label = Label.new()
		name_label.text = speaker + ":"
		name_label.add_theme_color_override("font_color", _speaker_color)
		name_label.add_theme_font_size_override("font_size", 19)
		hbox.add_child(name_label)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(6, 0)
		hbox.add_child(spacer)

		var text_label = Label.new()
		text_label.text = text
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.add_theme_color_override("font_color", _text_color)
		text_label.add_theme_font_size_override("font_size", 19)
		hbox.add_child(text_label)


func _add_npc_dialogue(text: String, npc_name: String) -> void:
	# Simple label — no typewriter for now
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_FILL
	_dialogue_container.add_child(hbox)

	var name_label = Label.new()
	name_label.text = npc_name + ":"
	name_label.add_theme_color_override("font_color", _speaker_color)
	name_label.add_theme_font_size_override("font_size", 19)
	hbox.add_child(name_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	hbox.add_child(spacer)

	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_color_override("font_color", _text_color)
	text_label.add_theme_font_size_override("font_size", 19)
	hbox.add_child(text_label)


func _add_player_dialogue(text: String) -> void:
	var label = Label.new()
	label.text = "You: %s" % text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	label.add_theme_color_override("font_color", Color(0.70, 0.85, 1.00, 1.0))
	label.add_theme_font_size_override("font_size", 19)
	_dialogue_container.add_child(label)

	# Scroll to bottom
	_scroll_to_bottom()


func _add_choice_button(choice: Dictionary) -> void:
	var btn = Button.new()
	btn.text = choice.get("label", "")
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)
	_style_button(btn)

	var choice_id = choice.get("id", "")
	var npc_name = choice.get("npc_name", "")
	btn.pressed.connect(_on_choice_pressed.bind(choice_id, npc_name))

	_choices_container.add_child(btn)


func _add_end_message() -> void:
	var label = Label.new()
	label.text = "— End of story —"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _accent_color)
	_choices_container.add_child(label)


func _on_choice_pressed(choice_id: String, npc_name: String) -> void:
	if choice_id == "__talk_to__":
		_enter_dialogue_mode(npc_name)
		return

	_scene_manager.make_choice(choice_id)


# ── Loading / Error states ─────────────────────────────────────

func _show_loading(is_loading: bool, message: String = "Thinking…") -> void:
	_loading_label.visible = is_loading
	_loading_label.text = "%s..." % message if is_loading else ""


func _show_error(message: String) -> void:
	_error_banner.text = message
	_error_banner.visible = true

	# Auto-hide after 5 seconds
	if _error_banner.get_parent():
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(func(): _error_banner.visible = false)


func _set_input_enabled(enabled: bool) -> void:
	_input_line.editable = enabled
	_send_button.disabled = not enabled
	if enabled:
		_input_line.grab_focus()


# ── Utility ────────────────────────────────────────────────────

func _scroll_to_bottom() -> void:
	_dialogue_scroll.scroll_vertical = floori(_dialogue_scroll.get_v_scroll_bar().max_value)
