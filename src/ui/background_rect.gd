## BackgroundRect — Full-screen background image for the current scene.
##
## Usage:
##   var bg = BackgroundRect.new()
##   add_child(bg)
##   bg.set_texture(load("res://assets/bg_mansion.png"))

extends Control
class_name BackgroundRect


# ── Internal nodes ──────────────────────────────────────────────
var _texture_rect: TextureRect


# ── Public API ──────────────────────────────────────────────────

## Set the background texture. Hides the rect if texture is null.
func set_texture(texture: Texture2D) -> void:
	if texture:
		_texture_rect.texture = texture
		_texture_rect.visible = true
	else:
		_texture_rect.visible = false


## Hide the background.
func hide_background() -> void:
	_texture_rect.visible = false


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_rect()


func _build_rect() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.visible = false
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_texture_rect)
