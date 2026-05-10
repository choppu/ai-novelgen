# Step 4: Engine Polish

**Phase:** 1 — Engine Core  
**Iteration:** 4 — Polish  
**Timeline:** Week 9–12 (within Medium Term)

## Objective

Complete the engine with inventory system, relationship/trust tracking, ending evaluation logic, save/load system, and visual presentation. Create a test story (~30 minutes playtime) to validate the full pipeline.

## Deliverables

- Inventory system (item collection, usage, offering)
- Relationship/trust tracking per NPC
- Ending evaluation logic (state-based ending determination)
- Save/load system
- Basic visual presentation (backgrounds, character sprites, transitions)
- Test story (~30 minutes playtime, hand-crafted JSON)

## Tasks

### 4.1 Inventory System

- [ ] Extend story JSON schema with item definitions:
  - [ ] `items` array:
    - [ ] `id` (string) — unique identifier
    - [ ] `name` (string) — display name
    - [ ] `description` (string) — item description
    - [ ] `obtainable_from` (array of objects) — where/how to obtain
      - [ ] `scene_id` (string)
      - [ ] `condition` (object) — flags/clues required
- [ ] Extend `GameState` with:
  - [ ] `inventory` (list of item IDs)
- [ ] Implement `InventoryManager` class:
  - [ ] `add_item(item_id)` — add item to inventory
  - [ ] `remove_item(item_id)` — remove item from inventory
  - [ ] `has_item(item_id)` → `bool`
  - [ ] `get_all_items()` → `Item[]`
  - [ ] `can_offer_item(item_id, npc_id, scene_id)` → `bool` — check if NPC accepts this item
- [ ] Integrate with input parser:
  - [ ] Detect `offer_item` intent from player input
  - [ ] Validate item is in inventory
  - [ ] Pass item context to dialogue generator

### 4.2 Relationship / Trust Tracking

- [ ] Extend `GameState` with:
  - [ ] `relationships` (map of npc_id → trust_level, int)
- [ ] Implement `RelationshipManager` class:
  - [ ] `get_trust(npc_id)` → `int`
  - [ ] `set_trust(npc_id, level)` — direct set (for scene triggers)
  - [ ] `modify_trust(npc_id, delta)` — increment/decrement
  - [ ] `meets_trust_threshold(npc_id, threshold)` → `bool`
- [ ] Define trust change triggers in story JSON:
  - [ ] On scene entry/exit
  - [ ] On specific choices
  - [ ] On clue revelations
  - [ ] On item offers
- [ ] Integrate with clue system:
  - [ ] Trust level gates tiered clue revelation
  - [ ] LLM prompt includes current trust level for NPC behavior

### 4.3 Ending Evaluation

- [ ] Extend story JSON schema with ending definitions:
  - [ ] `endings` array:
    - [ ] `id` (string) — unique identifier
    - [ ] `name` (string) — display name
    - [ ] `description` (string) — ending text
    - [ ] `requirements` (object):
      - [ ] `flags` (object) — required flag states
      - [ ] `clues` (array of strings) — required known clues
      - [ ] `trust` (object) — required trust levels per NPC
      - [ ] `inventory` (array of strings) — required items
    - [ ] `priority` (number) — for resolving multiple matching endings
    - [ ] `is_good_ending` (boolean) — optional classification
- [ ] Implement `EndingEvaluator` class:
  - [ ] `check_endings(game_state)` → `Ending[]` — all matching endings
  - [ ] `get_best_ending(game_state)` → `Ending or null` — highest priority match
  - [ ] `can_reach_ending(ending_id, game_state)` → `bool` — is this ending still possible
- [ ] Implement ending scene:
  - [ ] Trigger ending evaluation at designated scenes
  - [ ] Display ending name and description
  - [ ] Show summary of key decisions/clues

### 4.4 Save / Load System

- [ ] Implement `SaveSystem` class:
  - [ ] `save(game_state, slot_id)` — serialize full game state to file
  - [ ] `load(slot_id)` → `GameState` — deserialize from file
  - [ ] `list_saves()` → `SaveInfo[]` — list available save slots
  - [ ] `delete_save(slot_id)` — remove save file
  - [ ] Auto-save on scene transitions (configurable)
- [ ] Define save file format:
  - [ ] JSON serialization of `GameState`
  - [ ] Include story file reference
  - [ ] Include metadata (timestamp, scene name, playtime)
- [ ] UI for save/load:
  - [ ] Save menu (slot selection, auto-save indicator)
  - [ ] Load menu (slot list with metadata preview)

### 4.5 Visual Presentation

- [ ] Background system:
  - [ ] Load background images from story data
  - [ ] Transition animations (fade, slide)
  - [ ] Fallback gradient/solid color if image missing
- [ ] Character sprite system:
  - [ ] Load character sprites from story data
  - [ ] Position sprites on screen (left, center, right)
  - [ ] Expression variants (happy, sad, suspicious, etc.)
  - [ ] Fade in/out animations
- [ ] Dialogue presentation:
  - [ ] Nameplate with NPC name
  - [ ] Dialogue box with typewriter text effect
  - [ ] "Continue" prompt (click or key press)
  - [ ] Choice button styling
- [ ] Transition effects:
  - [ ] Scene transition (fade to black, crossfade)
  - [ ] Chapter/section title cards

### 4.6 Test Story

- [ ] Design a ~30 minute test story:
  - [ ] 3–4 locations
  - [ ] 4–6 NPCs with distinct personalities
  - [ ] 8–12 clues with tiered revelation
  - [ ] 3–4 endings (good, neutral, bad)
  - [ ] Inventory items with meaningful use
  - [ ] Trust system affecting NPC cooperation
- [ ] Hand-craft story JSON:
  - [ ] All scenes, dialogue, choices, transitions
  - [ ] Clue definitions with tiers
  - [ ] Item definitions
  - [ ] Ending definitions
  - [ ] Trust change triggers
- [ ] Full playthrough testing:
  - [ ] Verify all scenes are reachable
  - [ ] Verify all endings are achievable
  - [ ] Verify clue progression works correctly
  - [ ] Verify inventory and trust systems interact properly
  - [ ] Verify save/load preserves full state
  - [ ] Time the full playthrough (~30 minutes target)

### 4.7 Verification

- [ ] Inventory items can be obtained, held, and offered
- [ ] Trust levels change based on story triggers
- [ ] Trust gates tiered clue revelation correctly
- [ ] Endings evaluate correctly based on game state
- [ ] Save/load preserves full game state
- [ ] Visual presentation displays backgrounds, sprites, dialogue
- [ ] Test story completes successfully through all paths

## Acceptance Criteria

- [ ] Inventory system works end-to-end (obtain → hold → offer → use)
- [ ] Trust tracking updates correctly and gates clue tiers
- [ ] Ending evaluation identifies correct ending based on game state
- [ ] Save/load preserves and restores complete game state
- [ ] Visual presentation shows backgrounds, character sprites, and dialogue
- [ ] Test story is complete and playable (~30 minutes, all paths tested)
- [ ] Full pipeline validated: input → parser → dialogue → validator → state update

## Dependencies

- Step 1 (Engine Core Setup) completed
- Step 2 (LLM Integration) completed
- Step 3 (Clue System) completed

## Notes

- Create the test story early in this phase and iterate on it throughout — it validates everything
- Abstract architecture discussions cannot replace the insights from actually playing through a branching narrative
- The test story's JSON will serve as a reference for the story editor's export format
- Consider recording a playthrough video for documentation and sharing
