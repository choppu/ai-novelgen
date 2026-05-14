## ContinueIndicator — Blinking "▼" prompt to advance dialogue.
##
## A standalone label that blinks on/off at a configurable interval.
## Drop it into any container next to dialogue text. Always reserves its
## fixed width so sibling text never overlaps it.
##
## Usage:
##   var indicator = ContinueIndicator.new()
##   add_child(indicator)
##   indicator.start_blinking()
##   indicator.stop_blinking()

extends Label
class_name ContinueIndicator

const _MIN_SIZE := Vector2(30, 30)

# ── Internal nodes ──────────────────────────────────────────────
var _blink_timer: Timer


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	text = "▼"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	custom_minimum_size = _MIN_SIZE
	visible = false

	add_theme_color_override("font_color", VNTheme.get_text_color())
	add_theme_font_override("font", VNTheme.get_font_dialogue())
	add_theme_font_size_override("font_size", VNTheme.get_font_size_continue())

	_blink_timer = Timer.new()
	_blink_timer.wait_time = VNTheme.get_blink_interval()
	_blink_timer.one_shot = false
	_blink_timer.timeout.connect(_on_blink_tick)
	add_child(_blink_timer)


# ── Public API ──────────────────────────────────────────────────

## Start the blinking animation.
func start_blinking() -> void:
	visible = true
	_blink_timer.start()


## Stop blinking and hide the indicator (space is still reserved).
func stop_blinking() -> void:
	_blink_timer.stop()
	visible = false


# ── Timer callback ──────────────────────────────────────────────

func _on_blink_tick() -> void:
	visible = not visible
