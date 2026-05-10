# Story JSON Format

This document defines the JSON schema consumed by the novel engine.
All story data lives in `stories/*.json`.

## Schema

```jsonc
{
  "metadata": {
    "title": "string",        // Story title
    "author": "string",       // Author name
    "start_scene": "string"   // ID of the opening scene
  },
  "flags": {                  // Global boolean state markers
    "flag_name": {
      "initial": true | false
    }
  },
  "relationships": {          // NPC trust/karma values
    "npc_name": 0             // Initial trust level (int)
  },
  "clues": {                  // Clue definitions (see Clue section below)
    "clue_id": {
      "description": "string",
      "sources": ["npc_id", ...],
      "connections": ["clue_id", ...],
      "is_red_herring": boolean,
      "tiers": [
        {
          "tier": 1,
          "text": "string",
          "requires_trust": 0,
          "requires_flags": ["flag_name", ...],
          "valid_scenes": ["scene_id", ...],
          "set_flags": { "flag_name": true | false }
        }
      ]
    }
  },
  "characters": {             // Character definitions (see Character Cards below)
    "character_id": {
      "name": "string",
      "appearance": "string",
      "background": "string",
      "temperament": "string",
      "mood": "string",
      "can_reveal": ["clue_id", ...]
    }
  },
  "scenes": {
    "scene_id": {
      "description": "string",
      "background": "string | null",
      "characters": ["string", ...],
      "dialogue": [
        {
          "speaker": "string",
          "text": "string"
        }
      ],
      "choices": [
        {
          "id": "string",
          "label": "string",
          "target": "string",
          "requires_flags": { },
          "set_flags": { },
          "set_relationships": { "npc_name": int }
        }
      ],
      "on_enter": {
        "set_flags": { },
        "set_relationships": { "npc_name": int }
      }
    }
  }
}
```

## Field Descriptions

### `characters` (Character Cards)

Character definitions provide the LLM with rich persona context. Each character
is keyed by a unique string ID that matches references in scene `characters` arrays
and clue `sources`.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Display name used in dialogue |
| `appearance` | string | Yes | Physical description for scene setting |
| `background` | string | Yes | Backstory and motivations |
| `temperament` | string | Yes | Speech patterns and personality |
| `mood` | string | Yes | Current emotional state for the scene |
| `can_reveal` | string[] | Yes | Clue IDs this NPC can reveal |

The character card is assembled into the LLM prompt so the NPC responds in
character. The `can_reveal` field tells the engine which clues this NPC is
authorized to disclose (gate-checked by the clue system).

### `metadata`
Top-level story information. `start_scene` must reference a valid scene ID.

### `flags`
Boolean markers that track story state (e.g., `met_detective`, `found_letter`).
Each flag has an `initial` value. The engine may override flags via
`on_enter` blocks or choice `set_flags`.

### `relationships`
NPC trust/karma values. Each key is an NPC name, each value is an integer
trust level. Higher values mean the NPC is more willing to share information.

| Trust Range | NPC Behavior |
|---|---|
| 0–1 | Guarded, evasive, cold |
| 2–3 | Cautiously curious, shares small details |
| 4–5 | Beginning to trust, shares meaningful info |
| 6–7 | Trusts fairly well, shares most info |
| 8+ | Fully trusts, shares everything including secrets |

### `clues`
Author-defined entities that the engine tracks and gates. The engine decides
what clues are available per NPC per scene; the LLM weaves them into dialogue
naturally.

#### Clue Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `description` | string | Yes | Internal description for prompt context |
| `sources` | string[] | Yes | NPC IDs that can reveal this clue |
| `connections` | string[] | No | Related clue IDs (for coverage tracking) |
| `is_red_herring` | boolean | No | `true` if this is a false lead |
| `tiers` | Tier[] | Yes | Progressive disclosure levels |

#### Tier Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tier` | int | Yes | Level number (1, 2, 3, ...) |
| `text` | string | Yes | What the NPC says at this tier (for prompt context) |
| `requires_trust` | int | No | Minimum trust level with the source NPC |
| `requires_flags` | string[] \| object | No | Flags that must be true |
| `valid_scenes` | string[] | No | Scene IDs where this tier is available |
| `set_flags` | object | No | Flags automatically set when this tier is revealed |

#### Clue Revelation Flow

1. Engine loads all clue definitions from story JSON
2. When player interacts with an NPC, engine calls `get_available_clues(npc_id, scene_id)`
3. For each clue where the NPC is a source:
   - Tiers are sorted ascending
   - Already-revealed tiers are skipped
   - First unrevealed tier with all prerequisites met is returned
4. Available clues (with tier info) are included in the LLM prompt
5. LLM weaves clues naturally into dialogue
6. LLM returns `revealed_clues` and `revealed_clue_tiers` in JSON
7. Engine validates claimed clues against available set
8. If valid, engine records the revelation in `ClueTracker`
9. If the tier defines `set_flags`, those flags are applied to game state


#### Example: Tiered Clue

```jsonc
"the_mysterious_letter": {
  "description": "A crumpled letter found on the grounds",
  "sources": ["Guard"],
  "connections": ["library_secret"],
  "is_red_herring": false,
  "tiers": [
    {
      "tier": 1,
      "text": "Guard mentions finding a crumpled letter",
      "requires_trust": 0,
      "requires_flags": ["found_letter"],
      "set_flags": { "guard_shared_letter": true }
    },
    {
      "tier": 2,
      "text": "Guard reveals the letter mentions something in the library",
      "requires_trust": 2,
      "requires_flags": ["found_letter"]
    },
    {
      "tier": 3,
      "text": "Guard reveals initials 'A.F.' and warns to trust no one",
      "requires_trust": 4,
      "requires_flags": ["found_letter"]
    }
  ]
}
```

### `scenes.<id>`
Each scene is keyed by a unique string ID.

| Field | Type | Required | Description |
|---|---|---|---|
| `description` | string | Yes | Narrative text setting the scene |
| `background` | string \| null | No | Asset key for background image |
| `characters` | string[] | No | List of character names present |
| `dialogue` | DialogueLine[] | No | Ordered dialogue lines |
| `choices` | Choice[] | No | Player choice options |
| `on_enter` | OnEnter | No | State changes on scene entry |

### `DialogueLine`

| Field | Type | Required | Description |
|---|---|---|---|
| `speaker` | string | Yes | Speaker name; `""` for narration |
| `text` | string | Yes | The dialogue text |

### `Choice`

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | Yes | Unique choice identifier |
| `label` | string | Yes | Text displayed on the choice button |
| `target` | string | Yes | Scene ID to transition to |
| `requires_flags` | object | No | Flags that must match for this choice to appear |
| `set_flags` | object | No | Flags set when this choice is selected |
| `set_relationships` | object | No | NPC trust values set when this choice is selected |

### `OnEnter`

| Field | Type | Required | Description |
|---|---|---|---|
| `set_flags` | object | No | Flags automatically set when entering this scene |
| `set_relationships` | object | No | NPC trust values set when entering this scene |

## Extensibility Notes

- `requires_flags` uses exact boolean matching — a choice appears only when
  **all** specified flags match their required values.
- Clues are **author-defined entities** — the engine decides what's available,
  the LLM delivers it naturally.
- Clue revelations rely solely on the LLM's structured tool call output;
  there is no keyword-based fallback detection.
