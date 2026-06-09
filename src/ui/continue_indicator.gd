## ContinueIndicator — Blinking "▼" prompt to advance dialogue.
##
## A standalone label that blinks on/off at a configurable interval.
## Drop it into any container next to dialogue text. Always reserves its
## fixed width so sibling text never reflows around it — the indicator
## fades via alpha instead of toggling visibility, keeping layout stable.
##
## Usage:
##   var indicator = ContinueIndicator.new()
##   add_child(indicator)
##   indicator.start_blinking()
##   indicator.stop_blinking()

extends Label
class_name ContinueIndicator

const _MIN_SIZE := Vector2(36, 36)

# ── Internal nodes ──────────────────────────────────────────────
var _blink_timer: Timer


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	text = "▼"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = _MIN_SIZE
	modulate.a = 0.0

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
	modulate.a = 1.0
	_blink_timer.start()


## Stop blinking and fade out the indicator (space is still reserved).
func stop_blinking() -> void:
	_blink_timer.stop()
	modulate.a = 0.0


# ── Timer callback ──────────────────────────────────────────────

func _on_blink_tick() -> void:
	modulate.a = 1.0 if modulate.a == 0.0 else 0.0
