# Stories

Each story lives in its own folder with the following structure:

```
stories/
└── <story_name>/
    ├── story.json          # Story definition (scenes, characters, clues, etc.)
    ├── styles.json         # Colours, typography, timing, UI backgrounds
    ├── backgrounds/        # Scene background images (e.g. manor_exterior.png)
    ├── ui/                 # Story-specific UI background images
    │   ├── dialogue_box.png   # Background for the explore-mode dialogue panel
    │   ├── npc_chat.png       # Background for the NPC chat (IRC-style) panel
    │   └── choice_button.png  # Background texture for choice buttons
    ├── sprites/            # Character/prop sprites (e.g. guard_idle.png)
    ├── fonts/              # Custom fonts used in the story
    ├── music/              # Background music tracks
    └── sfx/                # Sound effects
```

## `ui/` — Per-story UI backgrounds (unique visual style per game)

Each story gets its own visual identity through custom UI background images.
These replace the default solid-colour panels with story-themed artwork.

### How it works

1. Place images in the story's `ui/` folder
2. Reference them in `styles.json` under `ui_backgrounds`
3. The engine loads them at startup and applies them automatically
4. If an image is missing or path is empty, the solid-colour fallback is used

```json
{
  "ui_backgrounds": {
    "dialogue_box":  "ui/dialogue_box.png",
    "npc_chat":      "ui/npc_chat.png",
    "choice_button": "ui/choice_button.png"
  }
}
```

### Image specifications

| Key | Used for | Recommended size | Stretch mode |
|---|---|---|---|
| `dialogue_box` | Bottom dialogue panel (explore mode) | 1920×220 | `KEEP_ASPECT_COVERED` |
| `npc_chat` | Full-screen NPC chat background | 1920×1080 | `KEEP_ASPECT_COVERED` |
| `choice_button` | Individual choice buttons | 200×56 | 9-patch (12px margins) |

### Design tips

- **dialogue_box**: Design a horizontal panel. Text is overlaid on top with margins, so keep important artwork toward the edges or use subtle textures.
- **npc_chat**: This is the full-screen background behind the IRC-style chat. Use atmospheric imagery that sets the mood — the chat bubbles use semi-transparent colours so the background shows through.
- **choice_button**: This becomes a 9-patch texture (12px inset on all sides). Design with corner detail and a stretchable center. The button text is centered.

### Example: two stories, two styles

```
shadow_photo_studio/ui/          whispering_manor/ui/
├── dialogue_box.png (warm)      ├── dialogue_box.png (cool blue)
├── npc_chat.png (film grain)    ├── npc_chat.png (gothic)
└── choice_button.png (amber)    └── choice_button.png (indigo)
```

Each story feels completely different despite sharing the same engine code.

## `story.json`

All asset paths in `story.json` are **relative to the story root** (the folder containing `story.json`).

Example references:
```json
{
  "scenes": {
    "manor_entrance": {
      "background": "backgrounds/manor_exterior.png",
      "characters": ["Guard"],
      "character_sprites": {
        "Guard": "sprites/guard_idle.png"
      }
    }
  }
}
```

## Naming conventions

- **Folders**: snake_case (e.g. `whispering_manor`)
- **Files**: snake_case with extensions (e.g. `manor_exterior.png`, `ambient_rain.ogg`)
