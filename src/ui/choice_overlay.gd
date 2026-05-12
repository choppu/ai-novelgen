## ChoiceOverlay — Dark backdrop with vertically stacked choice buttons.
##
## Appears over the game screen when the player must make a choice.
## Each choice is a Dictionary with at minimum a "label" key.
##
## Usage:
##   var overlay = ChoiceOverlay.new()
##   add_child(overlay)
##   overlay.choice_pressed.connect(_on_choice)
##   overlay.add_choice({"id": "talk_alice", "label": "Talk to Alice"})
##   overlay.add_choice({"id": "go_kitchen", "label": "Go to the kitchen"})
##   overlay.show_overlay()

extends Control
class_name ChoiceOverlay


# ── Signals ─────────────────────────────────────────────────────

## Emitted when a choice button is pressed.
## [code]choice_id[/code] — the choice id (from "id" key in dict)
## [code]npc_name[/code] — NPC name if this is a "__talk_to__" choice
signal choice_pressed(choice_id: String, npc_name: String)


# ── Internal nodes ──────────────────────────────────────────────
var _backdrop: ColorRect
var _button_container: VBoxContainer


# ── Public API ──────────────────────────────────────────────────

## Show the overlay with its current buttons.
func show_overlay() -> void:
	_backdrop.visible = true
	_button_container.visible = true


## Hide the overlay.
func hide_overlay() -> void:
	_backdrop.visible = false
	_button_container.visible = false


## Remove all choice buttons.
func clear() -> void:
	for child in _button_container.get_children():
		child.queue_free()


## Add a single choice button.
## [code]choice[/code] should have "label" (String) and optionally "id", "npc_name".
func add_choice(choice: Dictionary) -> void:
	var btn = Button.new()
	btn.text = choice.get("label", "")
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	VNTheme.style_choice_button(btn)

	var choice_id = choice.get("id", "")
	var npc_name = choice.get("npc_name", "")
	btn.pressed.connect(func(): choice_pressed.emit(choice_id, npc_name))

	_button_container.add_child(btn)


## Add an "End of story" label (no buttons).
func show_end_label() -> void:
	var end_label = Label.new()
	end_label.text = "— End of story —"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_color_override("font_color", VNTheme.TEXT_COLOR)
	end_label.add_theme_font_size_override("font_size", 26)
	_button_container.add_child(end_label)


# ── Construction ────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_backdrop()
	_build_button_container()


func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	add_child(_backdrop)


func _build_button_container() -> void:
	_button_container = VBoxContainer.new()
	_button_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_button_container.anchor_top = 0.3
	_button_container.anchor_bottom = 0.85
	_button_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_button_container.add_theme_constant_override("separation", 12)
	_button_container.visible = false
	add_child(_button_container)
