## CharacterSprite — Displays a character portrait above the dialogue box.
##
## Classic visual novel style: character sprite fades in when they speak,
## fades out for narration. Supports multiple mood expressions per character.
##
## Sprite naming convention (relative to story folder):
##   sprites/{character_id_lowercase}_{mood}.png
##
## Default moods are loaded from story.json `sprites.default_moods`.
## Scene-level mood overrides come from `scene_moods` in each scene.
##
## Usage:
##   var sprite = CharacterSprite.new()
##   add_child(sprite)
##   sprite.set_default_moods({"Haruka": "neutral", "Kenji": "determined"})
##   sprite.show_character("Haruka", "neutral")
##   sprite.show_character("Haruka", "neutral", {"offset_x": 50, "offset_y": -20, "flip_h": true})
##   sprite.hide_character()

extends Control
class_name CharacterSprite


# Mood fallback chain — try these in order if the preferred mood is missing
const _MOOD_FALLBACKS: Array[String] = ["neutral", "polite", "front", "determined", "happy", "angry", "side"]

# Default sprite offsets (pixels from base position)
const _DEFAULT_OFFSET_X: int = 0
const _DEFAULT_OFFSET_Y: int = 0


# ── Internal nodes ──
var _sprite_rect: TextureRect
var _fade_tween: Tween
var _current_character: String = ""
var _current_sprite_config: Dictionary = {}  # cached config for set_mood reuse
var _default_moods: Dictionary = {}           # loaded from story.json sprites.default_moods


# ── Public API ──────────────────────────────────────────────────

## Set default moods per character from story.json `sprites.default_moods`.
func set_default_moods(moods: Dictionary) -> void:
	_default_moods = moods


## Show a character sprite by character ID (e.g. "Haruka").
## Optionally specify a mood expression (e.g. "angry", "happy").
## If mood is empty, falls back to story-level default_moods, then "neutral".
## Optionally pass a sprite config dict from story.json:
##   {"offset_x": int, "offset_y": int, "flip_h": bool}
## Returns true if a sprite was found and displayed.
func show_character(character_id: String, mood: String = "", sprite_config: Dictionary = {}) -> bool:
	if character_id.is_empty():
		_current_character = ""
		hide_character()
		return false

	if mood.is_empty():
		mood = _default_moods.get(character_id, "neutral")

	var sprite_path = _find_sprite(character_id, mood)
	if sprite_path.is_empty():
		push_warning("No sprite found for character '%s' (mood: %s)" % [character_id, mood])
		hide_character()
		return false

	var texture = load(sprite_path)
	if texture == null or not (texture is Texture2D):
		push_warning("Failed to load sprite texture: %s" % sprite_path)
		hide_character()
		return false

	_current_character = character_id
	_current_sprite_config = sprite_config

	_sprite_rect.texture = texture

	# Apply sprite config after texture is set so flip_h takes effect
	_apply_sprite_config(sprite_config)

	_sprite_rect.visible = true

	# Cancel any in-progress fade-out
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	# Fade in
	_sprite_rect.modulate = Color(1, 1, 1, 0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_sprite_rect, "modulate", Color(1, 1, 1, 1), 0.3)

	return true


## Switch the current character's mood (keeps same character, changes expression).
func set_mood(mood: String) -> bool:
	if not _sprite_rect.visible or _sprite_rect.texture == null:
		return false
	if _current_character.is_empty():
		return false
	return show_character(_current_character, mood, _current_sprite_config)


## Hide the character sprite with a fade-out.
func hide_character() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	if not _sprite_rect.visible:
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(_sprite_rect, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(_on_hide_complete)


## Get the currently displayed character ID.
func get_current_character() -> String:
	return _current_character


func _on_hide_complete() -> void:
	_sprite_rect.visible = false
	_sprite_rect.modulate = Color(1, 1, 1, 1)


## Apply per-character sprite positioning and flip from story.json config.
## Config dict: {"offset_x": int, "offset_y": int, "flip_h": bool}
func _apply_sprite_config(config: Dictionary) -> void:
	var offset_x: int = config.get("offset_x", _DEFAULT_OFFSET_X)
	var offset_y: int = config.get("offset_y", _DEFAULT_OFFSET_Y)
	var flip_h: bool = config.get("flip_h", false)

	# Apply horizontal flip
	_sprite_rect.flip_h = flip_h

	var texture = _sprite_rect.texture
	if texture == null:
		return

	var tex_size = texture.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		return

	var vp_size = get_viewport_rect().size

	# Scale sprite to fit within viewport, maintaining aspect ratio
	var scale = min(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	var display_w = tex_size.x * scale
	var display_h = tex_size.y * scale

	# Position: (offset_x, offset_y) is the sprite's bottom-left corner
	# relative to the screen's bottom-left corner
	_sprite_rect.offset_left = float(offset_x)
	_sprite_rect.offset_top = -(offset_y + display_h)
	_sprite_rect.offset_right = float(offset_x) + display_w
	_sprite_rect.offset_bottom = -float(offset_y)


# ── Sprite path resolution ──────────────────────────────────────

## Try to find a sprite file for the given character and mood.
## Falls back through _MOOD_FALLBACKS if the preferred mood doesn't exist.
func _find_sprite(character_id: String, mood: String) -> String:
	var base = character_id.to_lower()

	# Try the requested mood first
	var path = _build_sprite_path(base, mood)
	if _file_exists(path):
		return path

	# Try fallback moods
	for fallback_mood in _MOOD_FALLBACKS:
		if fallback_mood == mood:
			continue
		path = _build_sprite_path(base, fallback_mood)
		if _file_exists(path):
			return path

	return ""


func _build_sprite_path(character_base: String, mood: String) -> String:
	return GameConfig.resolve_asset_path("sprites/%s_%s.png" % [character_base, mood])


func _file_exists(path: String) -> bool:
	return ResourceLoader.exists(path)


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_sprite()


func _build_sprite() -> void:
	_sprite_rect = TextureRect.new()
	_sprite_rect.visible = false

	# Anchor to bottom-left corner of the screen.
	# Sprite coordinates (offset_x, offset_y) in story.json use
	# bottom-left as origin: x=0,y=0 is the screen's bottom-left.
	_sprite_rect.anchor_left = 0.0
	_sprite_rect.anchor_top = 1.0
	_sprite_rect.anchor_right = 0.0
	_sprite_rect.anchor_bottom = 1.0
	_sprite_rect.offset_left = 0
	_sprite_rect.offset_top = 0
	_sprite_rect.offset_right = 0
	_sprite_rect.offset_bottom = 0

	# Keep aspect ratio, fit within bounds
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_rect.modulate = Color(1, 1, 1, 1)

	add_child(_sprite_rect)
