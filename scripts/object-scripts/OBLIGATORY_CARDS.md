# Obligatory Cards – What They Are and How They Are Identified

This document describes **which event cards are treated as obligatory** in the codebase, how they are **localized/identified** in the game (card IDs, naming), and how they are **recognized when the player plays the card** (click → modal → Good Karma option).  

**Important:** Obligatory cards can exist **only** among the **YD_** (Youth) and **AD_** (Adult) deck prefixes; there are no obligatory cards in other decks.

---

## 1. What kind of cards are obligatory?

**Obligatory cards can only come from decks with prefixes `YD_` (Youth) and `AD_` (Adult).** There are no obligatory cards in other decks (e.g. CS_, HS_, IS_, JOB_).

A card is **obligatory** if either:

- Its **type definition** in Event Engine has `kind = "obligatory"`, or  
- Its **card ID** (first word of name or description) ends with `_O` and is recognised by the engine.

In practice, only **YD_** and **AD_** card IDs are mapped to obligatory types in the engine. The **source of truth** is `7b92b3_EventEngine.lua`: table `TYPES` and map `CARD_TYPE`.

### 1.1 Youth deck – obligatory types

| Type key   | Card IDs (examples)        | Effect / note                          |
|-----------|----------------------------|----------------------------------------|
| **SICK_O**   | `YD_31_SICK_O` … `YD_35_SICK_O`   | Health −2 (stats)                      |
| **LOAN_O**   | `YD_36_LOAN_O`, `YD_37_LOAN_O`    | Choice: pay or lose SAT                |

### 1.2 Adult deck – obligatory types

| Type key          | Card ID pattern (examples)              | Effect / note                          |
|-------------------|----------------------------------------|----------------------------------------|
| **AD_SICK_O**     | `AD_01_SICK_O` … `AD_05_SICK_O` (or `_SICK_0`) | Health −3, add SICK status             |
| **AD_LUXTAX_O**   | `AD_12_LUXTAX_O`, `AD_13_LUXTAX_O`      | Luxury tax special                     |
| **AD_PROPTAX_O**  | `AD_14_PROPTAX_O`, `AD_15_PROPTAX_O`    | Property tax special                   |
| **AD_CHILD100_O** | `AD_21_CHILD100_O` … `AD_23_CHILD100_O` | Child cost 100, dice                   |
| **AD_CHILD150_O** | `AD_24_CHILD150_O` … `AD_26_CHILD150_O` | Child cost 150, dice                   |
| **AD_CHILD200_O** | `AD_27_CHILD200_O` … `AD_29_CHILD200_O` | Child cost 200, dice                   |
| **AD_HI_FAIL_O**  | `AD_30_HI_FAIL_O`, `AD_31_HI_FAIL_O`    | Hi‑tech failure special                |
| **AD_AUCTION_O**  | `AD_47_AUCTION_O`                       | Auction schedule special               |
| **AD_AUNTY_O**    | `AD_55_AUNTY_O` … `AD_57_AUNTY_O`       | Aunty dice special                     |

So: **obligatory cards** are those that map (via `CARD_TYPE`) to one of these type keys, and in `TYPES` that key has `kind = "obligatory"`. The engine also treats any recognised card ID ending with `_O` as obligatory (fallback in `isObligatoryCard`).

---

## 2. How are obligatory cards localised / identified in the game?

Identification is done by **card ID**, not by in-game text (e.g. “You get sick”). The card ID is a **single token** (first word) that must appear in the card’s **name** or **description** in TTS.

### 2.1 Where the ID must appear

- **Preferred:** First word of the card’s **name** (e.g. `YD_31_SICK_O`).
- **Fallback:** First word of the card’s **description** (if the first word of the name is not a valid ID).

So for “You get sick” to be treated as obligatory, the card’s name (or description) must start with an ID that the engine maps to `SICK_O`, e.g. `YD_31_SICK_O`. If the first word is “You” or “Sick”, the engine will **not** recognise it as obligatory.

### 2.2 Valid ID prefixes (for obligatory: only YD_ and AD_)

**For obligatory cards, only these prefixes apply:** `YD_` (Youth deck) and `AD_` (Adult deck). No obligatory cards exist in other decks (CS_, HS_, IS_, JOB_).

The Event Engine’s general ID recognition uses more prefixes, but **obligatory types are defined only for YD_ and AD_**. So the first word of name or description for an obligatory card must be a script ID like `YD_31_SICK_O` or `AD_47_AUCTION_O`, not the human-readable title.

### 2.3 Mapping: card ID → obligatory

- **CARD_TYPE** maps concrete card IDs (e.g. `YD_31_SICK_O`) to a **type key** (e.g. `SICK_O`).
- **TYPES[typeKey]** has `kind = "obligatory"` for all obligatory types listed in section 1.
- **Fallback:** If the ID is not in `CARD_TYPE` but ends with `_O` and passes the prefix check, the engine still treats it as obligatory.

**Practical rule for localisation:**  
Keep the **script ID as the first word** of the card’s name (or description). You can localise the rest of the name/description; only the first token is used for type/obligatory detection.

---

## 3. How are they identified when the player plays the card?

When the player **clicks** an event card on the track, the following happens. Identification of “is this obligatory?” happens **before** any modal text is changed.

### 3.1 Click handling

1. **Events Controller** (`1339d3_EventsController.lua`):  
   `evt_onCardClicked(card, player_color)` is triggered.  
   It calls `uiOpenModal(card, player_color)`.

2. **Inside `uiOpenModal`** (order matters):
   - **First:** Compute `effectiveColor` (turn player or clicker).
   - **Then:** Call `isCardObligatory(card)` and `hasGoodKarma(effectiveColor)` **before** changing the card’s description.
   - **After that:** Call `uiSetTrackDescription(card)` (tooltip etc.), then show the appropriate modal.

So obligatory (and Good Karma) are decided **before** the card’s description is overwritten; otherwise the engine might lose the card ID if it was only in the description.

### 3.2 How “obligatory” is decided (Event Engine)

Events Controller calls:

- `isCardObligatory(card)`  
  which uses `card.getGUID()` and calls the **Event Engine**:
  - `engine.call("isObligatoryCard", { card_guid = cardGuid })`

Event Engine (`isObligatoryCard` in `7b92b3_EventEngine.lua`):

1. Gets the card object by GUID: `getObjectFromGUID(guid)`.
2. Gets **card ID** via `extractCardId(cardObj)`:
   - First word of **name**; if it matches a known prefix (`YD_`, `AD_`, etc.), use it as `cardId`.
   - Otherwise first word of **description**; if it matches a known prefix, use it as `cardId`.
   - Otherwise `nil`.
3. Looks up `typeKey = CARD_TYPE[cardId]`, then `def = TYPES[typeKey]`.
4. Returns:
   - `true` if `def.kind == "obligatory"`, or  
   - `true` if `cardId` ends with `_O` (and was recognised above),  
   - otherwise `false`.

So at play time, the card is identified **only** by:

- **GUID** (to get the card object), then  
- **First word of name, or first word of description** (must be a script ID with a valid prefix), then  
- **CARD_TYPE** and **TYPES** in the Event Engine.

No other localisation or card text is used for obligatory detection.

### 3.3 What the player sees

- If the card is **obligatory** and the current player **has Good Karma**:  
  Modal: **“Use Good Karma to avoid results of this card?”** (YES = skip and consume token, NO = resolve normally).

- Otherwise:  
  Modal: **“Do you want to play this card?”** (normal YES/NO).

---

## 4. Summary table

| Question | Answer |
|----------|--------|
| **What cards are obligatory?** | Only **YD_** and **AD_** cards whose type has `kind = "obligatory"`: Youth SICK_O, LOAN_O; Adult AD_SICK_O, AD_LUXTAX_O, AD_PROPTAX_O, AD_CHILD100/150/200_O, AD_HI_FAIL_O, AD_AUCTION_O, AD_AUNTY_O. Plus any recognised YD_/AD_ ID ending with `_O`. |
| **How are they localised/identified in the game?** | By **card ID**: first word of the card’s **name** (or, if needed, **description**) must be the script ID (e.g. `YD_31_SICK_O`). **Obligatory cards exist only with prefixes `YD_` and `AD_`.** Rest of name/description can be localised. |
| **How are they identified when the player plays the card?** | On click, Events Controller opens the modal and **before** changing the card’s description calls Event Engine `isObligatoryCard(card_guid)`. The engine gets the card by GUID, then uses `extractCardId` (first word of name, else description) → `CARD_TYPE` → `TYPES`. If `kind == "obligatory"` or ID ends with `_O`, the card is obligatory and (if the player has Good Karma) the “Use Good Karma?” modal is shown. |

---

## 5. References in code

- **Event Engine:** `7b92b3_EventEngine.lua`  
  - `PREFIXES`, `extractCardId`, `CARD_TYPE`, `TYPES`, `isObligatoryCard`.
- **Events Controller:** `1339d3_EventsController.lua`  
  - `uiOpenModal`, `isCardObligatory`, `hasGoodKarma`, `evt_onCardClicked`, `evt_onUseKarma`.
- **Good Karma flow:** `GOOD_KARMA_MECHANICS.md`.
