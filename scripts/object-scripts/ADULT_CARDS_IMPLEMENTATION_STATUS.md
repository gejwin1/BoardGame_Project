# Adult Event Cards - Implementation Status Analysis

**Last Updated:** Based on EventEngine v1.7.2+  
**Total Adult Cards:** 81 (AD_01 through AD_81)

---

## 📊 Summary

| Status | Count | Cards | Percentage |
|--------|-------|-------|------------|
| ✅ **Fully Implemented** | 48 | AD_01-11, AD_12-15, AD_16-29, AD_30-31, AD_35-41, AD_44-46, AD_48-57 | **59.3%** |
| ⚠️ **Partially Implemented** | 9 | AD_32-34, AD_47 | **11.1%** |
| ❌ **Not Implemented** | 24 | AD_42-43, AD_58-81 | **29.6%** |

---

## ✅ FULLY IMPLEMENTED CARDS (48 cards)

### 1. **AD_SICK_O** (Cards AD_01-05) - ✅ **FULLY IMPLEMENTED**
- **Type:** Obligatory
- **Effect:** -3 Health, adds SICK status token
- **Status:** Complete - Works as intended

### 2. **AD_VOUCH_CONS** (Cards AD_06-09) - ✅ **FULLY IMPLEMENTED**
- **Type:** Keep (Voucher)
- **Effect:** 25% discount on Consumables in shop
- **Status:** Complete - Voucher system works

### 3. **AD_VOUCH_HI** (Cards AD_10-11) - ✅ **FULLY IMPLEMENTED**
- **Type:** Keep (Voucher)
- **Effect:** 25% discount on Hi-Tech items in shop
- **Status:** Complete - Voucher system works

### 4. **AD_LUXTAX_O** (Cards AD_12-13) - ✅ **FULLY IMPLEMENTED** (Recently Implemented)
- **Type:** Obligatory
- **Effect:** Pay 200 WIN per owned hi-tech item
- **Status:** Complete - Calculates item count, charges money, blocks if insufficient funds

### 5. **AD_PROPTAX_O** (Cards AD_14-15) - ✅ **FULLY IMPLEMENTED** (Recently Implemented)
- **Type:** Obligatory
- **Effect:** Pay 300 WIN per apartment level (L0=0, L1=1, L2=2, L3=3, L4=4)
- **Status:** Complete - Detects estate level, charges money, blocks if insufficient funds

### 6. **AD_DATE** (Cards AD_16-20) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** 2 AP cost, +2 SAT (or +4 SAT if married), adds DATING status
- **Status:** Complete - Marriage bonus works correctly

### 7. **AD_CHILD100_O** (Cards AD_21-23) - ✅ **FULLY IMPLEMENTED**
- **Type:** Obligatory (Dice-based)
- **Effect:** Dice roll - Child birth (3-6), cost 100 WIN/turn, blocks 2 AP
- **Status:** Complete - All mechanics working:
  - Dice roll determines child birth
  - Child cost added to Costs Calculator
  - AP blocking with marriage/BABYMONITOR reductions

### 8. **AD_CHILD150_O** (Cards AD_24-26) - ✅ **FULLY IMPLEMENTED**
- **Type:** Obligatory (Dice-based)
- **Effect:** Dice roll - Child birth (3-6), cost 150 WIN/turn, blocks 2 AP
- **Status:** Complete - Same as AD_CHILD100_O

### 9. **AD_CHILD200_O** (Cards AD_27-29) - ✅ **FULLY IMPLEMENTED**
- **Type:** Obligatory (Dice-based)
- **Effect:** Dice roll - Child birth (3-6), cost 200 WIN/turn, blocks 2 AP
- **Status:** Complete - Same as AD_CHILD100_O

### 10. **AD_HI_FAIL_O** (Cards AD_30-31) - ✅ **FULLY IMPLEMENTED** (Recently Implemented)
- **Type:** Obligatory
- **Effect:** Randomly breaks one hi-tech item, repair cost 25% of original value
- **Status:** Complete - Full implementation:
  - Randomly selects one owned hi-tech item
  - Shows repair button on card (interactive)
  - Repair costs calculated (25% of original)
  - Broken state tracking (persists across turns)
  - Skip option available

### 11. **AD_MARRIAGE** (Cards AD_35-41) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** -500 WIN, 4 AP cost, +2 SAT, requires DATING status
- **Special:** Multi-player effect (all other players affected)
- **Status:** Complete - All mechanics working:
  - ✅ DATING status requirement (blocks if missing)
  - ✅ Marriage token added
  - ✅ Multi-player bonuses applied
  - ✅ Marriage bonus for child AP blocking (-1 AP per child)

### 12. **AD_KARMA** (Cards AD_44-46) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** 1 AP cost, adds GOOD_KARMA status token
- **Status:** Complete - Works correctly (token appears on board)

### 13. **AD_SPORT** (Cards AD_48-50) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant (Dice-based)
- **Effect:** 1 AP cost, -100 WIN, dice roll for SAT reward
- **Dice Table:** Roll 1-2 = +0 SAT, Roll 3-6 = +2 SAT
- **Status:** Complete - Dice rolling and SAT rewards work

### 14. **AD_BABYSITTER50** (Cards AD_51-52) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** Unlocks 1-2 AP from child block, costs 50 WIN per AP
- **Status:** Complete - Choice system works, AP movement correct

### 15. **AD_BABYSITTER70** (Cards AD_53-54) - ✅ **FULLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** Unlocks 1-2 AP from child block, costs 70 WIN per AP
- **Status:** Complete - Same as AD_BABYSITTER50

### 16. **AD_AUNTY_O** (Cards AD_55-57) - ✅ **FULLY IMPLEMENTED**
- **Type:** Obligatory (Dice-based)
- **Effect:** Dice roll with various effects, may unlock child AP block
- **Dice Table:** 
  - Roll 1-2: -200 WIN
  - Roll 3-4: -200 WIN, unlocks 1-2 AP from child block
  - Roll 5-6: +600 WIN
- **Status:** Complete - All dice outcomes work, AP unlock works

---

## ⚠️ PARTIALLY IMPLEMENTED CARDS (9 cards)

### 1. **AD_WORKBONUS** (Cards AD_32-34) - ⚠️ **PARTIALLY IMPLEMENTED**
- **Type:** Instant
- **Effect:** 1 AP cost, supposed to give work bonus based on profession
- **Current Status:** 
  - ✅ Card plays (AP charged, card discarded)
  - ❌ **Missing:** Profession system not implemented
  - **Message:** "ℹ️ WORK BONUS: profesje jeszcze TODO."
- **What's Missing:**
  - Profession/job tracking system
  - Work bonus calculation based on profession
  - Actual bonus application (money/stats/SAT)

**Partial Implementation Meaning:** The card can be played and costs AP, but the actual bonus effect (the main purpose) is not implemented. It's essentially a placeholder that does nothing beyond charging AP.

---

### 2. **AD_AUCTION_O** (Card AD_47) - ⚠️ **PARTIALLY IMPLEMENTED**
- **Type:** Obligatory
- **Effect:** Should trigger an auction/estate purchase system
- **Current Status:**
  - ✅ Card is recognized (obligatory card detected)
  - ❌ **Missing:** Auction system mechanics
  - **Message:** "ℹ️ AUCTION: system aukcji/nieruchomości TODO."
- **What's Missing:**
  - Auction scheduling system
  - Estate purchase/auction mechanics
  - Bidding system (if applicable)

**Partial Implementation Meaning:** The card is recognized as obligatory (must be played), but the auction mechanics are not implemented. It essentially does nothing when played.

---

## ❌ NOT IMPLEMENTED CARDS (24 cards)

### 1. **AD_VOUCH_PROP** (Cards AD_42-43) - ❌ **NOT IMPLEMENTED**
- **Type:** Keep (Voucher)
- **Planned Effect:** 20% discount on Property purchases
- **Current Status:**
  - ✅ Card type is defined in TYPES table
  - ✅ Has `todo=true` flag
  - ✅ Note: "Property purchase system not implemented yet"
  - ❌ **Missing:** Property purchase system (rent/buy estates works, but voucher discount not applied)

**Not Implemented Meaning:** The card exists and can be kept, but the discount system for property purchases is not integrated. The Estate Engine handles purchases, but voucher discounts are not checked/used.

---

### 2. **AD_VE_*** (Cards AD_58-81) - ❌ **NOT IMPLEMENTED**
- **Type:** Instant (Vocation Events)
- **Count:** 24 cards (12 unique types, 2 cards each)
- **Planned Effect:** Choice-based system - player chooses between two Vocation Event paths

**All VE Cards:**
- AD_58-59: VE-NGO2-SOC1 (choice: NGO2 or SOC1)
- AD_60-61: VE-NGO1-GAN1 (choice: NGO1 or GAN1)
- AD_62-63: VE-NGO1-ENT1 (choice: NGO1 or ENT1)
- AD_64-65: VE-NGO2-CEL1 (choice: NGO2 or CEL1)
- AD_66-67: VE-SOC2-CEL1 (choice: SOC2 or CEL1)
- AD_68-69: VE-SOC1-PUB1 (choice: SOC1 or PUB1)
- AD_70-71: VE-GAN1-PUB2 (choice: GAN1 or PUB2)
- AD_72-73: VE-ENT1-PUB1 (choice: ENT1 or PUB1)
- AD_74-75: VE-CEL2-PUB2 (choice: CEL2 or PUB2)
- AD_76-77: VE-CEL2-GAN2 (choice: CEL2 or GAN2)
- AD_78-79: VE-ENT2-GAN2 (choice: ENT2 or GAN2)
- AD_80-81: VE-ENT2-SOC2 (choice: ENT2 or SOC2)

**Current Status:**
- ✅ Card types defined in TYPES table
- ✅ All have `todo=true` flag
- ✅ Choice UI structure exists (`startChoiceOnCard_AB` function)
- ✅ Shows choice buttons (A/B) on card
- ❌ **Missing:** Actual effect application for chosen VE path
- **Message:** Shows choice but effects not processed

**Not Implemented Meaning:** The UI shows choice buttons when card is played, but selecting an option does nothing. The Vocation Events tracking system and effects (stats/SAT/money bonuses) are not implemented.

---

## 📋 Detailed Status by Card Range

| Card Range | Type | Status | Notes |
|------------|------|--------|-------|
| **AD_01-05** | AD_SICK_O | ✅ Full | -3 Health, SICK status |
| **AD_06-09** | AD_VOUCH_CONS | ✅ Full | 25% Consumables discount |
| **AD_10-11** | AD_VOUCH_HI | ✅ Full | 25% Hi-Tech discount |
| **AD_12-13** | AD_LUXTAX_O | ✅ Full | 200 WIN per hi-tech item |
| **AD_14-15** | AD_PROPTAX_O | ✅ Full | 300 WIN per estate level |
| **AD_16-20** | AD_DATE | ✅ Full | +2 SAT (+4 if married) |
| **AD_21-23** | AD_CHILD100_O | ✅ Full | Child birth, 100 WIN/turn |
| **AD_24-26** | AD_CHILD150_O | ✅ Full | Child birth, 150 WIN/turn |
| **AD_27-29** | AD_CHILD200_O | ✅ Full | Child birth, 200 WIN/turn |
| **AD_30-31** | AD_HI_FAIL_O | ✅ Full | Breaks hi-tech, repair system |
| **AD_32-34** | AD_WORKBONUS | ⚠️ Partial | Missing profession system |
| **AD_35-41** | AD_MARRIAGE | ✅ Full | Requires DATING, multi-effect |
| **AD_42-43** | AD_VOUCH_PROP | ❌ None | Property voucher discount |
| **AD_44-46** | AD_KARMA | ✅ Full | GOOD_KARMA token |
| **AD_47** | AD_AUCTION_O | ⚠️ Partial | Missing auction system |
| **AD_48-50** | AD_SPORT | ✅ Full | Dice for SAT |
| **AD_51-54** | AD_BABYSITTER | ✅ Full | Unlock child AP |
| **AD_55-57** | AD_AUNTY_O | ✅ Full | Dice, unlock child AP |
| **AD_58-81** | AD_VE_* | ❌ None | 24 Vocation Events cards |

---

## 🔍 Implementation Details

### What "Fully Implemented" Means:
- Card is recognized and playable
- All effects work as intended (money, SAT, stats, AP, status tokens)
- Special mechanics work (dice, choices, multi-effects)
- Integration with other systems works (AP Controller, Money Controller, Token Engine, etc.)

### What "Partially Implemented" Means:
- Card can be played (AP/money charged, card processed)
- Basic structure exists (card type defined, handlers exist)
- **BUT:** Main effect or special mechanic is missing/incomplete
- Card essentially does nothing or shows "TODO" message

### What "Not Implemented" Means:
- Card type exists in definitions (`todo=true` flag)
- Card can be played and discarded
- **BUT:** No actual effects or mechanics implemented
- Choice UI might exist but choices don't do anything
- Voucher might be kept but discount not applied

---

## 🎯 Priority Recommendations

### High Priority (Core Mechanics):
1. **AD_VOUCH_PROP** - Property voucher discount integration (2 cards)
   - Relatively simple - just need to check voucher ownership in Estate Engine when purchasing

### Medium Priority (Game Features):
2. **AD_WORKBONUS** - Profession system implementation (3 cards)
   - Requires designing profession tracking system
   - Define work bonuses per profession

3. **AD_AUCTION_O** - Auction system (1 card)
   - Complex system - requires auction scheduling, bidding mechanics
   - May integrate with Estate Engine

### Lower Priority (Vocation Events):
4. **AD_VE_*** - Vocation Events system (24 cards)
   - Large system - requires tracking VE points/tracks
   - Define effects for each VE path (NGO, SOC, GAN, ENT, CEL, PUB)
   - May affect stats, SAT, or other game systems

---

## 📝 Notes

- All implemented cards work with Good Karma system (if obligatory)
- All implemented cards work with CAR hi-tech reduction
- All implemented cards integrate with Costs Calculator (where applicable)
- Child cards (AD_21-29) fully integrate with:
  - Marriage bonus (reduces AP blocking)
  - BABYMONITOR bonus (reduces AP blocking)
  - Babysitter cards (unlock AP)
  - Aunty cards (unlock AP)
  - Costs Calculator (track baby costs)
- All dice-based cards use physical die system
- All choice cards have interactive UI buttons

---

**Generated:** Based on EventEngine code analysis  
**File:** `7b92b3_EventEngine.lua`
