# Adult Deck Event Cards – Implementation Analysis

**Scope:** Adult deck event cards (AD_01 … AD_81) in `7b92b3_EventEngine.lua`.  
**Reference:** CARD_TYPE mapping, TYPES definitions, and handleSpecial / resolveDiceByValue in EventEngine.

---

## Summary

| Status | Card count | Description |
|--------|------------|-------------|
| **Fully implemented** | **58** | Playable with full rules and effects. |
| **Partially implemented** | **0** | *(None; AD_VOUCH_PROP gives token, EstateEngine uses it.)* |
| **Not implemented / placeholder** | **23** | Card is playable but has no real effect (TODO / choice only). |

Total adult event cards: **81**.

*Updates: AD_WORKBONUS (3) = 4× salary WIN; AD_VOUCH_PROP (2) = event gives property voucher token, estate applies 20% discount.*

---

## Fully implemented (55 cards)

These are recognized, cost AP/money where required, and resolve with the intended effect.

| Type key | Card range | Count | Effect summary |
|----------|------------|-------|----------------|
| **AD_SICK_O** | AD_01–05 | 5 | Obligatory: −3 Health, add SICK status. |
| **AD_VOUCH_CONS** | AD_06–09 | 4 | Keep: 25% discount Consumables. |
| **AD_VOUCH_HI** | AD_10–11 | 2 | Keep: 25% discount Hi-Tech. |
| **AD_LUXTAX_O** | AD_12–13 | 2 | Obligatory: pay 200 WIN per owned hi-tech (0 if none). |
| **AD_PROPTAX_O** | AD_14–15 | 2 | Obligatory: pay 300×apartment level (L0=0); if can’t pay, added to Costs Calculator. |
| **AD_DATE** | AD_16–20 | 5 | 2 AP; +2 SAT (or +4 if married); add DATING status; narrative message. |
| **AD_CHILD100_O** | AD_21–23 | 3 | Obligatory, dice: 100 WIN cost; 3–6 = child (gender by roll), 1–2 = no child; child cost to calculator. |
| **AD_CHILD150_O** | AD_24–26 | 3 | Same with 150 WIN. |
| **AD_CHILD200_O** | AD_27–29 | 3 | Same with 200 WIN. |
| **AD_HI_FAIL_O** | AD_30–31 | 2 | Obligatory: one random owned hi-tech “broken”; repair 25% cost or skip; choice on card. |
| **AD_MARRIAGE** | AD_35–41 | 7 | 4 AP, −500 WIN; requires DATING; +2 SAT; marriage token; DATING removed; others: attend (2 AP INACTIVE), +2 SAT and pay 200 only if they can afford. |
| **AD_VOUCH_PROP** | AD_42–43 | 2 | Keep: add 1× property voucher token (20%); EstateEngine applies discount on property purchase. |
| **AD_WORKBONUS** | AD_32–34 | 3 | 1 AP; +4× salary WIN (salary = vocation WIN/AP); no token. |
| **AD_KARMA** | AD_44–46 | 3 | 1 AP; add GOOD_KARMA status; instant discard. |
| **AD_SPORT** | AD_48–50 | 3 | 1 AP, −100 WIN; dice: 1–2 lost, 3–4 draw, 5–6 win; SAT by result; narrative in DICE_RESULT_UI. |
| **AD_BABYSITTER50** | AD_51–52 | 2 | Choice: pay 50 or 100 WIN to unlock 1 or 2 child-blocked AP this round; AP moved INACTIVE→START. |
| **AD_BABYSITTER70** | AD_53–54 | 2 | Same with 70 / 140 WIN. |
| **AD_AUNTY_O** | AD_55–57 | 3 | Obligatory, dice: money and/or unlock 1–2 child-blocked AP this round (AD_AUNTY_D6). |

**Total fully implemented:** 53 + AD_VOUCH_PROP (2) + AD_WORKBONUS (3) = **58** cards.

---

## Partially implemented (0 cards)

*(None. AD_VOUCH_PROP event card adds the property voucher token; EstateEngine applies 20% discount when buying property.)*

---

## Not implemented / placeholder only (23 cards)

### 1. AD_AUCTION_O (1 card: AD_47)

- **Defined as:** `special="AD_AUCTION_SCHEDULE"`.  
- **Current behaviour:** Placeholder message: “Auction: not implemented yet — no effect. (Design pending.)”; card finishes with no effect.  
- **Missing:** No design yet — it was never specified what this card should do (e.g. schedule an auction, bid on a property, trigger a property event).  
- **Location:** `handleSpecial` → `def.special == "AD_AUCTION_SCHEDULE"`.

### 2. AD_VE (Vocation Experience) cards (24 cards: AD_58–81)

- **Defined as:** `todo=true`, `ve={a="...", b="..."}` (e.g. NGO2/SOC1, NGO1/GAN1, …).  
- **Current behaviour:**  
  - Card shows choice of two options (A or B) via `startChoiceOnCard_AB(..., "VE_PICK_SIDE", ...)`.  
  - `evt_choiceA` / `evt_choiceB` for `VE_PICK_SIDE`: only broadcast `"VE: wybrano A (TODO)."` / `"VE: wybrano B (TODO)."` and call `finishChoice`.  
  - No stats, SAT, money, vocation, or any other game effect.  
- **Missing:**  
  - Definition of what “picking A” vs “B” does (e.g. which vocation path, experience, or bonus).  
  - Any integration with vocation/experience system (e.g. VocationsController, stats, or future “VE” tracking).  
- **Location:** `handleSpecial` (`def.todo and def.ve`), `evt_choiceA` / `evt_choiceB` for `VE_PICK_SIDE`.

**VE card pairs (12 types × 2 cards = 24):**  
AD_VE_NGO2_SOC1, AD_VE_NGO1_GAN1, AD_VE_NGO1_ENT1, AD_VE_NGO2_CEL1, AD_VE_SOC2_CEL1, AD_VE_SOC1_PUB1, AD_VE_GAN1_PUB2, AD_VE_ENT1_PUB1, AD_VE_CEL2_PUB2, AD_VE_CEL2_GAN2, AD_VE_ENT2_GAN2, AD_VE_ENT2_SOC2.

---

## Per-card quick reference (by AD_ number)

| AD_ range | Type | Status |
|-----------|------|--------|
| 01–05 | AD_SICK_O | Fully implemented |
| 06–09 | AD_VOUCH_CONS | Fully implemented |
| 10–11 | AD_VOUCH_HI | Fully implemented |
| 12–13 | AD_LUXTAX_O | Fully implemented |
| 14–15 | AD_PROPTAX_O | Fully implemented |
| 16–20 | AD_DATE | Fully implemented |
| 21–23 | AD_CHILD100_O | Fully implemented |
| 24–26 | AD_CHILD150_O | Fully implemented |
| 27–29 | AD_CHILD200_O | Fully implemented |
| 30–31 | AD_HI_FAIL_O | Fully implemented |
| 32–34 | AD_WORKBONUS | Fully implemented (4× salary WIN) |
| 35–41 | AD_MARRIAGE | Fully implemented |
| 42–43 | AD_VOUCH_PROP | Fully implemented (voucher token; estate discount) |
| 44–46 | AD_KARMA | Fully implemented |
| 47 | AD_AUCTION_O | Not implemented (no design yet) |
| 48–50 | AD_SPORT | Fully implemented |
| 51–52 | AD_BABYSITTER50 | Fully implemented |
| 53–54 | AD_BABYSITTER70 | Fully implemented |
| 55–57 | AD_AUNTY_O | Fully implemented |
| 58–81 | AD_VE_* (12 pairs) | Not implemented (choice only, no effect) |

---

## Recommended next steps (priority)

1. **AD_VE (24 cards)**  
   - Define effect of “A” vs “B” per card (e.g. vocation path, experience, small stat/SAT bonus).  
   - In `evt_choiceA` / `evt_choiceB` for `VE_PICK_SIDE`, apply that effect (and optionally store choice for future use).

2. **AD_AUCTION_O (1 card)**  
   - **Design first:** Decide what the card should do (e.g. schedule an auction, bid on a property, one-time property opportunity).  
   - Then implement the flow (schedule, bids, resolution) or keep the current “not implemented” placeholder.

---

**Generated from:** `7b92b3_EventEngine.lua` (CARD_TYPE, TYPES, handleSpecial, resolveDiceByValue, evt_choiceA/B) and existing EVENT_CARDS_STATUS_REPORT.md.
