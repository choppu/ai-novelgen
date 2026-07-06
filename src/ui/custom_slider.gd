## CustomSlider — A styled horizontal slider for the settings menu.
##
## Draws its own track and grip with rounded corners, glow effects,
## and smooth hover/press states. Emits `value_changed` like HSlider.
##
## Usage:
##   var slider = CustomSlider.new()
##   slider.min_value = 0.0
##   slider.max_value = 1.0
##   slider.set_value(0.5)
##   slider.value_changed.connect(func(v): print(v))
##   add_child(slider)

extends Control
class_name CustomSlider


# ── Signals ─────────────────────────────────────────────────────
signal value_changed(value: float)


# ── Backing fields (no setters to avoid recursion) ──────────────
var _min: float = 0.0
var _max: float = 1.0
var _value: float = 0.5


# ── Public properties (accessed via getters/setters) ────────────

func get_min_value() -> float:
	return _min

func set_min_value(v: float) -> void:
	_min = v
	_value = clampf(_value, _min, _max)
	queue_redraw()

func get_max_value() -> float:
	return _max

func set_max_value(v: float) -> void:
	_max = v
	_value = clampf(_value, _min, _max)
	queue_redraw()

func get_value() -> float:
	return _value

func set_value(v: float) -> void:
	var new_val = clampf(v, _min, _max)
	if new_val != _value:
		_value = new_val
		queue_redraw()
		value_changed.emit(_value)


# ── Internal state ──────────────────────────────────────────────
var _dragging: bool = false
var _hovered: bool = false

# Colours — override via set_colors()
var _track_bg: Color = Color(0.12, 0.12, 0.16, 1.0)
var _track_fill: Color = Color(0.6, 0.15, 0.18, 1.0)
var _grip_color: Color = Color(0.90, 0.90, 0.90, 1.0)
var _grip_hover: Color = Color(1.0, 1.0, 1.0, 1.0)
var _grip_press: Color = Color(0.80, 0.80, 0.80, 1.0)

# Dimensions
var _track_height: float = 8.0
var _grip_radius: float = 14.0
var _grip_hover_radius: float = 17.0
var _track_corner_radius: float = 4.0


# ── Public API ──────────────────────────────────────────────────

func set_colors(track_bg: Color, track_fill: Color, grip: Color) -> void:
	_track_bg = track_bg
	_track_fill = track_fill
	_grip_color = grip
	queue_redraw()


func set_dimensions(track_height: float, grip_radius: float) -> void:
	_track_height = track_height
	_grip_radius = grip_radius
	_grip_hover_radius = grip_radius + 3.0
	queue_redraw()


# ── Drawing ─────────────────────────────────────────────────────

func _draw() -> void:
	if size.x < 20:
		return

	var center_y = size.y / 2.0
	var track_left = _grip_radius
	var track_right = size.x - _grip_radius
	var track_width = track_right - track_left

	# ── Background track ──
	_draw_rounded_rect(Rect2(track_left, center_y - _track_height / 2.0, track_width, _track_height), _track_bg)

	# ── Filled portion ──
	var fill_width = track_width * _get_ratio()
	if fill_width > 1:
		_draw_rounded_rect(Rect2(track_left, center_y - _track_height / 2.0, fill_width, _track_height), _track_fill)

	# ── Grip ──
	var grip_pos_x = _get_grip_position(track_left, track_width)
	var radius = _grip_hover_radius if _hovered or _dragging else _grip_radius
	var grip_col = _grip_color
	if _dragging:
		grip_col = _grip_press
	elif _hovered:
		grip_col = _grip_hover

	_draw_circle_shadow(Vector2(grip_pos_x, center_y), radius + 6.0, Color(0.6, 0.6, 0.6, 0.25))
	draw_circle(Vector2(grip_pos_x, center_y), radius, grip_col)
	draw_circle(Vector2(grip_pos_x, center_y), radius * 0.55, Color(1.0, 1.0, 1.0, 0.30))


func _get_ratio() -> float:
	if _max == _min:
		return 0.0
	return clampf((_value - _min) / (_max - _min), 0.0, 1.0)


func _get_grip_position(track_left: float, track_width: float) -> float:
	return track_left + track_width * _get_ratio()


func _draw_rounded_rect(rect: Rect2, color: Color) -> void:
	var r = rect.position.x
	var t = rect.position.y
	var w = rect.size.x
	var h = rect.size.y
	var cr = minf(_track_corner_radius, minf(w / 2.0, h / 2.0))
	if cr < 0.5:
		draw_rect(rect, color)
		return

	# 4 corner circles
	draw_circle(Vector2(r + cr, t + cr), cr, color)
	draw_circle(Vector2(r + w - cr, t + cr), cr, color)
	draw_circle(Vector2(r + w - cr, t + h - cr), cr, color)
	draw_circle(Vector2(r + cr, t + h - cr), cr, color)
	# Connecting bars
	draw_rect(Rect2(r + cr, t, w - cr * 2, h), color)
	draw_rect(Rect2(r, t + cr, w, h - cr * 2), color)


func _draw_circle_shadow(position: Vector2, radius: float, color: Color) -> void:
	for i in range(3, 0, -1):
		var alpha = color.a / float(i + 1)
		draw_circle(position, radius + i * 2.0, Color(color.r, color.g, color.b, alpha))


# ── Input handling ──────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _dragging:
			_update_value_from_mouse(event)
		else:
			var track_left = _grip_radius
			var track_width = size.x - _grip_radius * 2.0
			var grip_x = _get_grip_position(track_left, track_width)
			var was_hovered = _hovered
			_hovered = abs(event.position.x - grip_x) < (_grip_hover_radius + 4.0)
			if _hovered != was_hovered:
				queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_hovered = true
				_update_value_from_mouse(event)
				queue_redraw()
			else:
				_dragging = false
				queue_redraw()


func _update_value_from_mouse(event: InputEventMouse) -> void:
	var track_left = _grip_radius
	var track_right = size.x - _grip_radius
	var ratio = clampf((event.position.x - track_left) / (track_right - track_left), 0.0, 1.0)
	var new_val = _min + ratio * (_max - _min)
	if new_val != _value:
		_value = new_val
		queue_redraw()
		value_changed.emit(_value)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 40)
