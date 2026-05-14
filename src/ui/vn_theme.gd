## VNTheme — Shared colour palette and styling helpers for the VN UI.
##
## All UI components reference this for consistent theming.
## Colours, font sizes, and timing values are loaded from the current
## story's `styles.json` via [StoryStyle].
## Attach nothing — use as a utility module via `preload` or `load`.

class_name VNTheme


# ── Colours ─────────────────────────────────────────────────────
## Story-specific colours loaded from styles.json.

static func get_bg_color()            -> Color: return _style().get_bg_color()
static func get_text_color()          -> Color: return _style().get_text_color()
static func get_narration_color()     -> Color: return _style().get_narration_color()
static func get_speaker_color()       -> Color: return _style().get_speaker_color()
static func get_player_color()        -> Color: return _style().get_player_color()
static func get_description_color()   -> Color: return _style().get_description_color()

static func get_dialogue_box_bg()     -> Color: return _style().get_dialogue_box_bg()
static func get_dialogue_box_border() -> Color: return _style().get_dialogue_box_border()

static func get_choice_bg()           -> Color: return _style().get_choice_bg()
static func get_choice_hover()        -> Color: return _style().get_choice_hover()
static func get_choice_focus()        -> Color: return _style().get_choice_focus()

static func get_input_bg()            -> Color: return _style().get_input_bg()
static func get_input_border()        -> Color: return _style().get_input_border()

static func get_error_bg()            -> Color: return _style().get_error_bg()
static func get_error_text()          -> Color: return _style().get_error_text()

static func get_loading_color()       -> Color: return _style().get_loading_color()


# ── Typography ──────────────────────────────────────────────────
## Story-specific font sizes loaded from styles.json.

static func get_font_size_name()         -> int: return _style().get_font_size_name()
static func get_font_size_dialogue()     -> int: return _style().get_font_size_dialogue()
static func get_font_size_description()  -> int: return _style().get_font_size_description()
static func get_font_size_choice()       -> int: return _style().get_font_size_choice()
static func get_font_size_error()        -> int: return _style().get_font_size_error()
static func get_font_size_continue()     -> int: return _style().get_font_size_continue()


# ── Fonts (story-specific, loaded by FontLoader) ────────────────

## Get the dialogue font (primary font for body text).
static func get_font_dialogue() -> Font:
	return FontLoader.get_font(FontLoader.FONT_KEY_DIALOGUE)

## Get the speaker name font.
static func get_font_name() -> Font:
	return FontLoader.get_font(FontLoader.FONT_KEY_NAME)

## Get the choice button font.
static func get_font_choice() -> Font:
	return FontLoader.get_font(FontLoader.FONT_KEY_CHOICE)

## Get the narration font.
static func get_font_narration() -> Font:
	return FontLoader.get_font(FontLoader.FONT_KEY_NARRATION)


# ── Timing ──────────────────────────────────────────────────────
## Story-specific timing values loaded from styles.json.

static func get_typewriter_speed()      -> float: return _style().get_typewriter_speed()
static func get_blink_interval()        -> float: return _style().get_blink_interval()
static func get_description_fade_in()   -> float: return _style().get_description_fade_in()
static func get_description_fade_out()  -> float: return _style().get_description_fade_out()
static func get_description_min_hold()  -> float: return _style().get_description_min_hold()
static func get_description_max_hold()  -> float: return _style().get_description_max_hold()
static func get_description_char_time() -> float: return _style().get_description_char_time()
static func get_error_auto_dismiss()    -> float: return _style().get_error_auto_dismiss()


# ── Internal ────────────────────────────────────────────────────
static var _style_instance: StoryStyle

static func _style() -> StoryStyle:
	if _style_instance == null:
		_style_instance = StoryStyle.instance()
	return _style_instance


# ── Styling helpers ─────────────────────────────────────────────

## Apply the standard VN choice-button style to a [Button].
static func style_choice_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = get_choice_bg()
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = get_dialogue_box_border()

	var hover = StyleBoxFlat.new()
	hover.bg_color = get_choice_hover()
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.45, 0.50, 0.70, 1.0)

	var focus = StyleBoxFlat.new()
	focus.bg_color = get_choice_focus()
	focus.set_corner_radius_all(6)
	focus.set_border_width_all(1)
	focus.border_color = Color(0.55, 0.60, 0.85, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", get_text_color())
	btn.add_theme_font_override("font", get_font_choice())
	btn.add_theme_font_size_override("font_size", get_font_size_choice())


## Build the dialogue box panel style.
static func create_dialogue_box_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = get_dialogue_box_bg()
	style.set_border_width_all(1)
	style.border_color = get_dialogue_box_border()
	style.set_corner_radius_all(6)
	return style


## Build a rounded filled panel style.
static func create_filled_panel(bg_color: Color, corner_radius: int = 6) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	return style


# ── Backward-compat aliases (const names from old VNTheme) ─────
## These delegate to the dynamic getters so existing code using
## `VNTheme.BG_COLOR` etc. still compiles.

static func get_BG_COLOR()            -> Color: return get_bg_color()
static func get_TEXT_COLOR()          -> Color: return get_text_color()
static func get_NARRATION_COLOR()     -> Color: return get_narration_color()
static func get_SPEAKER_COLOR()       -> Color: return get_speaker_color()
static func get_PLAYER_COLOR()        -> Color: return get_player_color()
static func get_DESCRIPTION_COLOR()   -> Color: return get_description_color()
static func get_DIALOGUE_BOX_BG()     -> Color: return get_dialogue_box_bg()
static func get_DIALOGUE_BOX_BORDER() -> Color: return get_dialogue_box_border()
static func get_CHOICE_BG_COLOR()     -> Color: return get_choice_bg()
static func get_CHOICE_HOVER_COLOR()  -> Color: return get_choice_hover()
static func get_CHOICE_FOCUS_COLOR()  -> Color: return get_choice_focus()
static func get_INPUT_BG_COLOR()      -> Color: return get_input_bg()
static func get_INPUT_BORDER_COLOR()  -> Color: return get_input_border()
static func get_ERROR_BG_COLOR()      -> Color: return get_error_bg()
static func get_ERROR_TEXT_COLOR()    -> Color: return get_error_text()
static func get_LOADING_COLOR()       -> Color: return get_loading_color()

static func get_FONT_SIZE_NAME()         -> int: return get_font_size_name()
static func get_FONT_SIZE_DIALOGUE()     -> int: return get_font_size_dialogue()
static func get_FONT_SIZE_DESCRIPTION()  -> int: return get_font_size_description()
static func get_FONT_SIZE_CHOICE()       -> int: return get_font_size_choice()
static func get_FONT_SIZE_ERROR()        -> int: return get_font_size_error()
static func get_FONT_SIZE_CONTINUE()     -> int: return get_font_size_continue()

static func get_TYPEWRITER_SPEED()      -> float: return get_typewriter_speed()
static func get_BLINK_INTERVAL()        -> float: return get_blink_interval()
static func get_DESCRIPTION_FADE_IN()   -> float: return get_description_fade_in()
static func get_DESCRIPTION_FADE_OUT()  -> float: return get_description_fade_out()
static func get_DESCRIPTION_MIN_HOLD()  -> float: return get_description_min_hold()
static func get_DESCRIPTION_MAX_HOLD()  -> float: return get_description_max_hold()
static func get_DESCRIPTION_CHAR_TIME() -> float: return get_description_char_time()
static func get_ERROR_AUTO_DISMISS()    -> float: return get_error_auto_dismiss()
