# Audio System

## Overview

The audio system provides background music (BGM) and sound effects (SFX) driven by story data. It is managed by the `SoundManager` autoload singleton and the `SoundEvents` utility class.

### Components

| File | Role |
|---|---|
| `src/audio/sound_manager.gd` | Autoload singleton. Manages BGM crossfading, SFX voice pool, volume control |
| `src/audio/sound_events.gd` | Utility class. Maps game events to SFX paths, provides convenience API |

### Audio Busses

Two custom audio busses are created at startup:

- **BGM** — Background music (default volume: 70%)
- **SFX** — Sound effects (default volume: 80%)

Both route to Master. Use Godot's Audio Bus editor for fine-grained control (EQ, compression, etc.).

---

## Story JSON Audio Format

### Scene-level audio

```json
{
  "scenes": {
    "manor_entrance": {
      "music": "music/ambient_storm.ogg",
      "sfx": "sfx/door_creak.ogg",
      // ...
    },
    "garden": {
      "music": "music/ambient_storm.ogg",
      "sfx": ["sfx/rain_heavy.ogg", "sfx/footsteps.ogg"],
      // ...
    },
    "silent_room": {
      "music": "",
      // ...
    }
  }
}
```

- **`music`** (string) — Path to BGM track. Relative paths are resolved via `GameConfig.resolve_asset_path()`. Set to `""` to silence BGM for this scene. Omit to keep current track.
- **`sfx`** (string | string[]) — Sound effect(s) played on scene entry. Single string or array for multiple simultaneous sounds.

### Dialogue-level SFX

```json
{
  "dialogue": [
    {
      "speaker": "Guard",
      "text": "Halt!",
      "sfx": "sfx/tension_rise.ogg"
    }
  ]
}
```

- **`sfx`** (string) — Sound effect played when this dialogue line begins display.

### Choice-level SFX

```json
{
  "choices": [
    {
      "id": "open_door",
      "label": "Open the door",
      "target": "study",
      "sfx": "sfx/door_creak.ogg"
    }
  ]
}
```

- **`sfx`** (string) — Sound effect played when this choice is selected (in addition to the default click sound).

### Story-level audio config (event overrides)

```json
{
  "audio": {
    "choice_click": "res://audio/sfx/custom_click.ogg",
    "clue_revealed": "res://audio/sfx/magical_chime.ogg"
  }
}
```

Override default event-to-SFX mappings for this story.

---

## Sound Events

### Engine defaults (always available)

| Event | When triggered | Default path |
|---|---|---|
| `choice_hover` | Mouse enters a choice button | `sfx/hover.mp3` |
| `choice_click` | Choice button pressed | `sfx/click.mp3` |
| `back_button` | Back button pressed | `sfx/back.mp3` |
| `scene_transition` | Scene entry | `sfx/scene_transition.mp3` |
| `clue_revealed` | Clue accepted by validator | `sfx/clue_reveal.mp3` |

### Story-defined sounds (in `story.json` → `audio`)

Emotional, ambient, and atmospheric sounds are defined per-story. Each story maps generic event names to its own audio files:

```json
{
  "audio": {
    "tension_rise":  "sfx/tension_rise.mp3",
    "realization":   "sfx/realization.mp3",
    "heartbeat":     "sfx/heartbeat.mp3",
    "rain_heavy":    "sfx/rain_heavy.mp3",
    "door_creak":    "sfx/door_creak.mp3",
    "footsteps":     "sfx/footsteps.mp3",
    "clock_tick":    "sfx/clock_tick.mp3"
  }
}
```

Once defined, use them anywhere via `SoundEvents.play("tension_rise")`. Missing paths produce a warning but never crash.

---

## API Reference

### SoundManager (autoload)

```gdscript
# BGM
SoundManager.play_bgm("res://audio/music/theme.ogg")    # Play/crossfade to track
SoundManager.stop_bgm()                                  # Stop immediately
SoundManager.fade_out_bgm(1.0)                           # Fade out over 1 second
SoundManager.is_bgm_playing()                            # bool
SoundManager.get_current_bgm()                           # String (path)

# SFX
SoundManager.play_sfx("res://audio/sfx/click.ogg")       # Play one-shot
SoundManager.play_sfx_volumes("...", 0.5)                # Play with custom volume

# Volume
SoundManager.set_master_volume(1.0)   # 0.0–1.0
SoundManager.set_bgm_volume(0.7)      # 0.0–1.0
SoundManager.set_sfx_volume(0.8)      # 0.0–1.0

# Crossfade
SoundManager.crossfade_duration = 1.5  # seconds
```

### SoundEvents (utility)

```gdscript
# Play by event name
SoundEvents.play("choice_click")

# Override event path
SoundEvents.set_event_path("choice_click", "res://audio/sfx/new_click.ogg")

# Load from story config dict
SoundEvents.load_from_config({"choice_click": "path.ogg"})

# Scene/choice/dialogue helpers (resolve paths automatically)
SoundEvents.play_scene_sfx(scene_data_dict)
SoundEvents.play_choice_sfx(choice_data_dict)
SoundEvents.play_dialogue_sfx(line_data_dict)
SoundEvents.play_clue_revealed()
```

---

## File Format Requirements

- **Supported formats**: `.ogg` (recommended), `.wav`, `.mp3`
- **BGM**: Looping OGG files (set looping flag in Godot import settings)
- **SFX**: Short non-looping sounds
- **Placement**: Store in `audio/music/` and `audio/sfx/` directories, or use `res://` absolute paths

### Import settings

In Godot, select your audio files and in the Import dock:
- **BGM tracks**: Check "Loopable" for seamless looping
- **SFX**: Leave defaults (no loop)

---

## Adding Audio to a Story

1. Place music files in `audio/music/` and SFX in `audio/sfx/`
2. Add `"music"` and `"sfx"` fields to scenes in `story.json`
3. Override event sounds via the `"audio"` section in story root
4. Test with Godot's audio bus viewer to verify levels
