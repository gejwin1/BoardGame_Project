# Events Controller – Vocational Event crash: summary for consultant

## 1. The error

**When it happens:** User clicks a Vocational Event card → modal "Do you want to play this card?" → user clicks **Yes** → game crashes.

**Exact message:**
```text
Error in Script (WLB EVENTS CTRL - 1339d3) function <call/playCardFromUI>: chunk_4:(875,2-42): attempt to call a nil value
```

- **Script:** `1339d3_EventsController.lua` (WLB EVENTS CTRL, GUID `1339d3`).
- **Reported function:** `playCardFromUI` (TTS shows this as the `<call/...>` entry point).
- **Real location:** Line **875**, columns 2–42, in **chunk_4** (TTS compiles this script into multiple chunks).
- **Cause:** Lua tries to **call** something that is **nil** (“attempt to call a nil value”).

**Observed behaviour:**

- Only **Vocational Event** cards trigger the crash when clicking Yes; other event cards do not. The code path is the same (evt_onYes → uiCloseModalSoft / uiCloseModal); the chunk_4 nil (e.g. `pcall`) is hit when that path runs. Fix: use a global `WLB_safeCall` defined in chunk 1 and guard all uses so chunk_4 never calls a nil.
- The same error has come back several times (user: “3rd or 4th time”) after earlier fixes.
- In one run there was also “Unknown card ID: AD_73_VE-ENT1-PUB1” (that ID was later added to the Event Engine mapping).

---

## 2. What we know from logs and flow

**From user’s console screenshots:**

1. **On game load** the message **`EVT CTRL loaded GUID=1339d3`** appears. So the **correct** Events Controller object (script `1339d3`) is loading.

2. **When the crash happens**, the diagnostic line **`EVT CTRL 1339d3 playCardFromUI v2 running`** does **not** appear. So:
   - The crash is **not** inside the `playCardFromUI` function body (that code never runs when user clicks Yes).
   - The real path is: user clicks **Yes** → button calls **`evt_onYes`** on the Events Controller (not `playCardFromUI`). So the failure is somewhere in **`evt_onYes`** or in functions it calls (e.g. `uiCloseModalSoft`). TTS still reports the error under “playCardFromUI” (likely due to how it names the call stack / entry).

3. **Line 875** in the current `1339d3_EventsController.lua` is inside **`uiCloseModal`** (or nearby **`uiCloseModalSoft`**), on the line that calls **`WLB_EVT.uiReturnHome(card)`**. So the nil call is almost certainly that helper (or another one on that line) when run from **chunk_4**.

4. **TTS chunking:** Tabletop Simulator compiles large Lua scripts into several “chunks”. **Local** functions and variables are not visible across chunks. So in the chunk where line 875 runs (chunk_4), something we expect to be a function (e.g. `WLB_EVT.uiReturnHome` or the original `uiReturnHome`) can be **nil**, which causes “attempt to call a nil value” even though the same name is defined elsewhere in the file.

**Flow when user clicks Yes on a Vocational Event:**

- Button `click_function = "evt_onYes"`, `function_owner = self` (Events Controller).
- So TTS runs **`evt_onYes(card, player_color, alt_click)`** on the Controller.
- `evt_onYes` does checks, then calls **`uiCloseModalSoft(card)`** (and later the Event Engine).
- Inside **`uiCloseModalSoft`** (or **`uiCloseModal`**) we call e.g. **`WLB_EVT.uiReturnHome(card)`**. In chunk_4 that reference can be nil → crash at line 875.

---

## 3. What was changed in the last seven steps (for revert)

All edits are in **`scripts/object-scripts/1339d3_EventsController.lua`**.

### Step 1 – Global namespace

- Near the top (after `local DEBUG = true`):  
  **Added:** `WLB_EVT = WLB_EVT or {}`  
- Purpose: One global table so helpers can be referenced from any TTS chunk.

### Step 2 – Publish helpers into WLB_EVT

- After `getSlotIndexForCardGuid()` and before `announceSlot1ObligatoryToCurrentTurn()`:  
  **Added:** A block assigning many local helpers to `WLB_EVT`, e.g.  
  `WLB_EVT.isCard = isCard`, `WLB_EVT.uiCloseModal = uiCloseModal`, `WLB_EVT.uiCloseModalSoft = uiCloseModalSoft`, `WLB_EVT.uiReturnHome = uiReturnHome`, `WLB_EVT.uiEnsureIdle = uiEnsureIdle`, plus: `isObjNearAnySlot`, `getSlotIndexForCardGuid`, `slot1HasObligatory`, `safeBroadcastTo`, `getEngine`, `canSpendExtraAP`, `spendExtraAP`, `log`, `warn`, `refreshTrackedSlots`, `refreshObligatoryLock`, `saveState`, `refreshEventSlotUI_later`, `refreshEventSlotUI`, `isCardObligatory`, `hasGoodKarma`, `uiOpenModal`, `getPSC`, `consumeGoodKarma`, `teleportToUsed`, `cardHasEngineModalUI`.  
- Purpose: So these functions are reachable via `WLB_EVT.*` in every chunk.

### Step 3 – evt_onYes uses only WLB_EVT and guards

- **Replaced** all direct helper calls in **`evt_onYes`** with **`WLB_EVT.xxx(...)`** and added checks like `if type(WLB_EVT) ~= "table" then return "ERROR" end`, `if type(WLB_EVT.isCard) ~= "function" then return "ERROR" end`, etc.  
- So: `isCard`, `isObjNearAnySlot`, `getSlotIndexForCardGuid`, `slot1HasObligatory`, `safeBroadcastTo`, `getEngine`, `uiCloseModal`, `uiCloseModalSoft`, `canSpendExtraAP`, `spendExtraAP`, `warn`, `log`, `uiEnsureIdle`, `refreshTrackedSlots`, `refreshObligatoryLock`, `saveState`, `refreshEventSlotUI_later` are all used only as `WLB_EVT.xxx` with type checks.

### Step 4 – uiCloseModal / uiCloseModalSoft use WLB_EVT and pcall

- **`uiCloseModal`:** Uses `WLB_EVT.isCard`, `WLB_EVT.uiReturnHome`, `WLB_EVT.uiEnsureIdle` with type checks.  
  **Wrapped** the calls to `WLB_EVT.uiReturnHome(card)` and `WLB_EVT.uiEnsureIdle(card)` in **`pcall(...)`** so a nil function does not crash the script.
- **`uiCloseModalSoft`:** Same idea: use `WLB_EVT.isCard` and `WLB_EVT.uiReturnHome`; **wrapped** `WLB_EVT.isCard(card)` and `card.getGUID()` in **pcall**; **wrapped** `WLB_EVT.uiReturnHome(card)` in **pcall**.

### Step 5 – evt_onCardClicked, evt_onNo, evt_onUseKarma

- **Replaced** direct helper use with **`WLB_EVT.xxx`** (and type checks where needed) in **`evt_onCardClicked`**, **`evt_onNo`**, **`evt_onUseKarma`**.

### Step 6 – playCardFromUI and onLoad

- **`playCardFromUI`:** Obligatory/karma branch and delegation to “Yes” now use **`WLB_EVT.isCardObligatory`**, **`WLB_EVT.hasGoodKarma`**, **`WLB_EVT.uiOpenModal`**, and **`WLB_EVT.evt_onYes`** (with fallback and type checks).  
- **`onLoad()`:** **Added** `WLB_EVT.evt_onYes = evt_onYes` (so it’s in the namespace even though it’s defined later in the file).

### Step 7 – Diagnostics and extra pcall

- **`onLoad()`:** **Added**  
  `broadcastToAll("EVT CTRL loaded GUID=" .. tostring(self.getGUID()), {1, 1, 1})`  
  (so we see which object actually loaded the script).
- **`playCardFromUI()`:** **Added** at start:  
  `broadcastToAll("EVT CTRL 1339d3 playCardFromUI v2 running", {1, 1, 1})`  
  and checkpoint broadcasts: A (cardGuid OK), B (got card object), C (before onYesFn with `type(WLB_EVT)`, `type(evt_onYes)`, `type(onYesFn)`).
- **pcall wrapping** in **`uiCloseModal`** and **`uiCloseModalSoft`** as in Step 4 (so any nil call there does not throw).

**Result:** Error still occurs (“no changes still the same error”). So either the failing call is not fully wrapped, or the nil happens in another line/chunk, or there is another copy of the script/object in use.

---

## 4. What the consultant might do

1. **Confirm the exact line 875** in the current `1339d3_EventsController.lua` (e.g. search for `uiReturnHome` / `uiCloseModal` / `uiCloseModalSoft`) and ensure **every** call that can be nil in chunk_4 is inside **pcall** or guarded by **type(…)== "function"** and never called if nil.

2. **Consider making critical helpers global** (e.g. `function uiReturnHome(card) ... end` at top level) so they are visible in all chunks, not only via `WLB_EVT`.

3. **Check for duplicate objects:** Ensure only one object with script 1339d3 is in the game and that the button “Yes” on the card uses that object as `function_owner`.

4. **Revert:** To undo the above, remove the `WLB_EVT` block and publish block, restore `evt_onYes` / `uiCloseModal` / `uiCloseModalSoft` / `evt_onCardClicked` / `evt_onNo` / `evt_onUseKarma` / `playCardFromUI` / `onLoad` to their previous versions (direct local/global helper calls, no WLB_EVT, no diagnostic broadcastToAll, no pcall wrapping). A version before these seven steps should be in git history or backup.

---

## 5. Consultant’s fix (WLB.EVT, chunk-safe helpers at top)

**Implemented after consultant’s note:**

- **Namespace:** At top of file: `WLB = WLB or {}`, `WLB.EVT = WLB.EVT or {}`, `WLB_EVT = WLB.EVT` (so existing `WLB_EVT.*` refs still work).
- **Critical helpers defined early (right after `uiState`):**  
  `WLB.EVT.isCard`, `WLB.EVT.uiReturnHome`, `WLB.EVT.uiCloseModalSoft`, `WLB.EVT.uiEnsureIdle`, `WLB.EVT.uiCloseModal` are defined as `WLB.EVT.xxx = function(...) ... end` so they live in the global table from load and are visible in every chunk. They use only `uiState`, config, and each other (no “local helper 1000 lines below”).
- **uiCloseModal / uiCloseModalSoft:** Replaced body with “thin wrapper”: only call `WLB.EVT.uiCloseModal(card)` / `WLB.EVT.uiCloseModalSoft(card)` after `type(WLB.EVT.uiCloseModal)` etc. check; if missing, `broadcastToAll("MISSING helper: ... in chunk", {1,0,0})` and return. No local helper calls in the close path.
- **Publish block:** Removed assignments for `isCard`, `uiReturnHome`, `uiCloseModal`, `uiCloseModalSoft`, `uiEnsureIdle` so the early `WLB.EVT` definitions are not overwritten by locals from the middle of the file.

---

## 6. Files involved

- **Events Controller (where the crash is):** `scripts/object-scripts/1339d3_EventsController.lua`
- **Event Engine (card logic, playCardFromUI called by Controller):** `scripts/object-scripts/7b92b3_EventEngine.lua`
- **Card ID mapping (e.g. AD_73_VE-ENT1-PUB1):** In `7b92b3_EventEngine.lua`, `CARD_TYPE["AD_73_VE-ENT1-PUB1"] = "AD_VE_ENT1_PUB1"` was added so that card is recognised.

If you want to revert only the “last seven steps” in the Events Controller, use the list in Section 3 and restore the previous logic for those functions and the two blocks (namespace + publish).
