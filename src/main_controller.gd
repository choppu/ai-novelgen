## MainController — Japanese Visual Novel style UI.
##
## Attached to the root Control node in main.tscn.
## Delegates UI rendering to self-contained components in src/ui/.
##
## Layout:
##   Background (full screen)
##   └── Top area: scene description flash (auto-fades)
##   └── Bottom: dialogue box (NPC name + text + continue indicator)
##   └── Overlay: choice buttons (appear after dialogue completes)
extends Control


## ── UI Components ──────────────────────────────────────────────
var _background: BackgroundRect
var _description_flash: DescriptionFlash
var _dialogue_box: DialogueBox
var _npc_chat_panel: NpcChatPanel
var _choice_overlay: ChoiceOverlay
var _loading_indicator: LoadingIndicator
var _error_banner: ErrorBanner


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
var _voice_generator

## ── Game Mode ─────────────────────────────────────────────────
## "explore" = showing scene choices, input hidden
## "dialogue" = chatting with NPC, input visible, back button to exit
var _mode: String = "explore"

## NPC currently being talked to
var _dialogue_npc: String = ""
var _npc_emotional_mood: int = 0

## ── Dialogue State Machine ────────────────────────────────────
## "idle" = waiting for player to advance
## "typing" = typewriter effect in progress
## "choices" = showing choice buttons
var _dialogue_state: String = "idle"

## True while waiting for LLM to respond (blocks dialogue advancement)
var _waiting_for_llm: bool = false

## Queue of dialogue lines to display (scene dialogue + LLM responses)
var _dialogue_queue: Array = []
var _current_line_index: int = 0

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
const _VoiceGeneratorScript = preload("res://src/voice_generator.gd")

## Preload UI components
const _BackgroundRectScript := preload("res://src/ui/background_rect.gd")
const _DescriptionFlashScript := preload("res://src/ui/description_flash.gd")
const _DialogueBoxScript := preload("res://src/ui/dialogue_box.gd")
const _ChoiceOverlayScript := preload("res://src/ui/choice_overlay.gd")
const _LoadingIndicatorScript := preload("res://src/ui/loading_indicator.gd")
const _ErrorBannerScript := preload("res://src/ui/error_banner.gd")
const _NpcChatPanelScript := preload("res://src/ui/npc_chat_panel.gd")


# ── Lifecycle ──────────────────────────────────────────────────

func _ready() -> void:
	_create_ui()
	_setup_scene_manager()
	_setup_clue_system()
	_setup_llm_pipeline()
	_load_story()

func _exit_tree() -> void:
	if _server != null:
		_server.stop()
	if _voice_generator != null:
		_voice_generator.clear_speaker_voices()


# ── UI Creation ────────────────────────────────────────────────

func _create_ui() -> void:
	# Scene background image (on top of solid bg, behind UI)
	_background = _BackgroundRectScript.new()
	add_child(_background)

	# Scene description flash (top center, auto-fades)
	_description_flash = _DescriptionFlashScript.new()
	add_child(_description_flash)

	# Dialogue box (bottom of screen, exploration mode only)
	_dialogue_box = _DialogueBoxScript.new()
	_dialogue_box.text_finished.connect(_on_text_finished)
	_dialogue_box.advance_requested.connect(_advance_dialogue)
	add_child(_dialogue_box)

	# Choice overlay (full screen, appears after dialogue)
	_choice_overlay = _ChoiceOverlayScript.new()
	_choice_overlay.choice_pressed.connect(_on_choice_pressed)
	add_child(_choice_overlay)
	
	# NPC chat panel (full-screen IRC-style chat, dialogue mode only)
	_npc_chat_panel = _NpcChatPanelScript.new()
	_npc_chat_panel.message_sent.connect(_on_chat_message_sent)
	_npc_chat_panel.back_pressed.connect(_exit_dialogue_mode)
	add_child(_npc_chat_panel)

	# Loading indicator (center screen)
	_loading_indicator = _LoadingIndicatorScript.new()
	add_child(_loading_indicator)

	# Error banner (top of screen)
	_error_banner = _ErrorBannerScript.new()
	add_child(_error_banner)


# ── SceneManager setup ─────────────────────────────────────────

func _setup_scene_manager() -> void:
	_scene_manager = _SceneManagerScript.new()
	_scene_manager.scene_changed.connect(_on_scene_changed)
	_scene_manager.story_loaded.connect(_on_story_loaded)
	_scene_manager.return_to_title_requested.connect(_on_return_to_title)


func _load_story() -> void:
	var story_path = GameConfig.get_story_path()
	_scene_manager.load_story(story_path)


# ── Clue system setup ──────────────────────────────────────────

func _setup_clue_system() -> void:
	_clue_tracker = _ClueTrackerScript.new()
	_clue_evaluator = _CluePrerequisiteEvaluatorScript.new(_clue_tracker)


func _reload_clue_definitions() -> void:
	var clues = _scene_manager.get_clues()
	_clue_evaluator.load_clues(clues)
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

	_memory_manager = _NPCMemoryScript.new()
	add_child(_memory_manager)
	_memory_manager.set_http_client(_http_client)
	_dialogue_generator.set_memory_manager(_memory_manager)

	# ── Voice (TTS) ──
	_voice_generator = _VoiceGeneratorScript.new()
	add_child(_voice_generator)
	_voice_generator.set_http_client(_http_client)
	_voice_generator.clear_speaker_voices()


# ── Signal handlers ────────────────────────────────────────────

func _on_story_loaded(success: bool, error_message: String) -> void:
	if success:
		_reload_clue_definitions()
		_setup_speaker_voices()
		_set_input_enabled(true)
	else:
		_show_error("Error: %s" % error_message)
		push_error(error_message)


func _on_text_finished() -> void:
	# Typewriter finished — transition controller state from typing → idle
	if _dialogue_state == "typing":
		_dialogue_state = "idle"


func _on_return_to_title() -> void:
	# Stop any in-progress voice generation
	if _voice_generator:
		_voice_generator.clear()
	# Reload the main scene to reset to title/start
	get_tree().reload_current_scene()


func _on_scene_changed(_scene_id: String, scene_data: Dictionary) -> void:
	var exited_dialogue = false
	if _mode == "dialogue":
		_exit_dialogue_mode()
		exited_dialogue = true

	# Clear conversation history on scene change
	if _dialogue_generator:
		_dialogue_generator.get_conversation_history().clear()

	# Clear voice queue on scene change
	if _voice_generator:
		_voice_generator.clear()

	# ── Audio: scene music + SFX ──
	_play_scene_audio(scene_data)

	if not exited_dialogue:
		_display_scene(scene_data)


func _on_dialogue_generated(response: Variant) -> void:
	_show_loading(false)
	_npc_chat_panel.set_input_enabled(true)
	_waiting_for_llm = false

	var target_npc = _dialogue_npc

	var available_clues = []
	if not target_npc.is_empty():
		var character_card = _scene_manager.get_character(target_npc)
		available_clues = _clue_evaluator.get_available_clues(
			target_npc, GameState.current_scene,
			character_card.get("can_reveal", [])
		)

	var validated = _response_validator.validate(response, available_clues)
	print("Validated response: %s" % validated.describe())

	# Record accepted clue revelations
	for clue_id in validated.accepted_clues:
		var tier = validated.accepted_clue_tiers.get(clue_id, 1)
		_clue_tracker.reveal_clue(clue_id, tier, GameState.current_scene)
		GameState.record_clue(clue_id, tier)
		print("Clue recorded: %s at tier %d" % [clue_id, tier])

		# ── Audio: clue revealed SFX ──
		SoundEvents.play_clue_revealed()

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

	# Add LLM response to chat
	_npc_chat_panel.append_message(_dialogue_npc, validated.dialogue, false)

	# ── Voice: generate TTS for NPC response ──
	_voice_generator.generate_and_play(validated.dialogue, _dialogue_npc)


func _on_generation_error(error_msg: String) -> void:
	_show_loading(false)
	_set_input_enabled(true)
	_waiting_for_llm = false
	_show_error("Generation error: %s" % error_msg)


# ── Player input handling ──────────────────────────────────────

func _on_chat_message_sent(text: String) -> void:
	if text.is_empty():
		return
	_process_player_input(text)


func _process_player_input(text: String) -> void:
	# Add player message to chat
	_npc_chat_panel.append_message("You", text, true)
	_npc_chat_panel.clear_input()
	_npc_chat_panel.set_input_enabled(false)
	_show_loading(true, "Thinking")
	_waiting_for_llm = true

	var scene_data = _scene_manager.get_current_scene()
	var scene_context = scene_data.get("description", "")

	var target_npc = _dialogue_npc
	var character_card = {}
	if not target_npc.is_empty():
		character_card = _scene_manager.get_character(target_npc)

	var available_clues = []
	if not target_npc.is_empty():
		available_clues = _clue_evaluator.get_available_clues(
			target_npc, GameState.current_scene,
			character_card.get("can_reveal", [])
		)

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


# ── Scene Display ──────────────────────────────────────────────

func _display_scene(scene_data: Dictionary) -> void:
	# Clear choices
	_choice_overlay.clear()
	_choice_overlay.hide_overlay()

	# Reset dialogue state
	_dialogue_queue.clear()
	_current_line_index = 0
	_waiting_for_llm = false

	# ── Background ──
	_load_background(scene_data)

	# ── Scene description flash ──
	var desc = scene_data.get("description", "")
	if not desc.is_empty():
		_description_flash.show_text(desc)

	# ── Build dialogue queue from scene ──
	var dialogue = scene_data.get("dialogue", [])
	for line in dialogue:
		if line is Dictionary:
			_dialogue_queue.append({
				"speaker": line.get("speaker", ""),
				"text": line.get("text", "")
			})

	# ── Mode-dependent behavior ──
	if _mode == "dialogue":
		_display_dialogue_mode()
		# Chat panel handles all display; skip dialogue box flow
		_dialogue_state = "idle"
	else:
		_display_explore_mode()

		# ── Start showing dialogue ──
		if _dialogue_queue.size() > 0:
			_dialogue_state = "idle"
			_current_line_index = 0
			_show_current_line()
		else:
			# No dialogue lines — show choices immediately
			_dialogue_state = "choices"
			_dialogue_box.hide_box()
			_show_choices()


# ── Dialogue Advancement ───────────────────────────────────────

## Show the current line from the dialogue queue with typewriter effect.
func _show_current_line() -> void:
	if _current_line_index >= _dialogue_queue.size():
		return

	var line = _dialogue_queue[_current_line_index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")

	# Show dialogue box
	_dialogue_box.show_box()

	# Set speaker name
	_dialogue_box.set_speaker(speaker, speaker == "You")

	# ── Voice: generate TTS for NPC lines ──
	if not speaker.is_empty() and speaker != "You":
		_voice_generator.generate_and_play(text, speaker)

	# ── Audio: per-line SFX (from scene JSON) ──
	SoundEvents.play_dialogue_sfx(line)

	# Start typewriter
	_dialogue_box.start_typing(text, speaker.is_empty())
	_dialogue_state = "typing"


func _advance_dialogue() -> void:
	if _dialogue_state == "typing":
		# Already handled in _unhandled_input
		return

	# Don't advance past the last line if waiting for LLM
	if _waiting_for_llm and _current_line_index >= _dialogue_queue.size() - 1:
		return

	# Move to next line
	_current_line_index += 1
	if _current_line_index >= _dialogue_queue.size():
		# All dialogue lines done
		_dialogue_state = "choices"
		_dialogue_box.hide_box()
		_show_choices()
		return

	_dialogue_state = "idle"
	_show_current_line()


# ── Choice Display ─────────────────────────────────────────────

func _show_choices() -> void:
	_choice_overlay.clear()

	# In dialogue mode, the back button in the input bar handles exiting.
	# No choice overlay needed — just keep the dialogue box visible.
	if _mode == "dialogue":
		return

	# Explore mode: synthesize "Talk to NPC" + story choices
	var scene_data = _scene_manager.get_current_scene()
	var characters = scene_data.get("characters", [])
	var has_any_choice = false

	if characters is Array:
		for npc_name in characters:
			var talk_choice = {
				"id": "__talk_to__",
				"label": "Talk to %s" % npc_name,
				"npc_name": npc_name
			}
			_choice_overlay.add_choice(talk_choice)
			has_any_choice = true

	var choices = _scene_manager.get_available_choices()
	for choice in choices:
		if choice is Dictionary:
			_choice_overlay.add_choice(choice)
			has_any_choice = true

	if not has_any_choice:
		_choice_overlay.show_end_label()

	_choice_overlay.show_overlay()


func _on_choice_pressed(choice_id: String, npc_name: String) -> void:
	# ── Audio: choice click SFX ──
	SoundEvents.play("choice_click")

	_choice_overlay.hide_overlay()

	if choice_id == "__talk_to__":
		_enter_dialogue_mode(npc_name)
		return

	_scene_manager.make_choice(choice_id)


# ── Explore / Dialogue Mode ────────────────────────────────────

func _display_explore_mode() -> void:
	pass


func _display_dialogue_mode() -> void:
	_npc_chat_panel.show_panel()
	# Populate chat with scene dialogue from this NPC
	var scene_data = _scene_manager.get_current_scene()
	var dialogue = scene_data.get("dialogue", [])
	for line in dialogue:
		if line is Dictionary and line.get("speaker", "") == _dialogue_npc:
			var text = line.get("text", "")
			if not text.is_empty():
				_npc_chat_panel.append_message(_dialogue_npc, text, false)
	_npc_chat_panel.set_input_enabled(true)


func _enter_dialogue_mode(npc_name: String) -> void:
	_mode = "dialogue"
	_npc_emotional_mood = 0
	_dialogue_npc = npc_name

	# Add NPC's opening lines to conversation history
	var current_scene = _scene_manager.get_current_scene()
	var history = _dialogue_generator.get_conversation_history()
	var scene_dialogue = current_scene.get("dialogue", [])
	for line in scene_dialogue:
		if line is Dictionary and line.get("speaker", "") == npc_name:
			var text = line.get("text", "")
			if not text.is_empty():
				history.add_llm_reply(text)

	# Clear chat and redisplay scene in dialogue mode
	_npc_chat_panel.clear_messages()
	_display_scene(current_scene)


func _exit_dialogue_mode() -> void:
	var exiting_npc = _dialogue_npc

	_npc_chat_panel.hide_panel()
	_npc_chat_panel.clear_messages()

	# Stop any in-progress voice generation
	if _voice_generator:
		_voice_generator.clear()

	_mode = "explore"
	_npc_emotional_mood = 0
	_dialogue_npc = ""

	# Trigger summarization
	if not exiting_npc.is_empty():
		var history = _dialogue_generator.get_conversation_history().get_messages()
		if not history.is_empty():
			var character = _scene_manager.get_character(exiting_npc)
			var background = character.get("background", "")
			_memory_manager.summarize(exiting_npc, history, background)

	# Skip re-displaying scene dialogue — go straight to choices
	_dialogue_box.hide_box()
	_dialogue_queue.clear()
	_current_line_index = 0
	_dialogue_state = "choices"
	_show_choices()


# ── Loading / Error states ─────────────────────────────────────

func _show_loading(is_loading: bool, message: String = "Thinking") -> void:
	if is_loading:
		_loading_indicator.show_loading(message)
	else:
		_loading_indicator.hide_loading()


func _show_error(message: String) -> void:
	_error_banner.show_error(message)


func _set_input_enabled(enabled: bool) -> void:
	if _mode == "dialogue":
		_npc_chat_panel.set_input_enabled(enabled)
	else:
		pass  # dialogue box has no input in explore mode


# ── Speaker Voice Setup ──────────────────────────────────────────

func _setup_speaker_voices() -> void:
	_voice_generator.clear_speaker_voices()
	var characters = _scene_manager.get_characters()
	for character_id in characters:
		var character = characters[character_id]
		if character is Dictionary:
			var char_name = character.get("name", character_id)
			var voice = character.get("voice", "")
			if not voice.is_empty():
				_voice_generator.set_speaker_voice(char_name, voice)
				# Also map by character id in case dialogue uses it
				_voice_generator.set_speaker_voice(character_id, voice)


# ── Audio ───────────────────────────────────────────────────────

func _play_scene_audio(scene_data: Dictionary) -> void:
	# ── BGM ──
	var music_path = scene_data.get("music", "")
	if music_path is String and not music_path.is_empty():
		var resolved = SoundManager.resolve_audio(music_path)
		SoundManager.play_bgm(resolved)
	elif scene_data.get("music", null) == null:
		# Scene has no music key — check if we should stop or keep current
		# Only stop if scene explicitly sets music to empty
		pass  # keep current BGM
	else:
		# Explicitly no music
		SoundManager.stop_bgm()

	# ── Scene entry SFX ──
	SoundEvents.play_scene_sfx(scene_data)

	# ── Scene transition SFX ──
	SoundEvents.play("scene_transition")


# ── Background ──────────────────────────────────────────────────

func _load_background(scene_data: Dictionary) -> void:
	var bg_path = scene_data.get("background", "")
	if bg_path is String and not bg_path.is_empty():
		var full_path = GameConfig.resolve_asset_path(bg_path)
		var texture = load(full_path)
		if texture is Texture2D:
			_background.set_texture(texture)
		else:
			_background.hide_background()
	else:
		_background.hide_background()
