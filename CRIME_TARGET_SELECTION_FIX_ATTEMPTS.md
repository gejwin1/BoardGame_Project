# Crime Target Selection Error – Documentation of Fix Attempts

**Purpose:** Record all approaches tried to fix the "attempt to call a nil value" error when selecting a crime target. For use by assistants, consultants, and future work—to avoid repeating failed strategies and to understand what was tried and why.

---

## 1. Error Overview

### When It Happens
- Player chooses **Crime** on a Vocational Event card
- Player selects a target (e.g. Yellow) from the target-selection overlay
- The game attempts to start the dice roll for the crime
- **Script error occurs** before or during the dice roll

### Exact Error Message
```text
Error in Script (Vocations Controller - 37f7a7) function <call/VECrimeTargetSelected>: chunk_4:(1259,18-1268,6): attempt to call a nil value
```

- **Script:** Vocations Controller (object GUID `37f7a7`), script `VocationsController.lua`
- **Reported entry point:** `VECrimeTargetSelected` (via `.call`)
- **Location:** `chunk_4`, lines 1259–1268 (TTS compiles large scripts into chunks)
- **Type:** `attempt to call a nil value` — something that should be a function is `nil` at call time

### Last Diagnostic Log Before Crash
```text
[CRIME_DIAG] VECrimeTargetSelected calling rollDieForPlayer color=Blue
```

So the failure occurs **during or immediately after** `rollDieForPlayer` is invoked.

---

## 2. Flow (Call Chain)

Understanding the flow helps see where cross-chunk or cross-object calls can fail.

```
1. User clicks Crime on VE card
   → EventsController / EventEngine starts crime flow

2. StartVECrimeTargetSelection (VocationsController)
   → startTargetSelection with callback="VECrimeTargetSelected"
   → Shows target buttons (Yellow, Blue, Red, Green)

3. User clicks target button (e.g. Yellow)
   → Global script calls voc.call("handleTargetSelection", "Yellow")

4. handleTargetSelection (VocationsController)
   → Detects callback == "VECrimeTargetSelected"
   → Does NOT call VECrimeTargetSelected directly (chunk-safe decision)
   → engine.call("VECrimeTargetSelected", params)  -- forwards to Event Engine

5. VECrimeTargetSelected (Event Engine, 7b92b3)
   → Validates params, lockCard, etc.
   → rollDieForPlayer(data.color, "evt_crime", callback)

6. rollDieForPlayer (Event Engine)
   → voc.call("VOC_CanUseEntrepreneurReroll", { color })
   → If Entrepreneur L2: voc.call("VOC_RollDieForPlayer", { ... })
   → Else: rollRealDieAsync(...)

7. Error reported in Vocations Controller
   → Suggests crash happens when Event Engine calls BACK into VocationsController
   → Either in VOC_CanUseEntrepreneurReroll, VOC_RollDieForPlayer,
     or in functions they call (e.g. getSciencePointsForColor, getActiveTurnColor, findTurnController)
```

---

## 3. Root Cause Hypothesis: TTS Script Chunking

Tabletop Simulator compiles large Lua scripts into multiple chunks. **Local** functions and variables are **not visible across chunks**. So:

- A function defined in chunk 1 may be `nil` when referenced from chunk 4
- Cross-object calls (e.g. Event Engine → VocationsController) run in the target object’s script, so chunk visibility is per-object
- A callback or async path can run in a different chunk than the caller

**Implication:** Any function or variable that might be called from a different chunk must be:

1. Exposed via `_G` (or a global table like `_G.VOC_CTRL`), or  
2. Passed explicitly through parameters, or  
3. Wrapped in `pcall` with fallbacks so `nil` calls do not crash

---

## 4. Fix Attempts (Chronological / Logical Order)

### Attempt 1: Forward VECrimeTargetSelected to Event Engine (Don’t Call Locally)

**Idea:** VocationsController should not call `VECrimeTargetSelected` directly, because that function lives on the Event Engine. Calling it locally could hit a chunk where it is `nil`.

**Change:**
- In `handleTargetSelection`, when `callback == "VECrimeTargetSelected"`:
  - Do **not** call `VECrimeTargetSelected(params)` locally
  - Instead: `engine.call("VECrimeTargetSelected", params)` where `engine = getObjectFromGUID("7b92b3")`

**Result:** Error persists. The crash is still in Vocations Controller, so the failure happens when the Event Engine calls **back** into VocationsController (e.g. `VOC_CanUseEntrepreneurReroll`, `getSciencePointsForColor`), not in the initial forward.

---

### Attempt 2: Chunk-Safe `getActiveTurnColor` in VOC_CanUseEntrepreneurReroll

**Idea:** `VOC_CanUseEntrepreneurReroll` uses `getActiveTurnColor()`, which may be `nil` in the chunk where it runs.

**Change:**
- Look up via `_G.VOC_CTRL`:
  ```lua
  local gac = (type(getActiveTurnColor) == "function" and getActiveTurnColor)
    or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.getActiveTurnColor) == "function" and _G.VOC_CTRL.getActiveTurnColor)
  local activeTurn = (type(gac) == "function" and gac()) or nil
  ```
- Register: `_G.VOC_CTRL.getActiveTurnColor = getActiveTurnColor`

**Result:** Error persists. The crash may not be in `VOC_CanUseEntrepreneurReroll` itself; or `getActiveTurnColor` is not the failing call.

---

### Attempt 3: Chunk-Safe `getSciencePointsForColor` and `findTurnController`

**Idea:** The crash is in `getSciencePointsForColor` (lines 1259–1268). That function uses `findTurnController()`, which is defined much later in the file (line ~8212) and might be `nil` in chunk 4.

**Change:**
- Use `_G.VOC_CTRL.findTurnController` as fallback:
  ```lua
  local findFn = (type(findTurnController) == "function" and findTurnController)
    or (type(_G.VOC_CTRL) == "table" and type(_G.VOC_CTRL.findTurnController) == "function" and _G.VOC_CTRL.findTurnController)
  local turnCtrl = (type(findFn) == "function" and findFn()) or nil
  ```
- Register: `_G.VOC_CTRL.findTurnController = findTurnController` after `findTurnController` is defined

**Result:** Error may persist if `findTurnController` is never registered in `_G.VOC_CTRL` before `getSciencePointsForColor` runs (e.g. load order / chunk order).

---

### Attempt 4: Wrap `getSciencePointsForColor` in `pcall`

**Idea:** Regardless of the exact nil source, catch any error so the game doesn’t crash.

**Change:**
- Wrap the body of `getSciencePointsForColor` in `pcall`:
  ```lua
  function getSciencePointsForColor(color)
    local ok, points = pcall(function()
      -- ... full implementation ...
    end)
    if ok and type(points) == "number" then return points end
    log("getSciencePointsForColor: pcall error " .. tostring(points))
    return 0
  end
  ```
- Add `type(findFn) == "function"` guard before `findFn()`
- Add `type(turnCtrl.call) == "function"` guard before `turnCtrl.call(...)`

**Result:** Designed to make the function fail-safe. If the crash is inside this function, it should now return 0 instead of erroring.

---

### Attempt 5: Chunk-Safe Lookups in Event Engine

**Idea:** Crime logic in Event Engine uses `CARD_TYPE` and `VE_CRIME_TABLE`, which may be in later chunks.

**Change:**
- In `evt_veCrime`, `processCrimeRollResult`, `evt_veTarget`, `evt_veCrimeRoll`:
  - Use fallbacks: `(type(CARD_TYPE)=="table" and CARD_TYPE) or (type(_G.WLB_EVT)=="table" and _G.WLB_EVT.CARD_TYPE)`
  - Same for `VE_CRIME_TABLE`
- Register: `_G.WLB_EVT.CARD_TYPE = CARD_TYPE`, `_G.WLB_EVT.VE_CRIME_TABLE = VE_CRIME_TABLE`

**Result:** Reduces risk of nil lookups in Event Engine; does not directly fix the Vocations Controller crash.

---

### Attempt 6: Diagnostic Logging

**Idea:** Pinpoint exactly where the crash occurs.

**Change:**
- Add `[CRIME_DIAG]` logs in:
  - `VOC_CanUseEntrepreneurReroll` (ENTER/EXIT)
  - `getSciencePointsForColor` (ENTER/EXIT)
  - `rollDieForPlayer` (ENTER, voc, VOC_CanUseEntrepreneurReroll result)
  - `VECrimeTargetSelected` (before calling rollDieForPlayer)

**Result:** Logs show `[CRIME_DIAG] VECrimeTargetSelected calling rollDieForPlayer` as the last message before the error, so the failure is during/after that call—likely in `VOC_CanUseEntrepreneurReroll` or in something it invokes.

---

## 5. Consultant's Fix (2026-02-16 – Full Globalization)

**Root cause:** In chunk_4, `getSciencePointsForColor` calls `normalizeColor`, `getTurnCtrl`, and `log` — but these were **local functions** defined in other chunks. In TTS chunking, locals from one chunk are **nil** in another chunk → "attempt to call a nil value".

**Fix applied (consultant's exact steps):**

1. **Globalize constants:** `TAG_TURN_CTRL` and `COLORS` — changed from `local` to global so functions in any chunk can use them.

2. **Globalize helper functions:** Removed `local` from:
   - `log`
   - `warn`
   - `normalizeColor`
   - `getTurnCtrl` (via `_G.getTurnCtrl` at top + `getTurnCtrl = _G.getTurnCtrl`)
   - `getSciencePointsForColor` (was already global)

3. **Simplify `getSciencePointsForColor`:** Uses `getTurnCtrl()` and `normalizeColor()` directly; full body in `pcall`; returns 0 on any error (no log calls inside pcall to avoid nil).

4. **onLoad verification:** Added `print("[VOC_CTRL] PATCH LOADED 2026-02-16 A")` to confirm TTS loads the new script.

## 6. Current Mitigations (As of Last Edit)

| Location | Mitigation |
|----------|------------|
| `handleTargetSelection` | Forwards `VECrimeTargetSelected` to Event Engine via `engine.call()`, never calls it locally |
| `VOC_CanUseEntrepreneurReroll` | Chunk-safe lookup for `getActiveTurnColor` via `_G.VOC_CTRL.getActiveTurnColor` |
| `VOC_RollDieForPlayer` | Same chunk-safe `getActiveTurnColor` in callback |
| `getTurnCtrl` | **Global function** (not local) — visible in all chunks |
| `getSciencePointsForColor` | Uses global `getTurnCtrl()` directly; full body wrapped in `pcall` |
| Event Engine crime helpers | `CARD_TYPE` and `VE_CRIME_TABLE` exposed in `_G.WLB_EVT` with fallbacks |

---

## 7. What Might Still Be Wrong

1. **Chunk load order:** `findTurnController` is defined around line 8212. If the chunk that defines it loads after the chunk that defines `getSciencePointsForColor`, `_G.VOC_CTRL.findTurnController` may still be unset when the crime flow first runs.

2. **Different nil call:** The crash might not be in `getSciencePointsForColor` but in another function invoked from the same call chain (e.g. `normalizeColor`, `log`, or a helper used by `VOC_CanUseEntrepreneurReroll`).

3. **Cross-object context:** When Event Engine calls `voc.call("VOC_CanUseEntrepreneurReroll", ...)`, execution runs in VocationsController’s script. Chunk boundaries are per script, so the failing chunk is in VocationsController, but the exact line/chunk mapping can be non-obvious.

4. **Async/callback context:** If the crash happens inside a callback (e.g. from `Wait.condition` or `rollPhysicalDieAndRead`), the chunk/scope might differ from the synchronous path.

---

## 8. Recommendations for Next Steps

1. **Confirm resolution:** Re-test the crime flow with the latest changes. If the error persists, check logs for which `[CRIME_DIAG]` message is last.

2. **Ensure `_G.VOC_CTRL` registration order:** Register `findTurnController` (and other chunk-critical helpers) as early as possible—e.g. in `onLoad` or in the first chunk—so they exist before any crime flow runs.

3. **Consider moving crime die logic:** If chunking keeps causing issues, consider moving the crime dice roll logic into the Event Engine (which already has `rollRealDieAsync`) and minimize callbacks into VocationsController during the roll.

4. **Reference existing pattern:** The Events Controller vocational crash was addressed with a `WLB_EVT` global namespace and early-defined helpers. See `EVENTS_CTRL_VOCATIONAL_ERROR_SUMMARY.md` for the same “chunk-safe global” pattern.

---

## 9. Related Files

| File | Role |
|------|------|
| `scripts/object-scripts/VocationsController.lua` | Target selection, `handleTargetSelection`, `VECrimeTargetSelected` passthrough, `VOC_CanUseEntrepreneurReroll`, `getSciencePointsForColor`, `findTurnController` |
| `scripts/object-scripts/7b92b3_EventEngine.lua` | `VECrimeTargetSelected`, `rollDieForPlayer`, `processCrimeRollResult`, `CARD_TYPE`, `VE_CRIME_TABLE` |
| `scripts/object-scripts/Global_Script_Complete.lua` | UI target buttons call `voc.call("handleTargetSelection", color)` |
| `scripts/object-scripts/1339d3_EventsController.lua` | Starts crime flow, delegates to Event Engine |
| `EVENTS_CTRL_VOCATIONAL_ERROR_SUMMARY.md` | Similar TTS chunking fix pattern for Events Controller |

---

## 10. Revert / Undo

To remove the crime-related fixes:

1. **VocationsController:** Revert changes to `handleTargetSelection`, `VECrimeTargetSelected`, `VOC_CanUseEntrepreneurReroll`, `VOC_RollDieForPlayer`, `getSciencePointsForColor`, `findTurnController` registration, and remove `[CRIME_DIAG]` logs.
2. **Event Engine:** Revert `_G.WLB_EVT` fallbacks for `CARD_TYPE` and `VE_CRIME_TABLE` in crime-related functions.
3. **`_G.VOC_CTRL`:** Remove registrations for `getActiveTurnColor`, `getSciencePointsForColor`, `findTurnController`.

Use git history to recover prior versions of these functions if needed.
