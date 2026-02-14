# SICK Status — Mechanics Documentation

This document describes how the **SICK** status (sickness) works in the game: how it is applied, where it is stored, which scripts control it, and how it is removed (including **automatic removal at the end of the current player’s turn**).

---

## 1. Overview

- **Tag:** `WLB_STATUS_SICK`
- **Meaning:** The player is “sick” for the rest of their current turn. It is a **one-turn status**: it is automatically removed when that player’s turn ends.
- **Source of truth:** The **Token Engine** holds which status tokens (including SICK) are on each player’s board. The **Player Status Controller** is the hub other scripts use to add/remove/query statuses; it forwards to the Token Engine.

---

## 2. How SICK Is Started (Applied)

### 2.1 Event cards (main source)

| Card type | Script | Effect |
|-----------|--------|--------|
| **Adult obligatory sick (AD_SICK_O)** | Event Engine (`7b92b3_EventEngine.lua`) | When the player resolves an Adult sick card (AD_01–AD_05, names like `AD_XX_SICK_O` or `AD_XX_SICK_0`), the card applies **−3 Health** and **adds the SICK status token** via `statusAddTag = STATUS_TAG.SICK` → `PS_AddStatus(color, "WLB_STATUS_SICK")`. |
| **Youth obligatory sick (SICK_O)** | Event Engine | Youth sick cards (YD_31–YD_35) apply **−2 Health** only. They do **not** add the SICK status token; only the Adult sick cards add the token. |

So in practice, the **SICK token** is only added by **Adult** sick event cards. Youth sick cards only apply the health penalty.

### 2.2 Other ways SICK can be applied

- **Token Engine UI (debug):** The Token Engine object (`61766c_TokenEngine.lua`) has buttons **+SICK** / **−SICK** that add or remove the SICK token for the target color (for testing).
- **Player Status Controller:** Any script can add SICK by calling the Events Controller / Player Status Controller hub with `PS_Event({ color = "Yellow", op = "ADD_STATUS", statusTag = "WLB_STATUS_SICK" })` (or `statusKey = "SICK"` if the hub supports it). In practice, Event Engine uses `PS_AddStatus(color, STATUS_TAG.SICK)` after resolving an AD_SICK_O card.

---

## 3. Where SICK Is Maintained (Storage and Controllers)

### 3.1 Token Engine (storage and physical token)

- **Script:** `61766c_TokenEngine.lua` (object tag: `WLB_TOKEN_ENGINE` or `WLB_TOKEN_SYSTEM`)
- **Role:** Holds the actual state and places the physical SICK token on the player board.
- **Internal state:**  
  `STATUSES[color].active[TAG_STATUS_SICK]` = the token object for that player (or `nil` if not sick).  
  SICK is **not** in `MULTI_STATUS`, so at most **one** SICK token per player.
- **APIs used by others:**
  - `TE_AddStatus_ARGS({ color, statusTag })` — add SICK (takes token from pool, places on board).
  - `TE_RemoveStatus_ARGS({ color, statusTag })` — remove SICK (return token to pool, refresh board).
  - `TE_HasStatus_ARGS({ color, statusTag })` — returns whether the player has SICK.
  - `TE_GetStatusCount_ARGS({ color, statusTag })` — returns 0 or 1 for SICK.

The physical SICK token in TTS must have tags: `WLB_STATUS_TOKEN` and `WLB_STATUS_SICK`.

### 3.2 Player Status Controller (hub)

- **Script:** `PlayerStatusController.lua` (tag: `WLB_PLAYER_STATUS_CTRL`)
- **Role:** Single entry point for “status” operations. Event Engine, Shop Engine, and Turn Controller do **not** call the Token Engine directly for SICK; they call the Player Status Controller, which forwards to the Token Engine.
- **API:** `PS_Event(payload)` with e.g.:
  - `op = "ADD_STATUS"`, `statusTag = "WLB_STATUS_SICK"` (or `statusKey = "SICK"`) → add SICK.
  - `op = "REMOVE_STATUS"`, `statusTag = "WLB_STATUS_SICK"` → remove SICK.
  - `op = "HAS_STATUS"`, `statusTag = "WLB_STATUS_SICK"` → returns true/false.
  - `op = "GET_STATUS_COUNT"` → count (0 or 1 for SICK).

So: **SICK is “maintained” in the Token Engine; the Player Status Controller is the script that other systems use to read/update it.**

---

## 4. End of Turn: SICK Is Erased (Current Player’s Turn)

SICK is defined as a **one-turn** status: it lasts only until the **end of the current player’s turn**, then it is removed.

### 4.1 Where it is implemented

- **Script:** `c9ee1a_TurnController.lua` (Turn Controller)
- **Function:** `onTurnEnd_ExpireOneTurnStatuses(color)`
  - It calls the Token Engine (via `tokenCall`) to remove both **SICK** and **WOUNDED** for the given `color`:
    - `tokenCall("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_SICK })`
    - `tokenCall("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_WOUNDED })`

### 4.2 When it runs (end of current player’s turn)

`onTurnEnd_ExpireOneTurnStatuses(active)` is called with the **active** player (the one who just ended their turn) in **both** end-of-turn paths:

1. **Normal “Next Turn” (no AP left):**  
   `ui_nextTurn()` → gets `active` = current player → runs `endTurnProcessing(active)`, `finalizeAPAfterTurn(active)`, then **`onTurnEnd_ExpireOneTurnStatuses(active)`** → SICK (and WOUNDED) are removed for that player.

2. **Confirm “End turn anyway” (AP left):**  
   `ui_confirmEndTurnYes()` → same sequence with the same `active` → **`onTurnEnd_ExpireOneTurnStatuses(active)`** again removes SICK (and WOUNDED) for that player.

So **SICK is always erased at the end of the current player’s turn**, whether they end with or without unspent AP.

---

## 5. Other Ways SICK Can Be Removed (Before End of Turn)

- **Health Monitor (Hi-Tech):** Shop Engine (`d59e04_ShopEngine.lua`). If the player has SICK, they can use the Health Monitor once per turn: roll 1d6; on **3–6** the SICK status is removed (“cured”); on 1–2 it stays. Implemented via `pscRemoveStatus(color, TAG_STATUS_SICK)`.
- **Cure consumable:** Shop Engine. If the player has SICK (or WOUNDED), they use the Cure card and roll the die. On success, SICK (or WOUNDED) is removed and they gain +3 Health. Also uses `pscRemoveStatus(color, TAG_STATUS_SICK)`.
- **Token Engine debug:** **−SICK** button removes the token for the target color.
- **Turn Controller:** As above, automatic removal at end of that player’s turn via `onTurnEnd_ExpireOneTurnStatuses`.

---

## 6. Summary Table

| Aspect | Detail |
|--------|--------|
| **Tag** | `WLB_STATUS_SICK` |
| **Added by** | Adult sick event cards (AD_SICK_O), Token Engine debug +SICK, or any script via PSC `ADD_STATUS` |
| **Not added by** | Youth sick cards (they only apply −2 Health, no token) |
| **Stored in** | Token Engine: `STATUSES[color].active["WLB_STATUS_SICK"]` (one token per player max) |
| **Accessed via** | Player Status Controller: `PS_Event` with `ADD_STATUS` / `REMOVE_STATUS` / `HAS_STATUS` / `GET_STATUS_COUNT` |
| **Removed at end of turn?** | **Yes.** Turn Controller calls `onTurnEnd_ExpireOneTurnStatuses(active)` in both end-of-turn flows, which removes SICK (and WOUNDED) for the player who just ended their turn. |
| **Removed earlier by** | Health Monitor (roll 3–6), Cure consumable, Token Engine −SICK button |

---

## 7. Script / Object Reference

| Script | Object / tag | Role for SICK |
|--------|----------------|---------------|
| `61766c_TokenEngine.lua` | `WLB_TOKEN_ENGINE` / `WLB_TOKEN_SYSTEM` | Stores and places SICK token; implements `TE_AddStatus_ARGS`, `TE_RemoveStatus_ARGS`, `TE_HasStatus_ARGS`, etc. |
| `PlayerStatusController.lua` | `WLB_PLAYER_STATUS_CTRL` | Hub: `PS_Event(ADD_STATUS/REMOVE_STATUS/HAS_STATUS)` → forwards to Token Engine. |
| `7b92b3_EventEngine.lua` | Event Engine | Adds SICK when resolving Adult sick cards (AD_SICK_O) via `PS_AddStatus(color, STATUS_TAG.SICK)`. |
| `c9ee1a_TurnController.lua` | Turn Controller | Calls `onTurnEnd_ExpireOneTurnStatuses(active)` at end of turn → removes SICK (and WOUNDED) for the current player. |
| `d59e04_ShopEngine.lua` | Shop Engine | Health Monitor and Cure consumable can remove SICK via PSC (e.g. `pscRemoveStatus(color, TAG_STATUS_SICK)`). |

---

**Conclusion:** SICK is applied by Adult sick event cards (and optionally by debug or other scripts via the Player Status Controller). It is stored in the Token Engine and queried/updated through the Player Status Controller. It is **guaranteed to be erased at the end of the current player’s turn** by the Turn Controller’s `onTurnEnd_ExpireOneTurnStatuses(active)` in both end-of-turn code paths.
