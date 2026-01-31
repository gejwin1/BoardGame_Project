
# Hi-Tech Cards - Implementation Plan

## 📋 Overview

**Total Cards:** 14  
**Card Type:** Hi-Tech (H)  
**Deck Tag:** `WLB_DECK_HSHOP`  
**Name Pattern:** `HSHOP_XX_*` (where XX = 01-14)

---

## 📱 Card List

| # | Card Name | Status | Cost (WIN) | Extra AP | Effect | Notes |
|---|-----------|--------|------------|----------|--------|-------|
| 1 | `HSHOP_01_COFFEE` | 📝 Documented | 1200 | 0 | Rest-equivalent +1 (permanent) | Same as PILLS rest bonus, but permanent |
| 2 | `HSHOP_02_COFFEE` | 📝 Documented | 1200 | 0 | Rest-equivalent +1 (permanent) | Same as HSHOP_01 |
| 3 | `HSHOP_03_COMPUTER` | 📝 Documented | 1100 | 0 | Spend 1 AP → +1 Knowledge (unlimited/turn) | Interactive card - needs UI button |
| 4 | `HSHOP_04_DEVICE` | 📝 Documented | 1100 | 0 | Spend 1 AP → +1 Skill (unlimited/turn) | Interactive card - needs UI button |
| 5 | `HSHOP_05_TV` | 📝 Documented | 1400 | 0 | Spend 1-4 AP → +1 SAT per AP (max 4 AP/turn) | Interactive card - needs UI button |
| 6 | `HSHOP_06_BABYMONITOR` | 📝 Documented | 1200 | 0 | -1 child AP block per baby (max 2 babies) | Reduces child-blocked AP permanently |
| 7 | `HSHOP_07_BABYMONITOR` | 📝 Documented | 1200 | 0 | -1 child AP block per baby (max 2 babies) | Same as HSHOP_06 |
| 8 | `HSHOP_08_HMONITOR` | 📝 Documented | 300 | 0 | SICK protection: roll die, 3-6 = auto-cure | Passive protection when SICK status added |
| 9 | `HSHOP_09_CAR` | 📝 Documented | 1200 | 0 | Shop/Estate entry free; Event cards -1 AP cost | Modifies costs in Shop Engine & Event Engine |
| 10 | `HSHOP_10_CAR` | 📝 Documented | 1200 | 0 | Shop/Estate entry free; Event cards -1 AP cost | Same as HSHOP_09 |
| 11 | `HSHOP_11_ALARM` | 📝 Documented | 700 | 0 | Items/cash protected from theft (not wounds) | Prevents certain event card effects |
| 12 | `HSHOP_12_SMARTPHONE` | 📝 Documented | 1000 | 0 | Once per turn: if ≥2 AP on Work/Learning → +1 SAT | End-of-turn check |
| 13 | `HSHOP_13_SMARTWATCH` | 📝 Documented | 700 | 0 | Each turn: -1 INACTIVE AP (except child-blocked) | Uses child AP tracking system |
| 14 | `HSHOP_14_SMARTWATCH` | 📝 Documented | 700 | 0 | Each turn: -1 INACTIVE AP (except child-blocked) | Same as HSHOP_13 |

### Card Categories

**Duplicate Cards (2 each):**
- COFFEE: 2 cards (HSHOP_01, HSHOP_02)
- BABYMONITOR: 2 cards (HSHOP_06, HSHOP_07)
- CAR: 2 cards (HSHOP_09, HSHOP_10)
- SMARTWATCH: 2 cards (HSHOP_13, HSHOP_14)

**Unique Cards (1 each):**
- COMPUTER: 1 card (HSHOP_03)
- DEVICE: 1 card (HSHOP_04)
- TV: 1 card (HSHOP_05)
- HMONITOR: 1 card (HSHOP_08)
- ALARM: 1 card (HSHOP_11)
- SMARTPHONE: 1 card (HSHOP_12)

---

## 🎯 Implementation Status

- [ ] Create `HI_TECH_DEF` table in Shop Engine
- [ ] Remove purchase block for H cards (row ~= "C")
- [ ] Implement card effects
- [ ] Test all 14 cards

---

## 📝 Detailed Card Mechanics

### 1-2. COFFEE (High-End Coffee Machine)
- **Cost:** 1200 WIN, 0 AP
- **Effect:** Permanent rest-equivalent bonus +1 (same system as PILLS)
  - Reduces required REST AP by 1 per year to maintain health
  - Stacks with other rest-equivalent bonuses
- **Type:** Permanent passive effect
- **Mechanic:** Tracked in Shop Engine's `restEquivalent[color]`, but permanent (doesn't reset)
- **Verification:** System checks at start of turn if player still has the card (can be stolen/broken)

### 3. COMPUTER (High-End Computer)
- **Cost:** 1100 WIN, 0 AP
- **Effect:** Spend 1 AP → Gain +1 Knowledge (unlimited uses per turn)
- **Type:** Interactive - requires UI button on card
- **Usage:** Player can use 5 AP to get 5 Knowledge, or any amount per turn
- **Implementation:** Need to add button to card after purchase, allow spending AP dynamically

### 4. DEVICE (Educational Device)
- **Cost:** 1100 WIN, 0 AP
- **Effect:** Spend 1 AP → Gain +1 Skill (unlimited uses per turn)
- **Type:** Interactive - requires UI button on card
- **Usage:** Same as Computer but for Skills
- **Implementation:** Similar to Computer but affects Skills stat

### 5. TV (50 inch TV)
- **Cost:** 1400 WIN, 0 AP
- **Effect:** Spend 1-4 AP → Gain +1 Satisfaction per AP (max 4 AP per turn)
- **Type:** Interactive - requires UI button on card
- **Usage:** Player can spend 1, 2, 3, or 4 AP per turn to get that many SAT points
- **Implementation:** Button on card allows choosing how many AP to spend (1-4), then grants SAT

### 6-7. BABYMONITOR (Electronic Baby Monitor)
- **Cost:** 1200 WIN, 0 AP
- **Effect:** Reduces child AP blocking by 1 per baby (works for max 2 babies)
  - If player has 1 child: -1 AP blocked (was 2, now 1)
  - If player has 2 children: -2 AP blocked (was 4, now 2)
- **Type:** Permanent passive effect
- **Mechanic:** Modifies child-blocked AP tracking in Player Status Controller
- **Note:** Only affects child-blocked AP, not other INACTIVE AP

### 8. HMONITOR (Health Monitor)
- **Cost:** 300 WIN, 0 AP
- **Effect:** Manual SICK protection (click card to check and cure)
  - Player clicks card when they want to check if sick
  - If sick: roll die (player rolls physically)
  - Roll 1-2: Still sick (status remains)
  - Roll 3-6: Instantly cured (SICK status removed)
  - No effect on WOUNDED status
  - Once per turn (usage tracked)
- **Type:** Interactive card - requires UI button on card (manual click-to-use for immersion)
- **Implementation:** Click handler `hitech_onHMonitorUse` in Shop Engine - players manage their own resources and roll die manually

### 9-10. CAR (New Car)
- **Cost:** 1200 WIN, 0 AP
- **Effect:**
  - Shop visits: Entry AP cost waived (usually 1 AP)
  - Estate Agency visits: Entry AP cost waived (if any)
  - Event cards: -1 AP cost (cannot go below 0)
- **Type:** Permanent passive modifier
- **Implementation:** 
  - Shop Engine: Check for CAR ownership before charging entry AP
  - Event Engine: Reduce event card AP costs by 1 if player has CAR
  - Note: This affects the COST, not a refund

### 11. ALARM (Anti-Burglary Alarm)
- **Cost:** 700 WIN, 0 AP
- **Effect:** Protects items and cash from theft events
  - Player possessions cannot be stolen (money, items)
  - Player can still get WOUNDED from crime events
  - Only affects "theft" type events, not physical harm
- **Type:** Passive protection
- **Implementation:** Event Engine checks for ALARM before applying theft effects

### 12. SMARTPHONE
- **Cost:** 1000 WIN, 0 AP
- **Effect:** Once per turn: If player spent ≥2 AP on Work or Learning → +1 Satisfaction
  - Checks at end of player's turn
  - Must have spent AP on WORK area OR SCHOOL/LEARNING area during the turn
  - Grants +1 SAT if condition met
- **Type:** End-of-turn check
- **Implementation:** Check AP spent in WORK and SCHOOL areas at end of turn (in Turn Controller's `endTurnProcessing()`)

### 13-14. SMARTWATCH
- **Cost:** 700 WIN, 0 AP
- **Effect:** Each turn: Reduce INACTIVE AP by 1 (except child-blocked AP)
  - Moves 1 AP from INACTIVE back to START
  - Does NOT affect child-blocked AP (permanent)
  - Can use `PS_GetNonChildBlockedAP()` to find removable AP
- **Type:** Start-of-turn effect
- **Implementation:** 
  - Uses child AP tracking system
  - Calls `PS_GetNonChildBlockedAP()` to find AP that can be unblocked
  - Moves 1 AP back via AP Controller `moveAP({to="START", amount=-1})`

---

## 🎯 Implementation Requirements

### Card Ownership Tracking
- **Permanent Items:** Need system to track which player owns which Hi-Tech cards
- **Verification:** Check at start of turn if player still has the card (can be stolen/broken)
- **Storage:** Store owned cards per player (probably in Shop Engine state or new system)

### Interactive Cards
- **COMPUTER, DEVICE, TV, HMONITOR:** Have UI buttons on card after purchase (manual click-to-use)
- **Button Actions:** Allow player to spend AP dynamically (COMPUTER/DEVICE/TV) or manage health (HMONITOR)
- **Design Rationale:** Manual interaction adds immersion - players manage resources themselves and roll die physically

### Passive Modifiers
- **COFFEE, CAR, ALARM, BABYMONITOR:** Modify existing systems automatically
- **HMONITOR, COMPUTER, DEVICE, TV:** Interactive cards (player clicks to use - intentional for immersion)
- **SMARTPHONE, SMARTWATCH:** Trigger at specific times (end-of-round, start-of-turn)

### Integration Points
- **Shop Engine:** COFFEE (rest-equivalent), CAR (entry cost waiver), HMONITOR (click handler)
- **Event Engine:** CAR (event AP cost reduction), ALARM (theft protection)
- **Turn Controller:** SMARTWATCH (start-of-turn INACTIVE reduction), SMARTPHONE (end-of-round check)
- **Player Status Controller:** BABYMONITOR (child AP block reduction)
- **Stats Controller:** COMPUTER (Knowledge), DEVICE (Skills)
- **Satisfaction Token:** TV, SMARTPHONE (SAT grants)
- **AP Controller:** COMPUTER, DEVICE, TV (AP spending), SMARTWATCH (AP unblocking)

---

## 📝 Notes

- All Hi-Tech cards are **permanent items** - once purchased, player keeps them (unless stolen/broken)
- Cards need ownership verification at start of turn
- Some cards are interactive (need UI), others are passive (automatic effects)
- Child AP tracking system will be used by BABYMONITOR and SMARTWATCH
