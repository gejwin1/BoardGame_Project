# Investment Cards (ISHOP) - Detailed Mechanics Analysis

**Last Updated:** Based on user specifications  
**Total Investment Cards:** 14 (ISHOP_01 through ISHOP_14)  
**Script:** `d59e04_ShopEngine.lua`

---

## 📋 Card List

1. **ISHOP_01_LOTTERY1** - Lottery Ticket (First Type)
2. **ISHOP_02_LOTTERY1** - Lottery Ticket (First Type)
3. **ISHOP_03_LOTTERY2** - Lottery Ticket (Second Type)
4. **ISHOP_04_LOTTERY2** - Lottery Ticket (Second Type)
5. **ISHOP_05_PROPINSURANCE** - Property Insurance (⚠️ NOT IMPLEMENTED YET)
6. **ISHOP_06_ESTATEINVEST** - Real Estate Investment
7. **ISHOP_07_ESTATEINVEST** - Real Estate Investment
8. **ISHOP_08_DEBENTURES** - Debentures Investment
9. **ISHOP_09_HEALTHINSURANCE** - Health Insurance (⚠️ NOT IMPLEMENTED YET)
10. **ISHOP_10_LOAN** - Bank Loan
11. **ISHOP_11_LOAN** - Bank Loan
12. **ISHOP_12_ENDOWMENT** - Endowment Insurance
13. **ISHOP_13_STOCK** - Stock Exchange Investment
14. **ISHOP_14_STOCK** - Stock Exchange Investment

---

## ✅ CARD DETAILS - FULL IMPLEMENTATION SPECS

### 1. **LOTTERY1** (ISHOP_01-02) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** 50 WIN
- **Type:** Instant (Dice-based)
- **Mechanics:**
  - Player purchases ticket
  - **Dice Roll Required:** D6
  - **Dice Table:**
    - Roll 1-4: **Lose** (no reward)
    - Roll 5: **Win 100 WIN**
    - Roll 6: **Win 500 WIN**
- **Implementation Notes:**
  - Similar to existing dice cards (NATURE_TRIP, CURE, FAMILY)
  - Show "ROLL D6" button on card after purchase
  - Use `startDiceOnCard()` pattern from Consumables
  - Card discarded after dice resolution

---

### 2. **LOTTERY2** (ISHOP_03-04) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** 200 WIN
- **Type:** Instant (Dice-based)
- **Mechanics:**
  - Player purchases ticket
  - **Dice Roll Required:** D6
  - **Dice Table:**
    - Roll 1-3: **Lose** (no reward)
    - Roll 4: **Win 300 WIN**
    - Roll 5: **Win 500 WIN**
    - Roll 6: **Win 1,000 WIN**
- **Implementation Notes:**
  - Same dice system as LOTTERY1
  - Different prize table
  - Card discarded after dice resolution

---

### 3. **PROPINSURANCE** (ISHOP_05) - ❌ **SKIP (NOT YET IMPLEMENTED)**
- **Purchase Cost:** 500 WIN
- **Type:** Keep (Insurance Policy)
- **Planned Effect:** 
  - Protects hi-tech items from problems (free repairs)
  - Protects money from being stolen (insurance refund)
- **Current Status:** ⚠️ **DON'T IMPLEMENT YET** - Requires theft mechanics and repair system integration
- **Future Implementation:**
  - Card kept by player (similar to Hi-Tech)
  - Check for insurance when hi-tech breaks or theft occurs
  - Provide free repairs or money refunds

---

### 4. **ESTATEINVEST** (ISHOP_06-07) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** Interactive (Player chooses payment method)
- **Type:** Interactive (Choice-based, Multi-turn payments)
- **Mechanics:**
  - **Apartment Delivery:** Player **always** gets apartment on **next turn** (turn 2) after taking the card, regardless of payment method chosen.
  - **Choice 1: Pay 60% Now**
    - Player pays 60% of apartment value immediately (turn 1)
    - Gets apartment **next turn** (turn 2)
  - **Choice 2: Three Payments of 30% Each**
    - Player pays 30% immediately (turn 1 - when card is taken)
    - Gets apartment **next turn** (turn 2 - same turn as second payment)
    - Player pays 30% in **second turn** (turn 2 - same turn as apartment delivery)
    - Player pays 30% in **third turn** (turn 3 - final payment)
    - **WARNING:** If player fails to pay any installment, loses property
  - **Restrictions:**
    - Cannot use discount cards/vouchers with this investment
  - **Cost Calculator Integration:**
    - Three payment option: Each 30% payment added to cost calculator for that turn
    - Player must pay via cost calculator or auto-deduct at turn end

- **Implementation Details:**
  - **Interactive Buttons:** Show choice buttons when card clicked
    - Button A: "PAY 60% NOW"
    - Button B: "3× PAYMENTS (30% each)"
  - **State Tracking Needed:**
    - Track which payment method chosen
    - Track payment progress (0, 1, 2, or 3 payments made)
    - Track apartment level chosen (L1, L2, L3, or L4)
    - Track total apartment value
  - **Integration with Estate Engine:**
    - Must query Estate Engine for current estate prices (ESTATE_PRICE table)
    - Call Estate Engine to place apartment **on next turn (turn 2)** after card is taken, regardless of payment method or payment completion status
  - **Payment Tracking:**
    - Store investment state: `investments[color] = { estateInvest = {method="60pct"|"3x30pct", level="L1", paidCount=0, totalValue=2000, ...} }`
    - Check at start of each turn if payments due
    - Add to cost calculator if payment due
  - **Loss Condition:**
    - If payment not made in time, investment is lost (no apartment, money gone)

---

### 5. **DEBENTURES** (ISHOP_08) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** Interactive (Player chooses investment amount)
- **Type:** Interactive (Keep card, Multi-turn investment)
- **Mechanics:**
  - **Investment Selection:**
    - Player chooses investment amount
    - **Increment System:** +50 WIN per click (50, 100, 150, 200, 250, ...)
    - Counter buttons: **+50** (increment), **-50** (decrement), **OK** (confirm)
    - Minimum: 50 WIN
  - **Payment Structure:**
    - Player invests chosen amount
    - **Same amount paid for 3 turns** (current turn + 2 more turns = 3 total payments)
    - Example: Invest 200 → Pay 200 in Turn 1, Turn 2, Turn 3
  - **Return Structure:**
    - After 3 turns (4th turn): Receive **200% of total investment** (100% profit)
    - Example: Invested 200 × 3 = 600 total, receive 1,200 WIN (600 profit)
  - **Early Cash Out:**
    - Player can take cash out **during any turn**
    - Button: **"TAKE OUT CASH NOW"**
    - Returns only invested amount (no profit)
  - **Final Cash Out:**
    - After 3 payments complete (4th turn)
    - Button: **"CASH OUT (WITH PROFIT)"** appears
    - Returns 200% of investment (100% profit)
  - **Security:**
    - "Nobody can steal the investment"
    - Investment protected from theft events

- **Implementation Details:**
  - **Card Kept by Player:** Similar to Hi-Tech cards (card stays with player)
  - **Initial Purchase Flow:**
    1. Player clicks card in shop
    2. Show counter UI: **-50** | **AMOUNT: 0** | **+50** | **OK**
    3. Player adjusts amount, clicks OK
    4. Charge initial payment (add to cost calculator)
    5. Give card to player with buttons attached
  - **Buttons on Card (Dynamic):**
    - **Initial State (Payments Remaining):** "TAKE OUT CASH NOW" (returns investment only)
    - **After 3 Payments (4th Turn):** "CASH OUT (WITH PROFIT)" (returns 200%)
    - Both buttons can exist simultaneously if payments complete
  - **State Tracking:**
    - `investments[color] = { debentures = {cardGUID="...", investedPerTurn=200, paidCount=0, totalInvested=0} }`
    - Track payment count (0, 1, 2, 3)
    - Track total invested (sum of all payments)
    - Track card GUID (to find card later for buttons)
  - **Cost Calculator Integration:**
    - Each payment (turn 1, 2, 3) added to cost calculator
    - Same amount for all 3 payments
  - **Turn Tracking:**
    - Check at start of each turn if debenture payment due
    - If payment due (paidCount < 3), add to cost calculator
    - Increment paidCount after payment
    - After paidCount == 3, show profit button on next turn

---

### 6. **HEALTHINSURANCE** (ISHOP_09) - ❌ **SKIP (NOT YET IMPLEMENTED)**
- **Purchase Cost:** 400 WIN
- **Type:** Keep (Insurance Policy)
- **Planned Effect:**
  - Get equivalent of lost revenues from job for APs while being SICK or WOUNDED
  - Insurance doesn't work with ADDICTIONS
- **Current Status:** ⚠️ **DON'T IMPLEMENT YET** - Requires work/job system implementation
- **Future Implementation:**
  - Check if player is SICK or WOUNDED
  - Calculate lost work income based on AP count blocked
  - Pay insurance benefit (money refund)
  - Exclude ADDICTION status from insurance coverage

---

### 7. **LOAN** (ISHOP_10-11) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** Interactive (Player chooses loan amount)
- **Type:** Interactive (Multi-turn payments)
- **Mechanics:**
  - **Loan Selection:**
    - Player chooses loan amount (same counter system as DEBENTURES?)
    - Or: Fixed amounts? (Need clarification)
  - **Payment Structure:**
    - **4 instalments of 33% each** of borrowed amount
    - Example: Borrow 1,500 → Pay 500 in Turn 2, 500 in Turn 3, 500 in Turn 4, 500 in Turn 5
    - Payments start **next turn** (Turn 1: take loan, Turns 2-5: pay instalments)
  - **End of Game Requirement:**
    - At end of game (last turn), must pay off **entire remaining loan** even if 4 years haven't passed
    - If 4 payments made: nothing due
    - If 1-3 payments made: pay remaining balance

- **Implementation Details:**
  - **Interactive Selection:** Same counter system as DEBENTURES (+50, -50, OK)
  - **State Tracking:**
    - `investments[color] = { loan = {amountBorrowed=1500, paidInstalments=0, instalmentAmount=500} }`
    - Track loan amount
    - Track number of instalments paid (0-4)
  - **Cost Calculator Integration:**
    - Each 33% instalment added to cost calculator
    - 4 instalments total (Turns 2, 3, 4, 5)
  - **End of Game Check:**
    - Must integrate with Turn Controller's end game detection
    - Calculate remaining balance: `(4 - paidInstalments) × instalmentAmount`
    - Force payment at game end

---

### 8. **ENDOWMENT** (ISHOP_12) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** Interactive (Player chooses duration, then amount)
- **Type:** Interactive (Multi-turn investment)
- **Mechanics:**
  - **Duration Selection:**
    - Player chooses investment duration: **2, 3, or 4 years**
    - Buttons: "2 YEARS" | "3 YEARS" | "4 YEARS"
  - **Payment Structure:**
    - **First instalment:** Same turn (when card purchased)
    - **Subsequent instalments:** Same amount each year for chosen duration
    - Example: Choose 3 years → Pay in Turn 1, Turn 2, Turn 3 (total 3 payments)
  - **Profit Calculation:**
    - **2 years:** 50% profit (receive 150% of total investment)
    - **3 years:** 125% profit (receive 225% of total investment)
    - **4 years:** 200% profit (receive 300% of total investment)
  - **Return:**
    - Receive money back **after duration complete**
    - Example: 3 years, invested 500 per year = 1,500 total → Receive 3,375 WIN (1,875 profit)

- **Implementation Details:**
  - **Two-Step Selection:**
    1. **First:** Choose duration (2/3/4 years) - buttons on card
    2. **Second:** Choose investment amount per year (counter: +50, -50, OK)
  - **State Tracking:**
    - `investments[color] = { endowment = {cardGUID="...", duration=3, amountPerYear=500, paidCount=0, totalInvested=0} }`
    - Track duration (2, 3, or 4)
    - Track amount per year
    - Track payment count (0, 1, 2, 3, or 4)
  - **Cost Calculator Integration:**
    - Each payment added to cost calculator (same amount each year)
    - Payments in Turns 1, 2, 3 (for 3-year option)
  - **Profit Calculation:**
    - Total invested = `amountPerYear × duration`
    - Return amount:
      - 2 years: `totalInvested × 1.5` (50% profit)
      - 3 years: `totalInvested × 2.25` (125% profit)
      - 4 years: `totalInvested × 3.0` (200% profit)
  - **Card Handling:**
    - Card kept by player (like Hi-Tech/Debentures)
    - Button appears after duration complete: "CASH OUT (PROFIT)"

---

### 9. **STOCK** (ISHOP_13-14) - ✅ **TO IMPLEMENT**
- **Purchase Cost:** Interactive (Player chooses investment amount)
- **Type:** Interactive (Double dice roll, can resign)
- **Mechanics:**
  - **Investment Selection:**
    - Player chooses investment amount (counter: +50, -50, OK)
  - **Dice Rolling System:**
    - **First Roll:** Predict the charts (any number 1-6)
    - **Second Roll:** Compare to first roll
    - **Results:**
      - **Second > First:** **Double investment** (2× return, 100% profit)
      - **Second == First:** **Nothing happens** (0× return, break even, get investment back)
      - **Second < First:** **Lose money** (0× return, lose investment)
  - **Resign Option:**
    - Player can **resign before second throw**
    - Returns investment amount (break even, no profit/loss)

- **Implementation Details:**
  - **Flow:**
    1. Player purchases card, chooses investment amount
    2. Pay investment amount immediately
    3. Show buttons: **"ROLL FIRST DIE"** and **"RESIGN"**
    4. After first roll: Show **"ROLL SECOND DIE"** and **"RESIGN"**
    5. After second roll: Calculate result and pay out
  - **Button States:**
    - **Before 1st Roll:** "ROLL FIRST DIE" | "RESIGN (Break Even)"
    - **After 1st Roll:** "ROLL SECOND DIE" | "RESIGN (Break Even)"
    - **After 2nd Roll:** Calculate result, pay out, remove buttons
  - **Dice State Tracking:**
    - `investments[color] = { stock = {cardGUID="...", investmentAmount=500, firstRoll=nil, secondRoll=nil, resolved=false} }`
  - **Result Calculation:**
    - First roll stored (1-6)
    - Second roll compared to first
    - Payout:
      - `secondRoll > firstRoll`: Return `investmentAmount × 2`
      - `secondRoll == firstRoll`: Return `investmentAmount` (break even)
      - `secondRoll < firstRoll`: Return `0` (lose investment)
    - Resign: Return `investmentAmount` (break even)
  - **Card Handling:**
    - Card kept by player during dice rolling
    - After resolution, card can be discarded or kept (clarify with user)

---

## 🔧 Implementation Requirements Summary

### Cards Requiring Dice System:
- **LOTTERY1** (ISHOP_01-02): Single D6 roll
- **LOTTERY2** (ISHOP_03-04): Single D6 roll
- **STOCK** (ISHOP_13-14): Double D6 roll with comparison

### Cards Requiring Interactive Buttons (Choice/Input):
- **ESTATEINVEST** (ISHOP_06-07): Choose payment method (60% now vs 3×30%)
- **DEBENTURES** (ISHOP_08): Counter for investment amount, cash out buttons
- **LOAN** (ISHOP_10-11): Counter for loan amount
- **ENDOWMENT** (ISHOP_12): Choose duration (2/3/4 years) + counter for amount
- **STOCK** (ISHOP_13-14): Counter for amount + dice roll buttons + resign button

### Cards Requiring Multi-Turn State Tracking:
- **ESTATEINVEST**: Track payment progress, apartment delivery
- **DEBENTURES**: Track 3 payments, profit payout after 3 turns
- **LOAN**: Track 4 instalments, end-of-game balance check
- **ENDOWMENT**: Track payments over 2-4 turns, profit payout after duration

### Cards Requiring Cost Calculator Integration:
- **ESTATEINVEST** (3×30% option): 3 payments added to cost calculator
- **DEBENTURES**: 3 payments (same amount each) added to cost calculator
- **LOAN**: 4 instalments (33% each) added to cost calculator
- **ENDOWMENT**: Payments over 2-4 turns added to cost calculator

### Cards Kept by Player (Like Hi-Tech):
- **DEBENTURES**: Card stays with player, has buttons for cash out
- **ENDOWMENT**: Card stays with player, button appears after duration
- **STOCK**: Card stays with player during dice rolling
- **PROPINSURANCE**: Card kept (when implemented) - protects items/money
- **HEALTHINSURANCE**: Card kept (when implemented) - provides insurance benefits

---

## 📊 Implementation Priority

### Phase 1: Simple Dice Cards (Easiest)
1. **LOTTERY1** (ISHOP_01-02)
2. **LOTTERY2** (ISHOP_03-04)
   - Both use existing dice system pattern
   - No state tracking needed
   - Simple payout logic

### Phase 2: Interactive Cards with Multi-Turn Tracking
3. **DEBENTURES** (ISHOP_08)
   - Interactive counter + multi-turn payments + cash out buttons
4. **LOAN** (ISHOP_10-11)
   - Interactive counter + multi-turn payments + end-game check
5. **ENDOWMENT** (ISHOP_12)
   - Duration choice + counter + multi-turn payments + profit calculation

### Phase 3: Complex Interactive Cards
6. **ESTATEINVEST** (ISHOP_06-07)
   - Integration with Estate Engine
   - Apartment delivery after payments
   - Payment loss mechanics
7. **STOCK** (ISHOP_13-14)
   - Double dice roll system
   - Resign mechanics
   - Complex result calculation

### Phase 4: Future Implementation
8. **PROPINSURANCE** (ISHOP_05) - Requires theft/repair system
9. **HEALTHINSURANCE** (ISHOP_09) - Requires work/job system

---

## 💾 State Tracking Structure

```lua
-- Investment state (per player)
investments[color] = {
  -- Real Estate Investment
  estateInvest = {
    cardGUID = "...",
    method = "60pct" or "3x30pct",
    level = "L1",  -- L1, L2, L3, L4
    totalValue = 2000,  -- Full apartment price
    paidCount = 0,  -- 0-3 (for 3x30pct)
    paidAmount = 0,  -- Total paid so far
  },
  
  -- Debentures
  debentures = {
    cardGUID = "...",
    investedPerTurn = 200,  -- Amount per payment
    paidCount = 0,  -- 0-3
    totalInvested = 0,  -- Sum of all payments
  },
  
  -- Loan
  loan = {
    amountBorrowed = 1500,
    instalmentAmount = 500,  -- 33% of borrowed
    paidInstalments = 0,  -- 0-4
  },
  
  -- Endowment
  endowment = {
    cardGUID = "...",
    duration = 3,  -- 2, 3, or 4 years
    amountPerYear = 500,
    paidCount = 0,  -- 0-duration
    totalInvested = 0,
  },
  
  -- Stock
  stock = {
    cardGUID = "...",
    investmentAmount = 500,
    firstRoll = nil,  -- 1-6 or nil
    secondRoll = nil,  -- 1-6 or nil
    resolved = false,
  },
}
```

---

## 🎮 User Interaction Flow Examples

### DEBENTURES Purchase Flow:
1. Player clicks ISHOP_08 in shop
2. Shop shows: "-50 | AMOUNT: 0 | +50 | OK"
3. Player clicks +50 twice → AMOUNT: 100
4. Player clicks OK
5. System charges 100 WIN, adds 100 to cost calculator
6. Card given to player with button: "TAKE OUT CASH NOW"
7. Next 2 turns: 100 WIN added to cost calculator automatically
8. After 3 payments: Button changes to "CASH OUT (WITH PROFIT)"
9. Player clicks → Receives 600 WIN (300 invested + 300 profit)

### ENDOWMENT Purchase Flow:
1. Player clicks ISHOP_12 in shop
2. Shop shows buttons: "2 YEARS (50%)" | "3 YEARS (125%)" | "4 YEARS (200%)"
3. Player clicks "3 YEARS"
4. Shop shows counter: "-50 | AMOUNT: 0 | +50 | OK"
5. Player sets amount to 500, clicks OK
6. System charges 500 WIN (first payment), adds 500 to cost calculator
7. Card given to player
8. Next 2 turns: 500 WIN added to cost calculator automatically
9. After 3 payments: Button appears: "CASH OUT (225%)"
10. Player clicks → Receives 3,375 WIN (1,500 invested + 1,875 profit)

---

**Generated:** Based on user specifications  
**Next Step:** Awaiting implementation approval
