# Step 5: Story Editor

**Phase:** 2 — Story Editor  
**Iteration:** 5 — Story Editor  
**Timeline:** Week 13+

## Objective

Build a story authoring tool that matches the engine's JSON data format. Supports the five-phase writing workflow (concept → bible → beat sheet → scenes → review) with LLM-assisted content generation.

## Deliverables

- Story editor data model matching engine's JSON format
- Story bible editor (characters, clues, locations)
- Clue graph visualization (connections, coverage, red herrings)
- Beat sheet builder (ordered, drag-and-drop)
- Scene generator (auto-assembles prompt from bible + beat + context, calls LLM)
- Coverage report (unreferenced clues, orphaned characters, missing scenes)
- Export to engine's JSON format

## Tasks

### 5.1 Editor Architecture

- [ ] Choose editor technology:
  - [ ] Option A: Web app (React/Vue + Node.js backend)
  - [ ] Option B: Desktop app (Tauri/Electron)
  - [ ] Option C: Godot-based editor (same engine, editor mode)
  - [ ] Decision criteria: LLM integration, export pipeline, development speed
- [ ] Set up editor project structure
- [ ] Define editor project file format (separate from engine JSON, intermediate format)

### 5.2 Core Data Model

- [ ] Implement editor data structures:
  - [ ] `Project` — top-level container
    - [ ] `title`, `description`, `version`
    - [ ] `characters` (Character[])
    - [ ] `clues` (Clue[])
    - [ ] `locations` (Location[])
    - [ ] `items` (Item[])
    - [ ] `beats` (Beat[])
    - [ ] `scenes` (Scene[])
    - [ ] `endings` (Ending[])
    - [ ] `timeline` (Timeline[])
- [ ] `Character` model:
  - [ ] `id`, `name`, `description`
  - [ ] `personality_traits` (string[])
  - [ ] `speech_patterns` (string[])
  - [ ] `secrets` (string[])
  - [ ] `relationships` (map of character_id → relationship description)
  - [ ] `motivation` (string)
  - [ ] `arc` (string) — character development arc
- [ ] `Clue` model (matches engine format):
  - [ ] `id`, `description`, `keywords`
  - [ ] `tiers` (Tier[])
  - [ ] `sources` (character_id[])
  - [ ] `connections` (clue_id[])
  - [ ] `is_red_herring` (boolean)
  - [ ] `placed_in_beats` (beat_id[]) — where this clue appears
- [ ] `Location` model:
  - [ ] `id`, `name`, `description`
  - [ ] `sensory_details` (string[]) — sights, sounds, smells
  - [ ] `objects` (item_id[])
  - [ ] `background_image` (path)
- [ ] `Beat` model:
  - [ ] `id`, `scene_number`, `summary`
  - [ ] `location_id` (string)
  - [ ] `characters_present` (character_id[])
  - [ ] `clues_available` (clue_id[])
  - [ ] `state_changes` (FlagChange[] + TrustChange[])
  - [ ] `choices` (Choice[])
  - [ ] `notes` (string) — author notes
- [ ] `Scene` model (full generated content):
  - [ ] `id`, `beat_id` (parent beat)
  - [ ] `description` (string) — scene setting
  - [ ] `dialogue` (DialogueLine[])
  - [ ] `choices` (Choice[])
  - [ ] `transitions` (Transition[])
  - [ ] `state_changes` (StateChange[])

### 5.3 Five-Phase Writing Workflow

- [ ] Implement phase-gated UI:
  - [ ] Phase 1: **Core Concept**
    - [ ] Premise form (title, logline, genre, tone)
    - [ ] Character roster (names, roles)
    - [ ] Ending definitions (outcomes, requirements)
    - [ ] LLM-assisted brainstorming (1–2 prompts)
  - [ ] Phase 2: **Story Bible**
    - [ ] Character detail editor (structured forms, not free text)
    - [ ] Clue editor (tiered definitions, connections)
    - [ ] Location editor (sensory details, objects)
    - [ ] Timeline editor (event ordering)
    - [ ] LLM-assisted fleshing out (5–8 prompts)
  - [ ] Phase 3: **Beat Sheet**
    - [ ] Ordered beat list (drag-and-drop reordering)
    - [ ] Beat detail panel (summary, clues, characters, state changes)
    - [ ] Clue placement tracking (which beat reveals which clue)
    - [ ] LLM-assisted beat generation (10–15 prompts)
  - [ ] Phase 4: **Scene Generation**
    - [ ] Scene-by-scene generation from beats
    - [ ] Auto-context assembly (bible + beat + prior scenes)
    - [ ] 2–3 scenes per prompt (batch generation)
    - [ ] In-order generation to maintain continuity
    - [ ] LLM-assisted scene writing (30–60 prompts)
  - [ ] Phase 5: **Consistency Pass**
    - [ ] Inconsistency flagging (contradictory facts, timeline errors)
    - [ ] Clue coverage report (unreferenced clues, orphaned clues)
    - [ ] Character coverage (orphaned characters, unused traits)
    - [ ] Tone audit (scene-by-scene tone analysis)
    - [ ] LLM-assisted review (5–10 prompts)

### 5.4 Story Bible Editor

- [ ] Character editor panel:
  - [ ] Structured form fields (not free text)
  - [ ] Relationship matrix visualization
  - [ ] Secret management (what each character knows/hides)
  - [ ] Speech pattern examples
- [ ] Clue editor panel:
  - [ ] Clue list with tier expansion
  - [ ] Prerequisite definition (flags, trust, other clues)
  - [ ] Source NPC assignment
  - [ ] Connection mapping
- [ ] Location editor panel:
  - [ ] Sensory detail fields (sight, sound, smell, touch)
  - [ ] Object/item placement
  - [ ] Background image reference

### 5.5 Clue Graph Visualization

- [ ] Implement interactive clue graph:
  - [ ] Nodes = clues (color-coded by status: placed, unreferenced, red herring)
  - [ ] Edges = connections between clues
  - [ ] Visual indicators for tier depth
  - [ ] Click to view/edit clue details
- [ ] Coverage visualization:
  - [ ] Highlight unreferenced clues (not placed in any beat)
  - [ ] Highlight orphaned clues (no connections)
  - [ ] Highlight red herrings distinctly
  - [ ] Show clue-to-beat mapping

### 5.6 Beat Sheet Builder

- [ ] Implement ordered beat list:
  - [ ] Drag-and-drop reordering
  - [ ] Expandable beat cards (summary preview)
  - [ ] Visual indicators for location, characters, clues
- [ ] Beat detail editor:
  - [ ] Summary text area
  - [ ] Location selector (from bible)
  - [ ] Character presence toggles
  - [ ] Clue assignment (which clues are available/revealed)
  - [ ] State change definitions (flags, trust)
  - [ ] Choice definitions (labels, target beats, conditions)

### 5.7 Scene Generator

- [ ] Implement auto-context assembly:
  - [ ] Gather relevant bible data (characters present, location, available clues)
  - [ ] Include prior scene context (last 2–3 scenes for continuity)
  - [ ] Include beat requirements (clues to reveal, state changes)
  - [ ] Construct structured prompt from assembled context
- [ ] Implement LLM integration:
  - [ ] Batch scene generation (2–3 scenes per prompt)
  - [ ] In-order generation to maintain continuity
  - [ ] Response parsing into Scene model
  - [ ] Validation against beat requirements
- [ ] Implement scene editing:
  - [ ] Rich text editor for dialogue and description
  - [ ] Choice editor (labels, targets, conditions)
  - [ ] State change editor (flags, trust, inventory)
  - [ ] Preview mode (renders scene as it would appear in engine)

### 5.8 Coverage Report and Consistency Checker

- [ ] Implement coverage analysis:
  - [ ] Unreferenced clues (defined but not placed in any beat)
  - [ ] Orphaned characters (defined but never present in any scene)
  - [ ] Missing scenes (beats without generated scenes)
  - [ ] Unused items (defined but not obtainable)
  - [ ] Unreachable endings (requirements impossible to satisfy)
- [ ] Implement consistency checking:
  - [ ] Timeline contradictions (events out of order)
  - [ ] Character knowledge violations (NPC knows unrevealed clues)
  - [ ] Trust level inconsistencies (tier requires trust not achievable)
  - [ ] Flag conflicts (same flag set differently in different paths)
- [ ] LLM-assisted review:
  - [ ] Send full story context for inconsistency analysis
  - [ ] Parse and display flagged issues
  - [ ] Suggest fixes

### 5.9 Export Pipeline

- [ ] Implement export to engine JSON format:
  - [ ] Transform editor data model → engine JSON schema
  - [ ] Validate all references (no broken IDs)
  - [ ] Validate all prerequisites (achievable conditions)
  - [ ] Generate complete story JSON file
  - [ ] Generate asset manifest (images, sprites referenced)
- [ ] Implement export validation:
  - [ ] Pre-export coverage report
  - [ ] Block export on critical errors (missing scenes, broken references)
  - [ ] Warn on non-critical issues (unreferenced clues, unused characters)
- [ ] Implement import (reverse pipeline):
  - [ ] Load engine JSON into editor data model
  - [ ] Allow editing and re-exporting

### 5.10 Verification

- [ ] Create a new story using the editor (full five-phase workflow)
- [ ] Export to engine JSON format
- [ ] Load exported story in the game engine
- [ ] Play through the exported story
- [ ] Verify all scenes, clues, choices, and endings work correctly
- [ ] Verify editor-produced data matches hand-crafted JSON structure

## Acceptance Criteria

- [ ] Editor supports full five-phase writing workflow
- [ ] Story bible editor provides structured forms for characters, clues, locations
- [ ] Clue graph visualization shows connections, coverage, and red herrings
- [ ] Beat sheet builder supports ordered, drag-and-drop beat management
- [ ] Scene generator auto-assembles context and calls LLM for content
- [ ] Coverage report identifies unreferenced clues, orphaned characters, missing scenes
- [ ] Consistency checker flags contradictions and violations
- [ ] Export produces valid engine JSON that loads and plays correctly
- [ ] Full pipeline validated: editor → export → engine → playthrough

## Dependencies

- Step 1–4 (Engine Core complete) — engine JSON format must be stable
- LLM server available for scene generation and review

## Notes

- **Data format first.** The engine's JSON format must be finalized before building the editor.
- Use Obsidian + LLM plugin for early story drafting while the custom editor is being built.
- Graduate to custom tool once engine data format is finalized.
- The editor should be able to import hand-crafted JSON (from the test story) for editing.
- Consider building the editor as a separate repository if technology stack differs from the engine.
