# Good Karma – Intended Game Mechanics (How It Should Work)

This document describes **how the Good Karma + obligatory card system is designed to work**: which component asks which, when the question appears, and what gets resolved. It does not debug why it might fail; it only explains the intended flow.

---

## Project standard: source of truth for all status tokens

- **Status = TokenEngine state**, queried and updated **only via PlayerStatusController** (PSC).
- **No scanning the table** for physical tokens by tag (e.g. `WLB_STATUS_*` + `WLB_COLOR_*`). Status tokens do **not** receive color tags; logic must not rely on them.
- **All HAS_STATUS / GET_STATUS_COUNT / ADD_STATUS / REMOVE_STATUS / REMOVE_STATUS_COUNT** go through **PSC → TokenEngine**. Controllers (Events, Shop, Estate, Turn, etc.) call `PS_Event` with the appropriate `op`; they never infer status from object tags.
- The physical token on the board is only a **visual representation**; the authoritative state is in TokenEngine.

---

## 1. When Does the System Decide to Ask?

**Trigger:** The player **clicks an event card** on the track (any slot 1–7).

- **Who handles the click:** **Events Controller** (`1339d3_EventsController.lua`).
- **Function:** `evt_onCardClicked(card, player_color)`.
  - `card` = the card object that was clicked.
  - `player_color` = the **clicker’s** color (TTS passes the clicking player’s seat color).
- **What happens next:** The controller calls `uiOpenModal(card, player_color)` → the card is lifted and a **modal** (question + buttons) is shown on the card.

So the **only** place that can show “Use Good Karma?” is **when the modal is opened**, inside `uiOpenModal`, **before** any “Do you want to play this card?” is shown.

---

## 2. Who Decides “Obligatory + Good Karma” and What They Ask

**Where:** Inside **Events Controller** → `uiOpenModal(card, clickerColor)`.

**Current player:** The controller does **not** use “who owns the card”. It uses:

- **Primary:** `Turns.turn_color` (the active turn’s player), if it exists and is non‑empty.
- **Fallback:** `clickerColor` (the person who clicked the card).

So the “current player” for the karma check is: **turn player, or else the clicker**.

**Two checks (both must be true to show the karma question):**

### 2.1 Is this card obligatory?

- **Who is asked:** **Event Engine** (`7b92b3_EventEngine.lua`).
- **How:** Events Controller calls `isCardObligatory(card)` → that calls  
  `engine.call("isObligatoryCard", { card_guid = card.getGUID() })` on the Event Engine object.
- **What the Event Engine does:**
  1. Gets the card object by GUID.
  2. Gets a **card ID** via `extractCardId(cardObj)`:
     - Reads the **first word** of the card’s **name** (`card.getName()`).
     - If that doesn’t match known prefixes (YD_, AD_, etc.), reads the **first word** of the card’s **description** (`card.getDescription()`).
  3. Looks up that ID in `CARD_TYPE` (e.g. `"YD_31_SICK_O"` → `"SICK_O"`).
  4. Looks up the type in `TYPES` (e.g. `SICK_O` has `kind = "obligatory"`).
  5. Returns `true` if `def.kind == "obligatory"` (or if the card ID ends with `_O`).
- **So:** “You get sick” is only recognised as obligatory if the card’s **name or description** starts with an ID that maps to `SICK_O` (e.g. `YD_31_SICK_O`). If the first word is something like “You” or “Sick”, the engine will **not** recognise it and will return **false**.

### 2.2 Does the current player have a Good Karma token?

- **Who is asked:** **Player Status Controller** (`PlayerStatusController.lua`), which then asks **Token Engine** (`61766c_TokenEngine.lua`).
- **How:** Events Controller calls `hasGoodKarma(playerColor)` → that finds the object with tag `WLB_PLAYER_STATUS_CTRL` and calls  
  `psc.call("PS_Event", { color = normalizedColor, op = "HAS_STATUS", statusTag = "WLB_STATUS_GOOD_KARMA" })`.
- **What Player Status Controller does:** Forwards to Token Engine: `TE_HasStatus(color, "WLB_STATUS_GOOD_KARMA")`.
- **What Token Engine does:** Looks in its **internal state** for that color: `ensureStatuses(color).active["WLB_STATUS_GOOD_KARMA"]`. If that entry exists (and for multi‑status, has at least one token), it returns **true**; otherwise **false**.
- **Important:** The answer depends **only** on Token Engine’s **in‑memory state** (the statuses it has recorded for that player). It does **not** scan the table for physical tokens. So the Good Karma token must have been **added through the normal flow** (e.g. KARMA card → Event Engine → PS_Event ADD_STATUS → Token Engine TE_AddStatus), or via the Player Status Controller test button “+ Good Karma”, so that Token Engine’s state actually has that status for that color.

**If both checks are true:** Events Controller sets `uiState.karmaChoice[cardGuid] = true` and calls `uiAttachKarmaChoice_MODAL(card)`.

**If either check is false:** Events Controller calls `uiAttachYesNo_MODAL(card)` (normal “Do you want to play this card?”).

---

## 3. What the Player Sees on the Card

- **Karma modal (obligatory + Good Karma):**
  - Text: **“Use Good Karma to avoid results of this card?”**
  - **YES** = use Good Karma (skip the card, consume one token).
  - **NO** = do **not** use Good Karma; resolve the card as usual (e.g. lose 2 health for “You get sick”).

- **Normal modal (all other cases):**
  - Text: **“Do you want to play this card?”**
  - **YES** = resolve the card (e.g. lose 2 health).
  - **NO** = cancel; card is not played, stays on the track.

---

## 4. What Happens When the Player Clicks YES (Use Good Karma)

- **Where:** Events Controller → `evt_onYes` sees `uiState.karmaChoice[cardGuid]` set → calls `evt_onUseKarma(card, player_color, alt_click)`.
- **What `evt_onUseKarma` does:**
  1. Confirms the player still has Good Karma (same `hasGoodKarma` via Player Status Controller / Token Engine).
  2. **Removes one Good Karma token:** Calls Player Status Controller  
     `PS_Event({ color, op = "REMOVE_STATUS", statusTag = "WLB_STATUS_GOOD_KARMA" })` → Token Engine removes one token from that player’s state and recycles the physical token.
  3. Clears the card from the track slot in the controller’s state.
  4. Moves the card to the **used** pile (`teleportToUsed`).
  5. **Does not** call the Event Engine to resolve the card.

**Result:** The obligatory card is discarded to used, one Good Karma token is consumed, and **no** card effects are applied (no health loss, no sickness, etc.).

---

## 5. What Happens When the Player Clicks NO (Resolve as Usual)

- **Where:** Events Controller → `evt_onNo` sees `uiState.karmaChoice[cardGuid]` set → clears that flag and calls `evt_onYes(card, player_color, alt_click)`.
- **What happens:** `evt_onYes` runs the **normal resolution path**: it closes the modal, gets the slot index, and calls the **Event Engine** `playCardFromUI({ card_guid, player_color, slot_idx, slot_extra_ap })`. The Event Engine resolves the card (e.g. SICK_O: apply stats, health −2, etc.).

**Result:** The card is resolved normally; Good Karma token is **not** removed.

---

## 6. Summary: Who Asks Whom

| Question | Asked by | Asked of | Source of truth |
|----------|----------|----------|------------------|
| Is this card obligatory? | Events Controller | Event Engine (`isObligatoryCard`) | Event Engine: card GUID → name/description → first word → CARD_TYPE → TYPES[].kind |
| Does this player have Good Karma? | Events Controller | Player Status Controller (`PS_Event` HAS_STATUS) → Token Engine (`TE_HasStatus`) | Token Engine **internal state** for that color (`s.active["WLB_STATUS_GOOD_KARMA"]`) |

**When the question is asked:** Once, when the player clicks the card and the Events Controller opens the modal (`uiOpenModal`). There is no second ask later; if the karma modal was not shown at that moment, the only option the player will see is the normal “Do you want to play this card?”.

**Who resolves the card:** Only the **Event Engine** (when Events Controller calls `engine.call("playCardFromUI", ...)`). If the player used Good Karma, Events Controller never calls the Event Engine for that card; it only moves the card to used and removes the token.

---

## 7. Requirements for the Karma Question to Appear

1. **Event Engine** object must exist and be findable by GUID (`getEngine()` / `EVENT_ENGINE_GUID`).
2. **Player Status Controller** object must exist and have tag `WLB_PLAYER_STATUS_CTRL`.
3. **Token Engine** must have been primed and must have the Good Karma status **in its state** for the **current player** (the one used in the check: turn color or clicker).
4. **Card identity:** The card’s **name or description** must start with a script ID that Event Engine maps to an obligatory type (e.g. `YD_31_SICK_O` for “You get sick”). If the first word is not such an ID, the card will not be considered obligatory.
5. **Current player** must be set: either `Turns.turn_color` or the clicker’s color, and that color must be one Token Engine knows (e.g. Yellow, Blue, Red, Green).

If any of these fail, the controller will show the normal “Do you want to play this card?” modal instead of “Use Good Karma to avoid results of this card?”.
