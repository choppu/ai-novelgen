# Step 3: Clue System

**Phase:** 1 — Engine Core  
**Iteration:** 3 — Clue System  
**Timeline:** Week 7–8 (within Medium Term)

## Objective

Implement the full clue system including clue definitions, prerequisite checking, revelation tracking, and tiered clue revelation. The engine computes available clues per NPC per scene; the LLM weaves them into dialogue naturally.

## Deliverables

- Clue definitions in story JSON format
- Prerequisite checking engine
- Revelation tracking (known clues state)
- Available clue computation per NPC per scene
- Tiered clue revelation (trust-gated progressive disclosure)
- Integration with LLM dialogue generation and response validation

## Tasks

### 3.1 Clue Data Model

- [ ] Extend story JSON schema with clue definitions:
  - [ ] `clues` array:
    - [ ] `id` (string) — unique identifier
    - [ ] `description` (string) — internal description for prompt context
    - [ ] `keywords` (array of strings) — keywords for fallback detection
    - [ ] `tiers` (array of objects) — progressive disclosure levels
      - [ ] `tier` (number) — level 1, 2, 3, etc.
      - [ ] `text` (string) — what the NPC says at this tier
      - [ ] `requires_trust` (number) — minimum trust level with NPC
      - [ ] `requires_flags` (array of strings) — required game flags
    - [ ] `sources` (array of strings) — NPC IDs that can reveal this clue
    - [ ] `connections` (array of strings) — related clue IDs (for coverage tracking)
    - [ ] `is_red_herring` (boolean) — false lead, for coverage reports
- [ ] Update `GameState` to track:
  - [ ] `known_clues` (map of clue_id → tier level)
  - [ ] Highest tier revealed per clue

### 3.2 Prerequisite Evaluator

- [ ] Implement `CluePrerequisiteEvaluator` class:
  - [ ] `check_prerequisites(clue_id, tier, game_state)` → `bool`
  - [ ] Evaluate flag requirements
  - [ ] Evaluate trust/relationship requirements
  - [ ] Evaluate prerequisite clue requirements
  - [ ] Evaluate scene/scene_history requirements
- [ ] Implement `get_available_clues(npc_id, scene_id, game_state)` → `AvailableClue[]`
  - [ ] Filter clues by source NPC
  - [ ] Check each tier's prerequisites
  - [ ] Exclude already-revealed tiers
  - [ ] Return highest available unrevealed tier per clue

### 3.3 Revelation Tracking

- [ ] Implement `ClueTracker` class:
  - [ ] `reveal_clue(clue_id, tier)` — record clue revelation
  - [ ] `is_known(clue_id)` → `bool` — has player discovered this clue at any tier
  - [ ] `get_tier(clue_id)` → `int` — highest tier revealed
  - [ ] `get_all_known()` → `ClueRevelation[]` — full revelation state
  - [ ] `get_unrevealed_count()` → `int` — total unrevealed clues
- [ ] Integrate with response validator:
  - [ ] When LLM claims a clue revelation, validate against available set
  - [ ] If valid, record the revelation in `ClueTracker`
  - [ ] If invalid, reject and log

### 3.4 Tiered Revelation Integration

- [ ] Update dialogue generator prompt to include:
  - [ ] Available clues with their tier level
  - [ ] Guidance on progressive disclosure (don't reveal tier 3 if tier 1 is new)
  - [ ] Trust level context so LLM adjusts NPC willingness to share
- [ ] Update response validator to handle tiers:
  - [ ] Validate revealed tier doesn't exceed available tier
  - [ ] Prefer lower tiers if multiple are available (gradual revelation)

### 3.5 Keyword Detection Enhancement

- [ ] Extend keyword detection to handle tiered clues:
  - [ ] Different keywords per tier (if applicable)
  - [ ] Detect partial revelations vs. full revelations
- [ ] Add confidence scoring for keyword matches:
  - [ ] Exact phrase match = high confidence
  - [ ] Single keyword match = medium confidence
  - [ ] Multiple keyword matches in context = high confidence

### 3.6 Verification

- [ ] Create test story with tiered clues
- [ ] Verify prerequisite evaluation (flags, trust, prerequisite clues)
- [ ] Verify available clue computation per NPC per scene
- [ ] Verify revelation tracking (tier progression)
- [ ] Verify LLM receives correct available clues in prompt
- [ ] Verify response validator rejects invalid tier claims
- [ ] Verify keyword fallback detects tiered clue revelations

## Acceptance Criteria

- [ ] Clue definitions load from story JSON with full tier structure
- [ ] Prerequisite evaluator correctly checks flags, trust, and clue dependencies
- [ ] Available clue computation returns correct clues per NPC per scene
- [ ] Revelation tracking records and queries clue tiers accurately
- [ ] Tiered revelation enforces progressive disclosure
- [ ] LLM prompt includes correct available clues with tier guidance
- [ ] Response validator rejects clues not in available set or exceeding tier
- [ ] Keyword fallback detects clue revelations from dialogue text

## Dependencies

- Step 1 (Engine Core Setup) completed
- Step 2 (LLM Integration) completed

## Notes

- Clues are **author-defined entities** — the engine decides what's available, the LLM delivers it naturally
- Support **tiered clues** for gradual revelation (trust-gated progressive disclosure)
- **Keyword detection** in dialogue text serves as backup if LLM omits metadata
- The clue system should be testable independently of the LLM (use mock responses)
