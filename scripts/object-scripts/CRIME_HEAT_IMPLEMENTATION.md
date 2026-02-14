# Crime, Heat & Investigation – Implementation Summary

## GUIDs (for dev)

| Object        | GUID     | Tag / note              |
|---------------|----------|--------------------------|
| **Shops Board** | `2df5f1` | `WLB_SHOP_BOARD`        |
| **Police Car**  | `ffe844` | `WLB_POLICE`           |

Global uses `HEAT_POLICE_GUID = "ffe844"`. HeatPoliceCar uses `SHOP_BOARD_GUID = "2df5f1"` (fallback tag `WLB_SHOP_BOARD`) for board-relative movement.

---

## Handover summary (for dev)

1. **Root cause:** Police Car was set to Persistent in TTS, which duplicated the object across loads. Some duplicates had old/different scripts, so `SetHeat` was called on the wrong instance (“function is not a function”) and the visible pawn didn’t match. **Action:** All duplicates removed; one fresh Police Car (GUID `ffe844`). **Rule:** Persistent OFF; exactly one object with tag `WLB_POLICE`.

2. **+ / − buttons:** Buttons on the token are supported but were unreliable while duplicates existed (wrong instance scripted). Once there is a single token, +/− should work. Optional: use a separate HeatControl tile that calls `policeCar.call("SetHeat"/"AddHeat")` instead.

3. **LOCAL vs WORLD coordinates:** The 7 slot positions may be **local to the Shops Board** (so when the board moves/rotates, world positions break). Implemented: toggle **`USE_BOARD_LOCAL`** in `HeatPoliceCar.lua` — `true` = treat `HEAT_POS` as local and convert with `board.positionToWorld(localPos)`; `false` = treat as world. **Test:** Set `USE_BOARD_LOCAL = true`, Save & Play; then `false`. Whichever keeps the pawn on the printed track is correct. If LOCAL works, keep it; if WORLD works, board must not move.

4. **Current state:** One Police Car script pasted; pawn sits roughly at slot 4. Movement may be wrong until LOCAL vs WORLD is confirmed. +/− re-enabled once movement is stable.

5. **Final target:** One Police Car (tag `WLB_POLICE`). Heat 0–6 reflected by pawn position on Shops Board. Movement **board-relative** (local + `positionToWorld`). Heat only after **successful** crime.

6. **Immediate dev actions:** Ensure Persistent OFF; exactly one `WLB_POLICE`; identify Shops Board by GUID `2df5f1` (tag `WLB_SHOP_BOARD`); run LOCAL vs WORLD test; then lock mode and re-enable +/− if desired.

---

## Quick checklist (what you need to do in TTS)

1. **Police Car token** – **Exactly one** token. Tag: `WLB_POLICE`. Paste **`HeatPoliceCar.lua`** into that object’s **one** Script tab (no duplicate script boxes).
2. **Heat track positions** – In `HeatPoliceCar.lua`, replace the 7 `Vector(...)` entries in `HEAT_POS` with real world coordinates from your shop board (one position per heat level 0–6). Use a temporary cube in each slot and `print(self.getPosition())` to get coordinates.
3. **New game** – Heat is reset to 0 when a new game is started (Global finds the Police Car and calls `SetHeat(0)`). No extra step needed if you use the normal new game flow.

---

## If the Police Car disappeared or you had duplicates (SetHeat error)

**Why the error can happen:** If the Police Car had **multiple script boxes** or the token was **duplicated** (e.g. by accident with a persistent token), TTS may call `SetHeat` on an object that doesn’t have the real script. Only the **one** token that has `HeatPoliceCar.lua` should exist and be used.

**If the token disappeared** (e.g. after turning persistence off): In TTS, persistent objects are stored in the save; when you change persistence or reload, the token can vanish from the table. You need to **create a new Police Car** and set it up again.

### Steps to create or replace the Police Car (one token, one script)

1. **Spawn a new token** in TTS (e.g. from Objects → Models, or any small pawn/car you use as the “police car”). Put it on the shop board where the heat track is (rough position is enough; the script will move it to heat 0 on load).

2. **Script:** Right‑click the token → **Scripting** → **Script** tab.  
   - Delete any existing script content.  
   - Paste the **entire** contents of **`HeatPoliceCar.lua`** (and only that script).  
   - Ensure there is **only one** Script tab/box for this object (no duplicated scripts).  
   - Save (Ctrl+S).

3. **Tag:** In the same object’s **Tags** (or in Scripting), add the tag: **`WLB_POLICE`**.  
   - Make sure no **other** object has this tag (only this one Police Car).

4. **GUID:** Right‑click the token → **Scripting** → at the top you’ll see the object’s **GUID** (e.g. `901027` or a new one). Copy it.  
   - In **Global** script, set **`HEAT_POLICE_GUID = "your_new_guid_here"`** (in the config section at the top) so “Start new game” always targets this token.

5. **Heat positions:** If this is a new board or you never set positions, edit `HEAT_POS` in the Police Car script as in section “Heat track positions (HEAT_POS)” below.

6. **Persistence:** Avoid making this token **Persistent** if that was causing duplicates. Use a normal (non‑persistent) token so it stays part of the save as a single object.

After this, there should be **exactly one** Police Car, with **one** script, and the SetHeat error should stop once Global and VocationsController use that object (by GUID or tag).

---

## What Was Implemented

1. **Heat (global 0–6)** – Increases by +1 only after a **successful** crime (Gangster vocation or VE crime card). Failed crimes do not increase heat.

2. **Police Car token** – Script `HeatPoliceCar.lua` is intended to run **on the Police Car object** on your shop board. The token moves to positions 0–6 to show current heat.

3. **Investigation** – After every successful crime the **order** is: (1) Heat +1, (2) **New** investigation roll (a **separate** die roll – the crime die is never reused), (3) Punishment from the investigation result.
   - Heat +1 (and police pawn moves).
   - Investigation roll: **new physical roll** 1d6 + Investigation Modifier (modifier from heat: 0→+0, 1–2→+1, 3–4→+2, 5–6→+3). Callers must **not** pass the crime roll; the script rolls again.
   - Punishment from the **investigation** result only:
     - **0–2:** No evidence, case dismissed.
     - **3–4:** Official warning – pay 200 VIN, lose 1 Satisfaction.
     - **5–6:** Formal charge – pay 300×Vocation Level VIN, lose 2 SAT, lose 1 AP (moved to inactive **this turn**).
     - **7+:** Major conviction – pay 500×Vocation Level VIN, lose 4 SAT, lose 2 AP (moved to inactive **this turn**), **restitution** (stolen VIN returned to victim).

4. **Hooks** – Heat + Investigation run only when a **crime** is committed (not for vocation-specific/special actions):
   - **Gangster vocation crime** (VocationsController): after successful die result (partial or full success), Heat + Investigation run automatically.
   - **Vocational event cards** have **three options** each; only **one** of them is “commit crime on another player”. **Only that option** triggers Heat + Investigation. The other two options are **special/vocation-specific actions** and do **not** increase heat or trigger investigation.
   - When the player **does** choose “commit crime on another player” on a VE card, the crime roll (wounded or wounded_steal) then runs Heat +1, separate investigation roll, and punishment/restitution. That is wired in EventEngine via: processCrimeRollResult, evt_veTarget, and evt_veCrimeRoll (different UI paths for the same “commit crime” choice).

## What You Need To Do in TTS

### 1. Police Car object

- You must have **exactly one** Police Car token. It must have **exactly one** Script tab with **`HeatPoliceCar.lua`** (no duplicate scripts on the same object, no duplicate tokens with the same tag). See **“If the Police Car disappeared or you had duplicates”** above if the token is missing or you see SetHeat errors.
- Ensure the Police Car token on the shop board has **tag: `WLB_POLICE`** (and no other object has this tag).
- Paste the contents of **`HeatPoliceCar.lua`** into that object’s **Script** tab (replacing any existing script; delete duplicates).

### 2. Heat track positions (HEAT_POS) and LOCAL vs WORLD

In `HeatPoliceCar.lua`:

- **`USE_BOARD_LOCAL`** (default `true`): if `true`, `HEAT_POS` are **local to the Shops Board** and are converted with `board.positionToWorld()` so the pawn stays on the track when the board moves. If `false`, `HEAT_POS` are **world** coordinates (board must not move).
- **Run the toggle test:** With `USE_BOARD_LOCAL = true`, Save & Play and check if the pawn stays on the printed heat track. If it teleports away, set `USE_BOARD_LOCAL = false` and test again. Use whichever mode keeps the pawn aligned.

Replace the 7 vectors in `HEAT_POS` with your actual slot positions:

- **If using LOCAL:** Measure positions **relative to the Shops Board** (e.g. place a cube on the board in each slot and use the board’s local position for that cube).
- **If using WORLD:** Use world coordinates (e.g. `print(self.getPosition())` with a cube in each slot; optionally raise Y so the pawn doesn’t clip).

```lua
HEAT_POS = {
  [0] = Vector(..., ..., ...),  -- slot 0 (left)
  [1] = Vector(..., ..., ...),
  -- ... through ...
  [6] = Vector(..., ..., ...),  -- slot 6 (right)
}
```

Shops Board is found by **GUID `2df5f1`** (fallback: tag `WLB_SHOP_BOARD`).

### 3. Global script

- Punishment AP loss is applied **this turn** (move to INACTIVE now). Implementation uses `Global.call("WLB_GET_BLOCKED_INACTIVE", ...)` and `Global.call("WLB_SET_BLOCKED_INACTIVE", ...)` for “lose AP next turn”; your existing Global script already provides these.

### 4. New game / reset

- **Done in code:** When `WLB_NEW_GAME()` runs (e.g. from Global `/wlbn` or TurnController new game), Global finds the Police Car by **GUID** (see `HEAT_POLICE_GUID` in Global; current `ffe844`) and calls `SetHeat(0)`. If you replace the Police Car token, copy the new object’s GUID in TTS and set `HEAT_POLICE_GUID` in the Global script to that value.

## Files Touched

- **`HeatPoliceCar.lua`** – Police Car token script: heat state, movement (with LOCAL vs WORLD toggle via `USE_BOARD_LOCAL`, Shops Board GUID `2df5f1` / tag `WLB_SHOP_BOARD`), AddHeat, SetHeat, GetHeat, GetInvestigationModifier, save/load, +/− testing buttons.
- **`VocationsController.lua`** – `findHeatPawn()`, `RunCrimeInvestigation()` (punishment ladder), Gangster crime success hook.
- **`7b92b3_EventEngine.lua`** – VE crime success: set `crimeGainsVIN` and call `RunCrimeInvestigation` on VocationsController.
- **`Global_Script_Complete.lua`** – In `WLB_NEW_GAME()`, find Police Car by GUID `ffe844` (fallback: tag `WLB_POLICE`) and call `SetHeat(0)` to reset heat for a new game.

No separate “Crime Controller” object; heat lives on the Police Car, investigation and punishment in VocationsController.
