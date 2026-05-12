## VNTheme — Shared colour palette and styling helpers for the VN UI.
##
## All UI components reference this for consistent theming.
## Attach nothing — use as a utility module via `preload` or `load`.

class_name VNTheme


# ── Colours ─────────────────────────────────────────────────────
const BG_COLOR := Color(0.05, 0.05, 0.07, 1.0)
const TEXT_COLOR := Color(0.95, 0.95, 0.92, 1.0)
const NARRATION_COLOR := Color(0.80, 0.80, 0.78, 1.0)
const SPEAKER_COLOR := Color(0.936, 0.967, 1.0, 1.0)
const PLAYER_COLOR := Color(0.70, 0.85, 1.00, 1.0)
const DESCRIPTION_COLOR := Color(0.85, 0.85, 0.80, 1.0)

const DIALOGUE_BOX_BG := Color(0.06, 0.06, 0.10, 0.88)
const DIALOGUE_BOX_BORDER := Color(0.30, 0.35, 0.50, 0.9)

const CHOICE_BG_COLOR := Color(0.12, 0.16, 0.28, 0.92)
const CHOICE_HOVER_COLOR := Color(0.22, 0.30, 0.50, 0.95)
const CHOICE_FOCUS_COLOR := Color(0.30, 0.40, 0.65, 0.95)

const INPUT_BG_COLOR := Color(0.12, 0.12, 0.15, 1.0)
const INPUT_BORDER_COLOR := Color(0.25, 0.30, 0.40, 1.0)

const ERROR_BG_COLOR := Color(0.50, 0.15, 0.15, 0.9)
const ERROR_TEXT_COLOR := Color(1.0, 0.8, 0.8, 1.0)

const LOADING_COLOR := Color(0.50, 0.50, 0.55, 1.0)


# ── Typography ──────────────────────────────────────────────────
const FONT_SIZE_NAME := 26
const FONT_SIZE_DIALOGUE := 22
const FONT_SIZE_DESCRIPTION := 22
const FONT_SIZE_CHOICE := 20
const FONT_SIZE_ERROR := 18
const FONT_SIZE_CONTINUE := 20


# ── Timing ──────────────────────────────────────────────────────
const TYPEWRITER_SPEED := 0.035      # seconds per character
const BLINK_INTERVAL := 0.6          # seconds per blink
const DESCRIPTION_FADE_IN := 0.8     # seconds
const DESCRIPTION_FADE_OUT := 1.0    # seconds
const DESCRIPTION_MIN_HOLD := 2.0    # seconds
const DESCRIPTION_MAX_HOLD := 6.0    # seconds
const DESCRIPTION_CHAR_TIME := 0.03  # seconds per char for hold calc
const ERROR_AUTO_DISMISS := 5.0      # seconds


# ── Styling helpers ─────────────────────────────────────────────

## Apply the standard VN choice-button style to a [Button].
static func style_choice_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = CHOICE_BG_COLOR
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = DIALOGUE_BOX_BORDER

	var hover = StyleBoxFlat.new()
	hover.bg_color = CHOICE_HOVER_COLOR
	hover.set_corner_radius_all(6)
	hover.set_border_width_all(1)
	hover.border_color = Color(0.45, 0.50, 0.70, 1.0)

	var focus = StyleBoxFlat.new()
	focus.bg_color = CHOICE_FOCUS_COLOR
	focus.set_corner_radius_all(6)
	focus.set_border_width_all(1)
	focus.border_color = Color(0.55, 0.60, 0.85, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_CHOICE)


## Build the dialogue box panel style.
static func create_dialogue_box_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = DIALOGUE_BOX_BG
	style.set_border_width_all(1)
	style.border_color = DIALOGUE_BOX_BORDER
	style.set_corner_radius_all(6)
	return style


## Build a rounded filled panel style.
static func create_filled_panel(bg_color: Color, corner_radius: int = 6) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	return style
