## FontLoader — Loads story-specific fonts and provides them to UI components.
##
## Autoloaded as "FontLoader". Scans the fonts folder of the current story
## and loads all font files (.otf, .ttf, .ttc).
##
## Fonts are stored in a dictionary keyed by a logical name:
##   - "dialogue"  → primary font for dialogue and body text
##   - "name"      → font for speaker names (may be italic or bold variant)
##   - "choice"    → font for choice buttons
##   - "narration" → font for narration text
##
## If no story-specific font is found, falls back to ThemeDB.fallback_font.
##
## Usage:
##   var font = FontLoader.get_font("dialogue")
##   label.add_theme_font_override("font", font)

extends Node


# ── Font keys ───────────────────────────────────────────────────
const FONT_KEY_DIALOGUE := "dialogue"
const FONT_KEY_NAME := "name"
const FONT_KEY_CHOICE := "choice"
const FONT_KEY_NARRATION := "narration"


# ── Loaded fonts ────────────────────────────────────────────────
var _fonts: Dictionary = {}


# ── Initialization ─────────────────────────────────────────────

func _ready() -> void:
	_load_story_fonts()


## Load fonts from the current story's fonts folder.
func _load_story_fonts() -> void:
	var story_name := GameConfig.get_current_story()
	if story_name.is_empty():
		print("[FontLoader] No story configured — using fallback font.")
		_fonts = _make_fallback_fonts()
		return

	var fonts_dir := "res://stories/%s/fonts/" % story_name
	_fonts = _load_fonts_from_dir(fonts_dir)

	if _fonts.is_empty():
		print("[FontLoader] No fonts found in %s — using fallback font." % fonts_dir)
		_fonts = _make_fallback_fonts()
	else:
		print("[FontLoader] Loaded fonts for story '%s':" % story_name)
		for key in _fonts:
			print("  - %s: %s" % [key, _fonts[key].resource_path])


## Load all font files from a directory.
## Returns a dictionary mapping font keys to FontFile resources.
func _load_fonts_from_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)

	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var lower: String = file_name.to_lower()
		if lower.ends_with(".otf") or lower.ends_with(".ttf") or lower.ends_with(".ttc"):
			var font_path := dir_path + file_name
			var font_file := _load_font_file(font_path)
			if font_file != null:
				# Assign to the first available key (primary = dialogue)
				if not result.has(FONT_KEY_DIALOGUE):
					result[FONT_KEY_DIALOGUE] = font_file
					result[FONT_KEY_NAME] = font_file
					result[FONT_KEY_CHOICE] = font_file
					result[FONT_KEY_NARRATION] = font_file
				# If multiple fonts exist, assign them to different keys
				else:
					if not result.has(FONT_KEY_NAME):
						result[FONT_KEY_NAME] = font_file
					elif not result.has(FONT_KEY_NARRATION):
						result[FONT_KEY_NARRATION] = font_file
					elif not result.has(FONT_KEY_CHOICE):
						result[FONT_KEY_CHOICE] = font_file
		file_name = dir.get_next()

	dir.list_dir_end()
	return result


## Load a single font file, returning a FontFile or null.
func _load_font_file(path: String) -> FontFile:
	var font = ResourceLoader.load(path)
	if font is FontFile:
		return font
	return null


## Create a fallback font dictionary using the system fallback font.
func _make_fallback_fonts() -> Dictionary:
	var fallback := ThemeDB.fallback_font
	return {
		FONT_KEY_DIALOGUE: fallback,
		FONT_KEY_NAME: fallback,
		FONT_KEY_CHOICE: fallback,
		FONT_KEY_NARRATION: fallback,
	}


# ── Public API ──────────────────────────────────────────────────

## Get a font by key. Falls back to ThemeDB.fallback_font if not found.
func get_font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	return ThemeDB.fallback_font


## Get all loaded fonts as a dictionary.
func get_all_fonts() -> Dictionary:
	return _fonts.duplicate()


## Reload fonts (useful if story changes at runtime).
func reload_fonts() -> void:
	_fonts.clear()
	_load_story_fonts()
