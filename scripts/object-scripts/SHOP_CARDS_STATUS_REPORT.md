# Shop Cards Implementation Status Report

**Last Updated:** 2026-01-XX  
**Total Shop Cards:** 56 (28 Consumables + 14 Hi-Tech + 14 Investments)

---

## 📊 Summary Overview

| Category | Total Cards | ✅ Fully Working | ⚠️ Partially Working | ❌ Not Implemented |
|----------|-------------|------------------|----------------------|---------------------|
| **Consumables (C)** | 28 | 28 | 0 | 0 |
| **Hi-Tech (H)** | 14 | 8 | 6 | 0 |
| **Investments (I)** | 14 | 10 | 0 | 2 |
| **TOTAL** | **56** | **46** | **6** | **2** |

---

## 🟢 CONSUMABLES (C) - 28 Cards

### ✅ Fully Working (28 cards)

1. **CURE** (6 cards: CSHOP_01-06)
   - ✅ Dice rolling (manual)
   - ✅ SICK/WOUNDED removal
   - ✅ +3 Health
   - ✅ Conditional AP cost (roll 2-4 = +1 AP, roll 5-6 = free)

2. **KARMA** (2 cards: CSHOP_07-08)
   - ✅ Adds GOOD_KARMA status token

3. **BOOK** (2 cards: CSHOP_09-10)
   - ✅ +2 Knowledge

4. **MENTORSHIP** (2 cards: CSHOP_11-12)
   - ✅ +2 Skills

5. **SUPPLEMENTS** (3 cards: CSHOP_13-15)
   - ✅ +2 Health

6. **PILLS** (5 cards: CSHOP_16-20)
   - ✅ +3 rest-equivalent bonus
   - ✅ Addiction risk mechanic (dice roll)
   - ✅ Addiction consequences (3 tokens, AP loss)
   - ✅ Treatment mechanic (cure addiction)

7. **NATURE_TRIP** (2 cards: CSHOP_21-22)
   - ✅ +3 rest-equivalent bonus
   - ✅ Dice rolling for SAT (1-6 SAT)

8. **FAMILY** (2 cards: CSHOP_23-24) - **"Planning Center"**
   - ✅ Dice rolling (manual)
   - ✅ Child creation (BOY/GIRL tokens)
   - ✅ **Child costs per turn** - 150 WIN per turn added to Costs Calculator
   - ✅ **AP blocking** - 2 AP blocked to INACTIVE when child is born
   - **Note:** Fully functional - creates child tokens, blocks AP, and adds recurring costs

9. **SAT Cards** (4 cards: CSHOP_25-28)
   - ✅ BALLOON: +4 SAT, 1 AP extra
   - ✅ GRAVITY: +12 SAT, 1 AP extra
   - ✅ BUNGEE: +6 SAT, 1 AP extra
   - ✅ PARACHUTE: +8 SAT, 1 AP extra

---

## 🔵 HI-TECH (H) - 14 Cards

### ✅ Fully Working (8 cards)

1. **COFFEE** (2 cards: HSHOP_01-02)
   - ✅ Permanent rest-equivalent +1
   - ✅ Tracks ownership
   - ✅ Stacks with other bonuses

2. **COMPUTER** (1 card: HSHOP_03)
   - ✅ Interactive button on card
   - ✅ Spend 1 AP → +1 Knowledge (unlimited)

3. **DEVICE** (1 card: HSHOP_04)
   - ✅ Interactive button on card
   - ✅ Spend 1 AP → +1 Skill (unlimited)

4. **TV** (1 card: HSHOP_05)
   - ✅ Interactive button on card
   - ✅ Spend 1-4 AP → +1 SAT per AP

5. **BABYMONITOR** (2 cards: HSHOP_06-07)
   - ✅ Reduces child AP blocking by 1 per baby (max 2 babies)
   - ✅ Immediately unblocks AP when purchased (if player has children)
   - ✅ Only ONE monitor works per player (owning 2 gives same benefit as 1)

6. **HMONITOR** (1 card: HSHOP_08)
   - ✅ Interactive button on card
   - ✅ Manual SICK protection (roll die, 3-6 = cure)
   - ✅ Once per turn usage tracking

### ⚠️ Partially Working (6 cards)

7. **CAR** (2 cards: HSHOP_09-10)
   - ✅ Shop entry free (waives 1 AP entry cost)
   - ✅ Event cards -1 AP cost reduction (implemented)
   - ❌ **Estate Agency entry free** - NOT IMPLEMENTED
   - **Note:** Event Engine has CAR reduction, but Estate Engine doesn't check for CAR ownership

8. **ALARM** (1 card: HSHOP_11)
   - ✅ Purchasing works
   - ✅ Ownership tracking works
   - ❌ **Theft protection** - NOT IMPLEMENTED
   - **Note:** Event Engine doesn't check for ALARM before applying theft effects

9. **SMARTPHONE** (1 card: HSHOP_12)
   - ✅ Purchasing works
   - ✅ Ownership tracking works
   - ❌ **End-of-turn Work/Learning check** - NOT IMPLEMENTED
   - **Note:** Turn Controller doesn't check if player spent ≥2 AP on Work/Learning

10. **SMARTWATCH** (2 cards: HSHOP_13-14)
    - ✅ Purchasing works
    - ✅ Ownership tracking works
    - ❌ **Start-of-turn -1 INACTIVE AP** - NOT IMPLEMENTED
    - **Note:** Turn Controller doesn't unblock AP for SMARTWATCH owners

---

## 🟡 INVESTMENTS (I) - 14 Cards

### ✅ Fully Working (10 cards)

1. **LOTTERY1** (2 cards: ISHOP_01-02)
   - ✅ Dice rolling (manual)
   - ✅ Payout: Roll 5 = 100 WIN, Roll 6 = 500 WIN

2. **LOTTERY2** (2 cards: ISHOP_03-04)
   - ✅ Dice rolling (manual)
   - ✅ Payout: Roll 4 = 300 WIN, Roll 5 = 500 WIN, Roll 6 = 1000 WIN

3. **ESTATEINVEST** (2 cards: ISHOP_06-07)
   - ✅ Interactive payment method selection (60% now vs 3×30%)
   - ✅ Apartment delivery on next turn
   - ✅ Cost Calculator integration (for 3×30% payments)
   - ✅ Resign button (if insufficient funds)
   - ✅ Token placement with correct housing level

4. **DEBENTURES** (1 card: ISHOP_08)
   - ✅ Interactive counter for investment amount
   - ✅ 3 payments (same amount each turn)
   - ✅ Cost Calculator integration
   - ✅ Cash out buttons (early or with profit after 3 turns)
   - ✅ 200% return (100% profit)

5. **LOAN** (2 cards: ISHOP_10-11)
   - ✅ Interactive counter for loan amount
   - ✅ 4 instalments of 33% each
   - ✅ Cost Calculator integration
   - ✅ End-of-game balance check

6. **ENDOWMENT** (1 card: ISHOP_12)
   - ✅ Duration selection (2/3/4 years)
   - ✅ Interactive counter for investment amount
   - ✅ Payments over chosen duration
   - ✅ Profit calculation (50%/125%/200% profit)
   - ✅ Cost Calculator integration

7. **STOCK** (2 cards: ISHOP_13-14)
   - ✅ Interactive counter for investment amount
   - ✅ Double dice roll system
   - ✅ Resign option
   - ✅ Result calculation (2× profit, break even, or loss)

### ❌ Not Implemented (2 cards - Intentionally Skipped)

8. **PROPINSURANCE** (1 card: ISHOP_05)
   - ❌ **NOT IMPLEMENTED** - Requires theft/repair system integration
   - **Planned Effect:** Protects hi-tech items from problems (free repairs)
   - **Status:** Intentionally skipped for now

9. **HEALTHINSURANCE** (1 card: ISHOP_09)
   - ❌ **NOT IMPLEMENTED** - Requires work/job system integration
   - **Planned Effect:** Get equivalent of lost revenues from job while SICK/WOUNDED
   - **Status:** Intentionally skipped for now

---

## 📝 Detailed Status Breakdown

### Consumables Issues

**No Issues:**
- ✅ **FAMILY Cards:** Fully functional - creates child tokens, blocks 2 AP to INACTIVE, and adds 150 WIN per turn to Costs Calculator

### Hi-Tech Missing Features

**Partial Implementations:**
1. ⚠️ **CAR:** Missing Estate Agency entry free (Event -1 AP works)
2. ⚠️ **ALARM:** Theft protection not implemented in Event Engine
3. ⚠️ **SMARTPHONE:** End-of-turn check not implemented in Turn Controller
4. ⚠️ **SMARTWATCH:** Start-of-turn AP unblocking not implemented in Turn Controller

### Investment Cards

**All Working Investment Cards:**
- ✅ LOTTERY1/2: Simple dice-based payouts
- ✅ ESTATEINVEST: Complex payment system, apartment delivery, resign option
- ✅ DEBENTURES: Multi-turn payments, profit system, cash out buttons
- ✅ LOAN: Multi-instalment payments, end-of-game check
- ✅ ENDOWMENT: Duration selection, profit calculation
- ✅ STOCK: Double dice roll, resign option, profit/loss calculation

**Intentionally Skipped:**
- ❌ PROPINSURANCE: Requires theft/repair system
- ❌ HEALTHINSURANCE: Requires work/job system

---

## 🎯 Implementation Completion

**Overall Progress:**
- **Consumables:** 28/28 fully working (100%) ✅
- **Hi-Tech:** 8/14 fully working, 6/14 partially working (57% fully, 100% purchasable)
- **Investments:** 10/14 fully working, 2/14 skipped (71% fully, 100% purchasable)

**All Cards Purchasable:**
- ✅ All Consumables can be purchased
- ✅ All Hi-Tech cards can be purchased (ownership tracking works)
- ✅ All Investment cards can be purchased (except PROPINSURANCE/HEALTHINSURANCE which are intentionally blocked)

---

## 🔧 Recommended Next Steps

### High Priority

1. **Complete CAR Card:**
   - Add Estate Agency entry free check in Estate Engine

3. **Complete ALARM Card:**
   - Add theft protection check in Event Engine before applying theft effects

4. **Complete SMARTPHONE Card:**
   - Add end-of-turn check in Turn Controller
   - Check if player spent ≥2 AP on Work/Learning → +1 SAT

5. **Complete SMARTWATCH Card:**
   - Add start-of-turn check in Turn Controller
   - Unblock 1 AP from INACTIVE (except child-blocked) using `PS_GetNonChildBlockedAP()`

### Low Priority (Future)

6. **PROPINSURANCE:** Implement when theft/repair system is ready
7. **HEALTHINSURANCE:** Implement when work/job system is ready

---

## ✅ What's Working Well

- **Purchase System:** All three shop rows (C/H/I) can be purchased
- **Ownership Tracking:** Hi-Tech ownership tracking works perfectly
- **Interactive Cards:** COMPUTER, DEVICE, TV, HMONITOR all have working buttons
- **Investment Cards:** Complex multi-turn payment systems work correctly
- **Cost Calculator Integration:** Investment payments properly integrated
- **Dice Rolling:** Manual dice system works for all dice-requiring cards
- **BABYMONITOR:** Recently fixed to immediately unblock AP when purchased

---

**Generated:** Based on current codebase analysis
