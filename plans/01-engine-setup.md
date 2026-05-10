# Step 1: Engine Core Setup

**Phase:** 1 — Engine Core  
**Iteration:** 1 — Minimal Engine  
**Timeline:** Week 1–2

## Objective

Set up the Godot 4 project and implement a minimal state machine that loads and transitions between scenes defined in a hardcoded JSON format.

## Deliverables

- Godot 4 project with gl_compatibility renderer
- Minimal state machine (scene ID, flags, transitions)
- Hardcoded JSON story format (2–3 scenes, 1 choice, 1 flag)
- Scenes load and transition correctly from JSON

## Tasks

### 1.1 Project Scaffolding

- [ ] Initialize Godot 4 project (`project.godot`)
- [ ] Configure Git ignore for build artifacts

### 1.2 JSON Story Format Definition

- [ ] Design and document the story JSON schema covering:
  - [ ] Scenes (id, description, background, characters present)
  - [ ] Dialogue lines (speaker, text, metadata)
  - [ ] Choices (id, label, target scene, required flags)
  - [ ] Flags (name, initial value)
  - [ ] State changes triggered by scene entry/exit
- [ ] Create a minimal test story file (`stories/test_story.json`) with:
  - [ ] 2–3 scenes
  - [ ] At least 1 choice point
  - [ ] At least 1 flag that changes on scene transition

### 1.3 State Machine

- [ ] Implement `GameState` class in GDScript:
  - [ ] `current_scene` (string ID)
  - [ ] `flags` (map of string → bool)
  - [ ] `scene_history` (ordered list of visited scene IDs)
- [ ] Implement `SceneManager` class:
  - [ ] `load_story(path)` — parse JSON, register scenes
  - [ ] `enter_scene(scene_id)` — validate transition, set current scene, apply state changes
  - [ ] `get_current_scene()` — return current scene data
  - [ ] `make_choice(choice_id)` — validate choice prerequisites, transition to target
  - [ ] `get_available_choices()` — filter choices by flag requirements
- [ ] Implement JSON parser integration (use Godot's built-in JSON or nlohmann/json)

### 1.4 Basic UI

- [ ] Create a minimal Godot scene (`.tscn`) for display:
  - [ ] Text area for scene description
  - [ ] Dialogue display area
  - [ ] Choice buttons (dynamically generated)

### 1.5 Verification

- [ ] Load test story from JSON
- [ ] Navigate through all scenes
- [ ] Verify flag changes on transitions
- [ ] Verify choices appear/disappear based on flags
- [ ] Verify scene history is tracked correctly

## Acceptance Criteria

- [ ] Godot project builds and runs without errors
- [ ] Test story JSON loads and all scenes are accessible
- [ ] State machine correctly tracks flags, current scene, and history
- [ ] Choices are gated by flag prerequisites
- [ ] UI displays scene content and allows player interaction

## Dependencies

- Godot 4.x installed

## Notes

- Keep the JSON format simple and extensible — it will be the contract for the story editor later
- All story assets (JSON story, images, fonts, sounds) should live in the story-specific directory
- Use Godot's built-in JSON parsing where possible to minimize external dependencies
- All logic should live in GDScript; Godot editor is only for visual preview/debugging
