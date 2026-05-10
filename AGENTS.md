# LLM-Powered Visual Novel Engine — Development Plan

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Game Engine (Godot)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ State Machine │  │ Scene Graph  │  │  Clue / Puzzle    │  │
│  │ (Fixed Logic) │  │ (Fixed Logic)│  │  System           │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬──────────┘  │
│         │                 │                    │             │
│  ┌──────▼─────────────────▼────────────────────▼───────────┐ │
│  │              LLM Integration Layer                       │ │
│  │  • Input Parser (player NL → structured intent)         │ │
│  │  • Dialogue Generator (NPC responses + metadata)        │ │
│  │  • Response Validator (clue gating, constraint checks)  │ │
│  └───────────────────────┬─────────────────────────────────┘ │
└───────────────────────────┼───────────────────────────────────┘
                            │ HTTP/JSON
┌───────────────────────────▼───────────────────────────────────┐
│              LLM Process (lemonade server)                    │
│  • Loads GGUF model                                           │
│  • Serves via OpenAI-compatible API                           │
│  • Q4_K_M quantization default                                │
└───────────────────────────────────────────────────────────────┘
```

---

## 1. Engine Design Decisions

### Core Principle: Fixed Logic for Story Progression

| Concern | Approach | Rationale |
|---|---|---|
| Scene transitions | Engine state machine | Deterministic, testable, author-controlled |
| Puzzle validation | Condition evaluator | Exact prerequisites, no LLM ambiguity |
| Ending determination | State evaluation | Reliable gating based on accumulated flags |
| NPC dialogue | LLM generation | Natural language, character voice, atmosphere |
| Player input parsing | LLM intent extraction | Flexible natural language understanding |
| Clue revelation | Engine-gated, LLM-delivered | Engine decides what's available, LLM weaves it into dialogue |

### State Model

```
GameState
├── flags         → Boolean markers for events (met_npc_1, puzzle_solved)
├── inventory     → Collected items
├── known_clues   → Clues the player has discovered
├── relationships → Numeric trust/karma per NPC
├── current_scene → Position in the story graph
└── scene_history → Ordered list of visited scenes
```

### Clue Architecture

- Clues are **author-defined entities** with prerequisites, sources, and effects
- Engine computes **available clues** per NPC per scene before calling the LLM
- LLM receives available clues in its prompt and weaves them into dialogue naturally
- LLM returns structured metadata (`revealed_clues_tiers` dictionary) alongside dialogue text
- Engine **validates** claimed clues against the available set — never trusts blindly
- **Keyword detection** in dialogue text serves as backup if LLM omits metadata
- Support **tiered clues** for gradual revelation (trust-gated progressive disclosure)

### LLM Communication Protocol

- LLM runs as **separate process** via `llama-server`
- Communication over **HTTP/JSON** (OpenAI-compatible API)
- Response format enforced: `{ dialogue, revealed_clues_tiers, emotional_state }`
- Human-paced interaction means HTTP overhead is negligible

---

## 2. Technology Stack

### Engine

| Component | Choice | Rationale |
|---|---|---|
| Game engine | **Godot 4** | Strong 2D, text-based scene files, CLI support |
| Language | **GDScript** | LLM-friendly, performance |
| Development style | **Code-first** | Editor used only for visual preview/debugging; all logic in GDScript |
| Scene files | `.tscn` as data | Plain text, LLM-readable, version-controllable |

### LLM

| Component | Choice | Rationale |
|---|---|---|
| Inference | **lemonade** (`lemond`) | GGUF support, Metal/Vulkan/CPU, built-in HTTP server |
| Default model | **Qwen 3.5 9B** (Q4_K_M) | Best balance of instruction following + creative quality at this size |
| Model type | **Base instruction-tuned** | Reliable JSON output and constraint adherence; creativity achieved through prompt engineering |
| Quantization | **Q4_K_M** default, Q5_K_M optional | Best quality/size tradeoff; avoid Q3 and below |


## 3. Development Phases

### Phase 1: Engine Core

Build the game engine first, then the story editor. This is **the correct order** because:

1. The story editor produces data that the engine consumes — you need to define the data format before you can build a tool that generates it
2. Early engine builds let you validate architecture decisions (state machine design, clue system, LLM integration) before investing in authoring tooling
3. You can test with hand-crafted JSON story data while building the engine, then replace it with editor-generated data later

That said, don't wait for a "complete" engine. Build iteratively:

```
Iteration 1: Minimal engine
  └── State machine + scene loading + hardcoded JSON story
  └── Verify: scenes transition correctly, flags work

Iteration 2: LLM integration
  └── llama.cpp server + HTTP client + input parser + dialogue display
  └── Verify: player types NL, gets NPC response with metadata

Iteration 3: Clue system
  └── Clue definitions + prerequisite checking + revelation tracking
  └── Verify: clues unlock correctly, LLM respects constraints

Iteration 4: Polish
  └── Inventory, relationships, multiple endings, save/load
  └── Verify: full playthrough with branching and endings

Iteration 5: Story editor
  └── Bible management + beat sheet + scene generation + export
  └── Verify: editor-produced data loads correctly in engine
```

### Phase 2: Story Editor

Build this after the engine's data format is stable.

**Core data model:**
- Characters (name, description, secrets, relationships, speech patterns)
- Clues (id, description, source, connections, tiers, prerequisites)
- Locations (name, sensory details, objects)
- Beats (scene number, summary, available clues, state changes)
- Scenes (dialogue, descriptions, choices, transitions)

**Core features:**
1. Phase-gated workflow (concept → bible → beat sheet → scenes → review)
2. Story bible editor (structured forms, not free text)
3. Clue graph visualization (connections, coverage, red herrings)
4. Beat sheet builder (ordered, drag-and-drop)
5. Scene generator (auto-assembles prompt from bible + beat + context, calls LLM)
6. Coverage report (unreferenced clues, orphaned characters, missing scenes)
7. Export to engine's JSON format

**Five-phase writing workflow:**
1. **Core Concept** — Premise, characters, endings, tone (1-2 prompts)
2. **Story Bible** — Characters, clues, locations, timeline (5-8 prompts)
3. **Beat Sheet** — Scene-by-scene outline with clue placement (10-15 prompts)
4. **Scene Generation** — Full content, 2-3 scenes per prompt, in order (30-60 prompts)
5. **Consistency Pass** — Inconsistency flags, clue coverage, tone audit (5-10 prompts)

---

## 5. Key Constraints to Remember

1. **LLM is a delivery mechanism, not the source of truth.** The engine owns all game state. The LLM generates text; the engine decides what happens.

2. **Never trust LLM output for game logic.** Always validate `revealed_clues_tiers` against the engine-computed available set. Always use keyword detection as backup.

3. **Prompt is your interface.** The quality of LLM integration depends on prompt engineering — rich persona cards, explicit constraints, structured tool calling — not model size alone.

4. **Data format first.** Define the engine's story JSON format early. Everything downstream (editor, export, LLM output parsing) depends on it.

5. **Iterate on a real story.** Hand-craft a small test story early. Abstract architecture discussions cannot replace the insights you get from actually playing through a branching narrative with LLM-generated dialogue.