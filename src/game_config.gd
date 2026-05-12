## GameConfig — Loads and provides access to game configuration.
##
## Autoloaded as "GameConfig". Reads config/game.json on startup.
extends Node


## ── Story settings ──
var _current_story: String


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var path = "res://config/game.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err = "Failed to open game config: %s (error %d)" % [path, FileAccess.get_open_error()]
		push_error(err)
		return

	var raw = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(raw)
	if parse_result is Dictionary:
		_current_story = (parse_result as Dictionary).get("current_story", "")
		print("=== Game Configuration ===")
		print("  Current story: %s" % _current_story)
		print("==========================")
	else:
		push_error("Failed to parse game config JSON")


## Get the name of the current story (folder name under stories/).
func get_current_story() -> String:
	return _current_story


## Get the full path to the story.json file for the current story.
func get_story_path() -> String:
	return "res://stories/%s/story.json" % _current_story

## Resolve a story-relative asset path to a full res:// path.
## Paths in story.json are relative to the story root folder.
func resolve_asset_path(relative_path: String) -> String:
	return "res://stories/%s/%s" % [_current_story, relative_path]
