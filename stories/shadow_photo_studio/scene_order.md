# Scene Order — Shadow Photo Studio

## Act 1 — Arrival & First Clues
1. `street_approach` — Walk down the street, see the studio
2. `studio_entrance` — Knock on the locked door, spot Obasan
3. `neighborhood_obasan` — First conversation with Obasan (gets key hint)
4. `return_studio_entrance` — Hub: return to studio entrance
5. `studio_enter` — Find the key under the pot, unlock the door
6. `studio_interior` — Enter studio, meet Haruka

## Act 2 — The Darkroom (all Haruka investigation happens here)
7. `darkroom` — Explore the darkroom, talk to Haruka about Yuki
   - **"Ask about the small locked box"** → `ending_darkroom_light` (early route, requires `knows_haruka_nightmares` + `knows_last_photo`)
   - **"Leave the darkroom"** → `return_studio_interior`
8. `return_studio_interior` — Return to main studio area
9. `return_studio_entrance` — Hub: exit to street (now can access cafe/Shinjuku)

## Act 3 — Kenji & The Journalist
10. `neighborhood_cafe` — Spot Café Renoir, see Kenji through window
11. `cafe_meeting` — Meet Kenji, learn about Shinjuku building
12. `return_cafe_meeting` — Return to Kenji for deeper conversation
13. `return_studio_entrance` — Hub: choose next destination

## Act 4 — Shinjuku Investigation
14. `shinjuku_arrival` — Take the train, arrive at the building
15. `shinjuku_lobby` — Enter the dim lobby, frozen security camera
16. `shinjuku_304` — Third floor, find Yuki's photograph on the floor
17. `shinjuku_desk` — Examine desk: Kuroda folder, ledger, camera
18. `shinjuku_cabinet` — Check filing cabinet: victim files, Yuki's file
19. `shinjuku_escape` — Footsteps approach — flee with evidence

## Act 5 — Resolution
20. `final_confrontation` — Return to studio with evidence, show Haruka what you found

## Endings (4 branches from final_confrontation + 1 shared early route)
- `ending_darkroom_light` — Haruka confesses, Yuki steps out of hiding (shared by darkroom early route AND final_confrontation)
  - Publish the evidence
  - Help Yuki disappear
  - Continue to Café Renoir (if player hasn't met Kenji yet)
- `ending_developed_truth` — Publish evidence with Kenji
- `ending_last_exposure` — Haruka destroys the last photograph
- `ending_fogged_film` — Close the case, accept Yuki vanished

## Hub Scenes (returnable crossroads)
- `return_studio_entrance` — Main hub; routes to Obasan, cafe, Shinjuku, or re-enter studio
- `return_studio_interior` — Studio hub; routes to darkroom or exit
- `neighborhood_obasan_return` — Obasan revisit (unlocks cafe option after meeting Haruka)

## Key Gating Chain (minimum path to all endings)
```
street_approach → studio_entrance → neighborhood_obasan → return_studio_entrance
  → studio_enter → studio_interior → darkroom → return_studio_interior
  → return_studio_entrance → neighborhood_cafe → cafe_meeting
  → shinjuku_arrival → shinjuku_lobby → shinjuku_304
  → shinjuku_desk + shinjuku_cabinet (order flexible)
  → shinjuku_escape → final_confrontation → [ending]
```

## Design Notes
- **`ending_darkroom_light` is a unified scene** reachable from two paths:
  - **Early route** (from darkroom): Player asks about the locked box → Haruka confesses → Yuki reveals himself → player can continue to find Kenji
  - **Full route** (from final_confrontation): Player returns with Shinjuku evidence → shows Haruka → opens darkroom door → same scene, same characters
- **No separate `ending_haruka_confession`** — it was the same ending as `ending_darkroom_light`, just split unnecessarily
- **The locked box** is visible in the darkroom from the first visit, giving the player a natural hook to ask about it
- **`final_confrontation`** is now about showing Haruka the Shinjuku evidence, not a monologue. The emotional beat is her reading Yuki's "DISAPPEAR" file.
