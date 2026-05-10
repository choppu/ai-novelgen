# Development Plans

Detailed plan files for each step in the LLM-Powered Visual Novel Engine project.

## Overview

```
plans/
├── README.md                 ← You are here
├── 01-engine-setup.md        ← Phase 1, Iteration 1 (Week 1–2)
├── 02-llm-integration.md     ← Phase 1, Iteration 2 (Week 3–6)
├── 03-clue-system.md         ← Phase 1, Iteration 3 (Week 7–8)
├── 04-engine-polish.md       ← Phase 1, Iteration 4 (Week 9–12)
├── 05-story-editor.md        ← Phase 2, Iteration 5 (Week 13+)
└── 06-quality-tier-and-launch.md ← Phase 2, Iteration 6 (Week 13+)
```

## Phase 1: Engine Core

Build the game engine first. The story editor produces data that the engine consumes — you need to define the data format before building a tool that generates it.

| Step | Plan | Timeline | Status |
|------|------|----------|--------|
| 1 | [Engine Setup](01-engine-setup.md) | Week 1–2 | ⬜ Not started |
| 2 | [LLM Integration](02-llm-integration.md) | Week 3–6 | ⬜ Not started |
| 3 | [Clue System](03-clue-system.md) | Week 7–8 | ⬜ Not started |
| 4 | [Engine Polish](04-engine-polish.md) | Week 9–12 | ⬜ Not started |

## Phase 2: Story Editor + Launch

Build the authoring tool after the engine's data format is stable.

| Step | Plan | Timeline | Status |
|------|------|----------|--------|
| 5 | [Story Editor](05-story-editor.md) | Week 13+ | ⬜ Not started |
| 6 | [Quality Tier + Launch](06-quality-tier-and-launch.md) | Week 13+ | ⬜ Not started |

## Dependencies

```
01-engine-setup
       ↓
02-llm-integration
       ↓
03-clue-system
       ↓
04-engine-polish
       ↓
05-story-editor  ──→  06-quality-tier-and-launch
```

## Key Principles (from BRAINSTORMING.md)

1. **LLM is a delivery mechanism, not the source of truth.** Engine owns all game state.
2. **Never trust LLM output for game logic.** Always validate against engine-computed state.
3. **Prompt is your interface.** Quality depends on prompt engineering, not model size alone.
4. **Data format first.** Define engine JSON format early — everything downstream depends on it.
5. **Iterate on a real story.** Hand-craft a small test story early to validate the pipeline.
