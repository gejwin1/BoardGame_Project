# Award Tokens – Design Document

## Overview

New status token type **WLB_STATUS_AWARD** (with base tag **WLB_STATUS_TOKEN**) to track progress toward vocation awards at end of game. Most vocations need to gather specific achievements before they can receive their Level 3 award.

---

## Token Configuration

| Property | Value |
|----------|-------|
| **Tags** | `WLB_STATUS_TOKEN`, `WLB_STATUS_AWARD` |
| **Storage** | Same system as experience tokens (multi-copy, stackable) |
| **Purpose** | Count toward award conditions (typically need 2) |

---

## Per-Vocation Award Logic

### 1. Social Worker
- **Condition:** Successfully conduct 2 community events with at least 1 participant each.
- **Grant token when:** After each successful community event that had ≥1 participant.
- **Need:** 2 award tokens + K10, S10 (from VOCATION_DATA L3).
- **Where to grant:** In `resolveInteractionEffectsWithDie` for:
  - `SW_L1_PRACTICAL_WORKSHOP`
  - `SW_L2_COMMUNITY_SESSION`
  - `SW_L3_EXPOSE_CASE`
  
  Only grant if at least one *other* player joined (initiator does not count). I.e. `#participants > 1` (initiator + joiners, excluding initiator if they’re alone? Clarify: “at least one participant” = at least one *other* player joined, or initiator counts as participant? → Assume: at least one player besides initiator joined, i.e. `#participants > 1` or “anyone joined”).

### 2. Public Servant
- **Condition:** Successfully collect taxes 2 times at any level.
- **Grant token when:** After each successful tax collection (Income, Hi-Tech, Property campaigns).
- **Need:** 2 award tokens + K15, S7 (from VOCATION_DATA L3).
- **Where to grant:** In tax campaign resolution when tax was actually collected (participants paid, no full refusal).

### 3. NGO Worker
- **Condition:** Complete 2 social campaigns OR 1 social campaign + 10 AP voluntary work.
- **Grant token when:** After each completed social campaign (Charity L1, Crowdfunding L2, Advocacy L3).
- **Need:** 2 award tokens (path A) OR 1 award token + 10 AP voluntary work (path B) + K12, S10.
- **Where to grant:** In `resolveInteractionEffectsWithDie` for:
  - `NGO_L1_CHARITY`
  - `NGO_L2_CROWDFUND`
  - `NGO_L3_ADVOCACY`
- **Voluntary work path:** Track `voluntaryWorkAP[color]` (cumulative). At promotion check, accept: `(awardTokens >= 2)` OR `(awardTokens >= 1 AND voluntaryWorkAP >= 10)`.

### 4. Gangster
- **Condition:** Commit 2 crimes without getting caught.
- **Grant token when:** When investigation fails (gangster not caught).
- **Need:** 2 award tokens + K9, S13 (from VOCATION_DATA L3).
- **Where to grant:** In crime resolution / investigation result handler when result = “not caught” (investigation roll fails).
- **Note:** Heat/investigation system is automatic; token granted only when investigation does not catch the gangster. Only need 2 tokens (crimes not caught). Total crimes don't matter – e.g. 5 crimes with 2 not caught = 2 tokens, which is enough.

### 5. Celebrity
- **No award tokens.** Award = 10 AP work at Level 3 + pay 4,000 VIN.
- **Flow:**
  - Work AP at L3 is already tracked (`workAPThisLevel`).
  - When Celebrity is at L3 and `workAPThisLevel[color] >= 10`, show **“Get an award”** button in vocation summary.
  - On click: deduct 4,000 VIN, mark award as received (or trigger promotion-to-award flow).
- **Need:** K7, S15 + 10 AP work at L3 + 4,000 VIN.

### 6. Entrepreneur
- **No award tokens.** Condition = own L3 or L4 house + 2 hi-tech items.
- **Flow:** Check at promotion/award time (or end of game):
  - Housing level 3 or 4 (from EstateEngine / TokenEngine).
  - At least 2 hi-tech items owned (from ShopEngine).
- **No button.** Purely end-of-game / promotion check.

---

## Knowledge & Skills Requirements (from VOCATION_DATA)

| Vocation      | Level 3 Award        | Knowledge | Skills |
|---------------|----------------------|-----------|--------|
| Public Servant| 2 tax collections    | 15        | 7      |
| Celebrity     | 10 AP work + 4000 VIN| 7         | 15     |
| Social Worker | 2 community events   | 10        | 10     |
| NGO Worker    | 2 campaigns or 1+10AP| 12        | 10     |
| Entrepreneur  | L3/L4 house + 2 hi-tech | 9      | 13     |
| Gangster      | 2 crimes not caught  | 9         | 13     |

---

## Implementation Checklist

### TokenEngine
- [ ] Add `TAG_STATUS_AWARD = "WLB_STATUS_AWARD"` to status tags.
- [ ] Add to `STATUS_ORDER` and `MULTI_STATUS` (like experience tokens).
- [ ] Ensure bag has award tokens with tags `WLB_STATUS_TOKEN` + `WLB_STATUS_AWARD`.
- [ ] Add debug button `btnAddAward` (optional).

### PlayerStatusController
- [ ] Add `WLB_STATUS_AWARD` to status tag list (if needed for forwarding).

### VocationsController
- [ ] Add helper `addAwardToken(color)` – calls PSC/TokenEngine ADD_STATUS for WLB_STATUS_AWARD.
- [ ] Add `getAwardTokenCount(color)` – GET_STATUS_COUNT for WLB_STATUS_AWARD.
- [ ] Update `VOC_CanPromote` for `type == "award"`:
  - **Public Servant, Social Worker, Gangster:** require `awardTokens >= 2` + K/S.
  - **NGO Worker:** require `(awardTokens >= 2) OR (awardTokens >= 1 AND voluntaryWorkAP >= 10)` + K/S.
  - **Entrepreneur:** check L3/L4 house + 2 hi-tech (no tokens).
  - **Celebrity:** handled via “Get an award” button (work-based + 4000).

### Grant Award Tokens – integration points
- [ ] **Social Worker:** After successful community events with ≥1 participant.
- [ ] **Public Servant:** After successful tax collection.
- [ ] **NGO Worker:** After completed Charity, Crowdfunding, or Advocacy campaigns.
- [ ] **Gangster:** When investigation fails (not caught).

### Celebrity “Get an award” button
- [ ] In vocation summary, when Celebrity L3 and `workAPThisLevel >= 10`, show “Get an award” button.
- [ ] On click: check 4000 VIN, deduct, mark award received (new state or consume promotion check).

### Entrepreneur award check
- [ ] Add `checkEntrepreneurAwardCondition(color)` – housing L3/L4 + 2 hi-tech.
- [ ] Use in `VOC_CanPromote` for Entrepreneur L3.

### NGO voluntary work tracking
- [ ] Add `state.voluntaryWorkAP[color]` – increment when NGO uses Voluntary Work action.
- [ ] Use in award condition for NGO L3.

---

## Clarifications (confirmed)

1. **Social Worker “participant”:** Does “at least one participant” mean at least one *other* player joined (i.e. excluding initiator), or initiator alone counts? → Suggest: at least one other player joined (`#participants > 1`).
2. **Gangster “3 with one caught”:** Should we support the alternative path (3 crimes with 1 caught)? If yes, need to track “crimes caught” and allow award when `(notCaught >= 2) OR (totalCrimes >= 3 AND caught <= 1)`.
3. **Celebrity award vs promotion:** Is the Celebrity L3 “award” separate from promotion (i.e. you promote to L3 first, then later “get award” by doing 10 more AP + 4000)? Or is promotion to L3 itself the award (10 AP at L2 + 4000)? Design assumes: at L3, do 10 AP work, then click “Get an award” and pay 4000.
