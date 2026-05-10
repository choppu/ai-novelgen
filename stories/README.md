# Stories

Each story lives in its own folder with the following structure:

```
stories/
└── <story_name>/
    ├── story.json          # Story definition (scenes, characters, clues, etc.)
    ├── backgrounds/        # Background images (e.g. manor_exterior.png)
    ├── sprites/            # Character/prop sprites (e.g. guard_idle.png)
    ├── fonts/              # Custom fonts used in the story
    ├── music/              # Background music tracks
    └── sfx/                # Sound effects
```

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
