# Alternative / Rollback Scripts

This folder holds **previous known-good versions** of scripts to roll back to when fixing errors.

## Purpose

Use these files when you want to **revert** the main scripts to an earlier state and fix issues from that point, instead of debugging from the current (broken) state.

## Files (to be added)

| File | Description |
|------|-------------|
| `c9ee1a_TurnController.lua` | Turn Controller v2.9.2 — **saved** |
| `7b92b3_EventEngine.lua` | Event Engine — *pending (paste when ready)* |
| `EventEngine_Refactored.lua` | Event Engine z architekturą _G.WLB.EVT — **chunk-safe** (patrz EVENT_ENGINE_REFACTOR_PLAN.md) |
| `1339d3_EventsController.lua` | Events Controller — *pending (paste when ready)* |
| `VocationsController_Refactored.lua` | VocationsController z architekturą _G.WLB.VOC — **chunk-safe** (patrz VOCATIONS_CONTROLLER_REFACTOR_PLAN.md) |

## How to use

1. When all three files are in this folder, copy them **over** the corresponding files in `scripts/object-scripts/` (same filenames).
2. Or: open each file from here in the game object’s script in TTS and replace the content.
3. Test from this baseline; then re-apply or re-do fixes one at a time.

## Main scripts location

- `../object-scripts/c9ee1a_TurnController.lua`
- `../object-scripts/7b92b3_EventEngine.lua`
- `../object-scripts/1339d3_EventsController.lua`
