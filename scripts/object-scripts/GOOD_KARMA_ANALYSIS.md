# Good Karma Not Working – Analysis (No Code Changes)

You asked for a clear diagnosis of why the Good Karma / obligatory flow still does not work: the player never sees “Use Good Karma to avoid results of this card?” and cards are always resolved the same way, with or without a Good Karma token. Below is an analysis based only on reading the code. **No code has been changed.**

---

## How the flow is supposed to work

1. Player clicks an event card on the track.
2. **Events Controller** `evt_onCardClicked(card, player_color)` runs → calls `uiOpenModal(card, player_color)`.
3. Inside **`uiOpenModal`**:
   - Compute `effectiveColor` (turn player or clicker).
   - **Before** changing the card’s description, call:
     - `isCardObligatory(card)` → asks Event Engine if this card is obligatory.
     - `hasGoodKarma(effectiveColor)` → asks PlayerStatusController/TokenEngine if this player has Good Karma.
   - If **both** are true → set `showKarmaChoice = true` → call `uiAttachKarmaChoice_MODAL(card)` (“Use Good Karma to avoid results?” + YES/NO).
   - Otherwise → call `uiAttachYesNo_MODAL(card)` (“Do you want to play this card?” + YES/NO).
4. So the karma question appears **only if** both checks are true. If either is false, the player only sees the normal Yes/No modal and can never choose Good Karma.

So “no sign of Good Karma option” means: **the condition that sets `showKarmaChoice = true` is never satisfied.** One or more of the following must be failing.

---

## Exact condition in code

In `1339d3_EventsController.lua`, inside `uiOpenModal` (around lines 724–735):

```lua
if effectiveColor and effectiveColor ~= "" and type(isCardObligatory) == "function" and type(hasGoodKarma) == "function" then
  local ok1, obligatory = pcall(function() return isCardObligatory(card) end)
  local ok2, hasKarma = pcall(function() return hasGoodKarma(effectiveColor) end)
  ...
  if ok1 and obligatory == true and ok2 and hasKarma == true then
    showKarmaChoice = true
  end
end
```

So **all** of the following must be true for the karma modal to show:

1. **`effectiveColor`** is non-nil and non-empty.
2. **`isCardObligatory`** is a function (not nil).
3. **`hasGoodKarma`** is a function (not nil).
4. **`isCardObligatory(card)`** returns `true` (and `ok1` is true).
5. **`hasGoodKarma(effectiveColor)`** returns `true` (and `ok2` is true).

If **any** of 1–5 fails, you always get the normal “Do you want to play this card?” and no Good Karma option. So the reason Good Karma “doesn’t work” is that at least one of these five fails in your runs. Below is what can cause each one.

---

## Possible reasons (in order of likelihood)

### 1. **Obligatory is never detected – card ID not in name/description (most likely)**

**What happens:** `isCardObligatory(card)` calls the Event Engine’s `isObligatoryCard({ card_guid })`. The engine gets the card by GUID, then gets a **card ID** with `extractCardId(cardObj)`:

- First word of the card’s **name** (`card.getName()`).
- If that doesn’t match a known prefix (`YD_`, `AD_`, etc.), first word of the card’s **description** (`card.getDescription()`).
- If neither matches → `extractCardId` returns **nil** → `isObligatoryCard` returns **false**.

So **obligatory is only recognised if the first word of the card’s name or description in TTS is a script ID** like `YD_31_SICK_O` or `AD_47_AUCTION_O`. If your cards have:

- Name: “You get sick” / “Chorujesz” / “Sick” etc.
- and the description does **not** start with that ID either,

then the first word is **not** a valid ID, so `extractCardId` is nil and **every** card is treated as non‑obligatory. Then `showKarmaChoice` is never set, and you never see the Good Karma question – regardless of whether the player has a Good Karma token.

**How to confirm:** In TTS, pick an obligatory card (e.g. “You get sick”), select it, and check:

- First word of **Name** (e.g. in the object’s name field).
- First word of **Description** (e.g. in the object’s description field).

If neither is something like `YD_31_SICK_O`, that’s the reason. The code has no other way to know the card is obligatory.

---

### 2. **Good Karma check always false**

Even if the card is obligatory, the karma modal only shows when **`hasGoodKarma(effectiveColor)`** is true. That can fail if:

- **PlayerStatusController (PSC) not found:** `getPSC()` returns nil (no object with tag `WLB_PLAYER_STATUS_CTRL`), so `hasGoodKarma` returns false.
- **Color mismatch:** `effectiveColor` is e.g. `"Yellow"` but TokenEngine stores `"yellow"` (or the other way around). The controller normalises to “Yellow” (first letter upper, rest lower); if PSC/TokenEngine expect a different format, the lookup can fail.
- **TokenEngine state:** Good Karma was never added for that colour via PSC (e.g. never used the “+ Good Karma” test button, or never played a KARMA card that adds the token through the normal flow). Then `HAS_STATUS` for Good Karma is false.

So even with correct card IDs, if PSC is missing or the token isn’t in TokenEngine for that player, you’ll only ever see the normal modal.

---

### 3. **`effectiveColor` is empty**

`effectiveColor` is:

- `Turns.turn_color` if set and non-empty,
- else `uiState.modalColor[g]` (stored clicker when modal was opened),
- else `clickerColor` (argument to `uiOpenModal`).

If **Turns** is nil or not set (e.g. Turn Controller not loaded or not setting a global), and for some reason the click doesn’t pass the player colour correctly (e.g. second parameter to the button’s click function is wrong or missing), then `effectiveColor` can be nil/empty. Then the whole `if effectiveColor and effectiveColor ~= "" ...` block is skipped and the karma logic never runs.

---

### 4. **`isCardObligatory` or `hasGoodKarma` is nil when `uiOpenModal` runs**

The condition explicitly requires:

- `type(isCardObligatory) == "function"`
- `type(hasGoodKarma) == "function"`

So if either is **nil** (e.g. not defined in the scope where `uiOpenModal` runs), the inner block is skipped and we never call them. In a single script file, both are defined as locals later in the same file, so normally they are in scope when any function in that script runs. The only plausible way they’d be nil is if **TTS compiles this script in multiple chunks** and the chunk that defines `uiOpenModal` does not share the same scope as the chunk that defines `isCardObligatory` and `hasGoodKarma`. Then in the chunk that runs `uiOpenModal`, those names could be nil. The comment in `playCardFromUI` (“TTS can compile large scripts into multiple chunks”) suggests this is possible. If that’s the case, the guard would always fail and the karma branch would never run.

---

### 5. **Event Engine not found**

`isCardObligatory(card)` uses `getEngine()` (object with GUID `EVENT_ENGINE_GUID`). If that object doesn’t exist or isn’t found, `getEngine()` is nil and `isCardObligatory` returns false. Then obligatory is never true, so no karma modal. Less likely if the rest of the game (playing cards, etc.) works, but still a possibility if the engine object is missing or GUID is wrong.

---

## Summary: what is the reason?

**The most likely single reason** is **(1) card identity:**  
The event cards in your table **do not have the script ID as the first word of the name or description**. So the engine never recognises them as obligatory, `isCardObligatory(card)` is always false, and the Good Karma branch is never taken. That matches “no option to use Good Karma” and “doesn’t matter if the player has the token or not.”

Other possible contributors (alone or together):

- **(2)** PSC missing, wrong colour format, or Good Karma never in TokenEngine for that player.
- **(3)** `effectiveColor` empty (Turns / clicker not set).
- **(4)** In a multi‑chunk TTS build, `isCardObligatory` or `hasGoodKarma` is nil in the chunk that runs `uiOpenModal`.
- **(5)** Event Engine object not found.

I am **not** 100% certain which of these is true in your setup without running the game or seeing logs. I have **not** implemented any fix; the above are the only ways the current code can behave as you describe. To be sure, you’d need to either:

- Inspect card names/descriptions in TTS (for 1),
- Add temporary prints in `uiOpenModal` (effectiveColor, type(isCardObligatory), type(hasGoodKarma), result of isCardObligatory(card), result of hasGoodKarma(effectiveColor)), or
- Confirm in TTS whether the script is split into chunks and whether those helpers are in the same scope as `uiOpenModal`.

Once you know which of 1–5 fails, the fix is targeted (e.g. fix card IDs, or ensure PSC/TokenEngine/colour/turn, or ensure the same chunk defines and uses the helpers). I will not propose a “fake” change without knowing which of these is actually failing.
