# Vocations System - Analysis Documentation

**Status:** IN PROGRESS - Receiving information in parts  
**Last Updated:** 2026-01-XX  
**Purpose:** Document Vocations system mechanics before implementation

---

## 📋 Overview

The **Vocations System** is a critical foundational mechanic that determines each player's profession/career path during the Adult period. It affects:
- Work income (salary per AP spent)
- Promotion requirements (Knowledge/Skills needed)
- Special talents/abilities per level
- VE (Vocational Events) card interactions
- Work bonus calculations

**Key Principle:** Each player chooses ONE vocation at the start of Adult period. Vocations are **exclusive** (cannot be chosen by multiple players).

---

## 🎯 Phase Structure

### Youth Period
- **Purpose:** Tutorial-like phase
- **Main Task:** Gather Knowledge and Skill points
- **Why Important:** Knowledge/Skills are needed for vocation promotions later
- **Access:** Youth Board available (easier to gain Knowledge/Skills)
- **Note:** Youth Board will be hidden during Adult period (currently visible for development)

### Adult Period
- **Purpose:** Main gameplay phase
- **Vocation Selection:** Happens at the beginning of Adult period
- **Access:** Youth Board NOT available (players can still gain Knowledge/Skills, but harder)
- **Development Note:** All elements currently visible for development, will be hidden later

---

## 🎲 Vocation Selection Mechanics

### Selection Order Rules

**If starting from Youth period:**
1. Calculate "Science Points" = Knowledge + Skills (combined total)
2. Player with **highest Science Points** chooses vocation first
3. **Tie-breaker:** Turn order (earlier player in turn order chooses first if Science Points are equal)

**If starting from Adult period:**
1. Players receive **bonus Knowledge/Skills** at start (equivalent to what they would have gained during Youth)
2. Players distribute these bonus points themselves (can allocate to Knowledge or Skills)
3. Calculate "Science Points" = Knowledge + Skills (including bonuses)
4. Player with **highest Science Points** chooses vocation first
5. **Tie-breaker:** Turn order (earlier player in turn order chooses first if Science Points are equal)

**Important:** Selection is **exclusive** - once a vocation is chosen, it cannot be chosen by another player.

---

## 👔 The Six Vocations

1. **Public Servant** ✅ (Details provided)
2. **Celebrity** ✅ (Details provided)
3. **Social Worker** ✅ (Details provided)
4. **Gangster** ✅ (Details provided)
5. **Entrepreneur** ✅ (Details provided)
6. **NGO Worker** ✅ (Details provided)

**Status:** ✅ All detailed mechanics received - see detailed sections below.

---

## 📊 Detailed Vocation Information

### Icon Mapping (Common to All Cards)
- **Book icon** = Knowledge requirement
- **Diamond icon** = Skill requirement
- **Clock / "X years"** = Experience requirement
- **"You need all 3 for a promotion"** = Knowledge + Skill + Experience/award condition

---

### 1. PUBLIC SERVANT

#### Level 1 – Junior Clerk
- **Salary:** +100 VIN/AP
- **Promotion Requirements:** Knowledge 8, Skills 4, Experience 2 years ("You need all 3 for a promotion")
- **Level Perks (Always-On):**
  - Free access to Health Monitor (keeps it for whole game)
  - 50% discount on all Consumable cards
  - **Obligation:** Must work 2–4 AP/year* (footnote: "*no promotion this year" if not met)
- **Level Action:** Yearly income tax collection campaign
  - **Cost:** Spend 2 AP
  - **D6 Outcomes:**
    - 1–2: Some documents were missing → no taxes collected
    - 3–4: Each player pays 15% of their cash to bank; you gain +1 Satisfaction
    - 5–6: Each player pays 30% of their cash to bank; you gain +3 Satisfaction
  - **Extra Rule:** "Due to his mastery of administrative law, the Public Servant can waive his own tax obligation once each level."

#### Level 2 – Administrative Officer
- **Salary:** +200 VIN/AP
- **Promotion Requirements:** Knowledge 12, Skills 6, Experience 3 years
- **Level Perks:**
  - Free access to Anti-Burglary Alarm (keeps it for whole game)
  - 50% discount on all Consumables
  - **Obligation:** Must work 2–4 AP/year* (footnote: "*-1 Satisfaction per missing/extra AP at work & no promotion this year")
- **Level Action:** Hi-tech tax collection campaign
  - **Cost:** Spend 2 AP
  - **D6 Outcomes:**
    - 1–2: Some documents were missing → no taxes collected
    - 3–4: Each player pays 200 VIN per High-Tech item to bank; you gain +2 Satisfaction
    - 5–6: Each player pays 400 VIN per High-Tech item to bank; you gain +4 Satisfaction
  - **Waive Rule:** Same as Level 1 (waive own tax once each level)

#### Level 3 – Office Director
- **Salary:** +300 VIN/AP
- **Promotion Requirement (Award-Based):** Knowledge 15, Skills 7, and Award*
  - **Award Condition:** "Successfully collect taxes TWO times at any level"
- **Level Perks:**
  - Free access to New Car (keeps it for whole game)
  - 50% discount on all Consumables
  - **Obligation:** Must work 2–4 AP/year* (footnote: "*-2 Satisfaction per missing/extra AP at work & no award this year")
- **Level Action:** Property tax collection campaign
  - **Cost:** Spend 2 AP
  - **D6 Outcomes:**
    - 1–2: Some documents were missing → no taxes collected
    - 3–4: Each player pays 200 VIN per level of property to bank; you gain +3 Satisfaction
    - 5–6: Each player pays 400 VIN per level of property to bank; you gain +6 Satisfaction
  - **Waive Rule:** Same as above

#### Public Servant – Special Events
- **Special Action 1: Policy Drafting Deadline**
  - **Cost:** -1 Health, -3 AP
  - **Gain:** +5 Satisfaction, +1 Knowledge

- **Special Action 2: Bureaucratic Bottleneck**
  - **Cost:** Spend 3 AP
  - **D6 Outcomes:**
    - 1–2: You failed, system collapsed → All other players lose 2 AP; you lose 2 Satisfaction
    - 3–4: You tried a lot but didn't manage to change anything → No effect
    - 5–6: You did it! Reformed the whole system → You gain +7 Satisfaction, all other players gain +2 Satisfaction

---

### 2. NGO WORKER

#### Level 1 – NGO Volunteer
- **Salary:** +80 VIN/AP
- **Promotion Requirements:** Knowledge 7, Skills 5, Experience 3 years
- **Level Perk:** Once on your turn, you can take one "Good Karma" card for free (no time/money), only once.
- **Back Actions:**
  1. **Start the charity**
     - **Cost:** Spend 2 AP
     - **D6 Outcomes:**
       - 1–2: Nothing happens
       - 3–4: Each player pays 200 VIN
       - 5–6: Each player pays 400 VIN and you get a 400 VIN reward
  2. **Voluntary work**
     - "Unpaid but brings you satisfaction"
     - **Cost:** -2 AP → **Gain:** +1 Satisfaction

#### Level 2 – Project Coordinator
- **Salary:** +240 VIN/AP
- **Promotion Requirements:** Knowledge 11, Skills 9, Experience 2 years
- **Level Perk:** Once on your turn, take one "Trip" card for free (no time/money), only once.
- **Back Actions:**
  1. **Start the crowdfunding campaign**
     - **Cost:** Spend 2 AP
     - **D6 Outcomes:**
       - 1–2: Nothing happens
       - 3–4: Each player pays 250 VIN
       - 5–6: Each player pays 400 VIN; you must spend this money in the shop to buy a High-Tech item
  2. **Voluntary work**
     - **Cost:** -3 AP → **Gain:** +2 Satisfaction

#### Level 3 – NGO Owner
- **Salary:** +450 VIN/AP
- **Promotion Requirement (Award-Based):** Knowledge 12, Skills 10, Award*
  - **Award Condition:** Complete 2 social campaigns OR 1 social campaign + 10 AP volunteering work
- **Level Perk:** Once on your turn, take one "Investment" card for free (no time/money), only once.
- **Back Actions:**
  1. **Advocacy Pressure Campaign**
     - **Cost:** Spend 3 AP
     - **Other players choose YES or NO:**
       - YES: They pay 300 VIN and gain +2 Satisfaction; you gain +1 Satisfaction per participant
       - NO: They lose 1 Satisfaction; you gain +1 Skill once per campaign
  2. **Voluntary work**
     - **Cost:** -1 AP → **Gain:** +1 Satisfaction

#### NGO Worker – Special Events
- **Special Action 1: International Crisis Appeal**
  - **Cost:** -1 AP, -200 VIN
  - Each other player chooses:
    - **Join:** donate 200 VIN, gain +2 Satisfaction
    - **OR ignore**
  - **Your gain:** +2 Satisfaction for each joiner and +1 Satisfaction per refuser

- **Special Action 2: Misused Donation Scandal**
  - **Cost:** -2 AP, -300 VIN
  - **D6 Outcomes:**
    - 1–2: Donor accuses you publicly → -3 Satisfaction
    - 3–4: Issue resolved quietly → +4 Satisfaction
    - 5–6: Donor apologizes publicly → +6 Satisfaction & +1 Knowledge

---

### 3. ENTREPRENEUR

#### Level 1 – Shop Assistant
- **Salary:** +150 VIN/AP
- **Promotion Requirements:** Knowledge 7, Skills 8, Experience 2 years
- **Front Perk/Action:** Spend 1 AP to talk to shop owner → double prices for 1 turn for other players.
- **Back Actions:**
  - **Passive:** After every turn when you have the biggest amount of money → +1 Satisfaction
  - **Action: Flash Sale Promotion**
    - **Cost:** Spend 1 AP
    - Every player may immediately buy one Consumable with 30% discount
    - You buy first; after each player buys, shop shelf refills
    - You gain +1 Satisfaction per other player who buys during this Flash Sale

#### Level 2 – Manager
- **Salary:** +300 VIN/AP
- **Promotion Requirements:** Knowledge 7, Skills 11, Experience 3 years
- **Front Talent:** Spend 1 AP to use your network → yourself or another player rerolls a die
- **Back Actions:**
  - **Passive:** If you have the biggest amount of money → +1 Satisfaction
  - **Action: Commercial Training Course**
    - **Cost:** Spend 2 AP
    - Others can improve Knowledge or Skills; each player may pay 200 VIN to participate; you gain +1 Satisfaction per participant
    - **"Exam time!" D6 Outcomes:**
      - 1: Failed → no learning
      - 2–5: Passed → +1 Knowledge OR +1 Skill
      - 6: Genius → +2 Knowledge OR +2 Skills

#### Level 3 – Hi-Tech Company Owner
- **Salary:** +500 VIN/AP
- **Promotion Requirement (Award-Based):** Knowledge 9, Skills 13, Award*
  - **Award Condition:** Buy a level 3 or level 4 house + 2 High-Tech items
- **Front Action:** During your turn, spend 2 AP to change place of max 3 event cards in the event lane
- **Back Actions:**
  - **Passive:** If you have the biggest amount of money → +2 Satisfaction
  - **Passive:** 25% discount on properties (can stack with discount card)

#### Entrepreneur – Special Events
- **Special Action 1: Aggressive Expansion**
  - **Cost:** -2 AP, -300 VIN
  - **D6 Outcomes:**
    - Collapse → -2 Satisfaction & -200 VIN
    - Moderate growth → +3 Satisfaction
    - Massive success → +6 Satisfaction & +800 VIN

- **Special Action 2: Employee Training Boost**
  - **Cost:** Spend 2 AP and 500 VIN
  - **Gain:** +2 Satisfaction, +2 Skills

---

### 4. GANGSTER

#### Level 1 – Thug
- **Salary:** +80 VIN/AP
- **Promotion Requirements:** Knowledge 3, Skills 10, Experience 3 years
- **Front Action:** Spend 3 AP to steal one High-Tech item from the shop
  - **D6 Outcomes:**
    - 1–2: Fail → nothing
    - 3–4: Partial success → police can investigate
    - 5–6: Full success → police can't even start investigation
- **Back Action: Crime against another player**
  - **Cost:** Spend 2 AP
  - **D6 Outcomes:**
    - 1–2: You failed
    - 3–4: Target gets WOUNDED and you steal 300 VIN
    - 5–6: Target gets WOUNDED and you steal the selected High-Tech item OR 500 VIN
  - **Satisfaction Rules:**
    - "Every successful crime makes you happy" = amount on D6 = amount of satisfaction
    - "Every successful crime on another player makes them unhappy"
    - Victim rolls by themselves: 1-2-3 = -3 satisfaction / 4-5-6 = -5 satisfaction

#### Level 2 – Gangster
- **Salary:** +200 VIN/AP
- **Promotion Requirements:** Knowledge 8, Skills 11, Experience 2 years
- **Front Action:** Spend 3 AP to commit a crime and produce false money
  - **D6 Outcomes:**
    - 1–2: Fail → nothing
    - 3–4: Success → gain 1000 VIN
    - 5–6: Great success → gain 2000 VIN
- **Back Action: Crime against another player**
  - **Cost:** 2 AP
  - **Outcomes:**
    - Fail
    - WOUNDED + steal 750 VIN
    - WOUNDED + steal selected High-Tech item OR 1000 VIN

#### Level 3 – Head of the Gang
- **Salary:** +450 VIN/AP
- **Promotion Requirement (Award-Based):** Knowledge 9, Skills 13, Award*
  - **Award Condition:** Commit 2 crimes without getting caught (or complete 3 including getting caught once)
- **Front Action:** Spend 2 AP to enforce citywide lockdown → all opponents start next turn with -1 AP
- **Front Extra:** "Your crew brings in cash – roll to see how much"
  - **D6 Outcomes:**
    - 1–2: Gain 200 VIN
    - 3–4: Gain 500 VIN
    - 5–6: Gain 1000 VIN & +2 Satisfaction
- **Back Action: Crime against another player**
  - **Cost:** 2 AP
  - **Outcomes:**
    - Fail
    - WOUNDED + steal 1500 VIN
    - WOUNDED + steal selected High-Tech item OR 2000 VIN

#### Gangster – Special Events
- **Special Action 1: Robin Hood Job**
  - **Cost:** Spend 2 AP
  - **D6 Outcomes:**
    - 1–2: Plan leaks → pay 200 VIN to bank and -2 Satisfaction
    - 3–4: Steal+donate up to 500 VIN → gain +4 Satisfaction
    - 5–6: Steal+donate up to 1000 VIN → gain +7 Satisfaction

- **Special Action 2: Protection Racket**
  - **Cost:** Spend 3 AP
  - Each other player chooses:
    - **Pay:** they spend 200 VIN per vocation level; you gain +1 Satisfaction per payer and keep the money
    - **Refuse:** they lose -2 Health & -2 Satisfaction
  - **Also:** "This event raises heat level by 1"

---

### 5. CELEBRITY

#### Level 1 – Aspiring Streamer
- **Salary:** +30 VIN/AP
- **Promotion Requirements:** Knowledge 3, Skills 8, plus work for 10 AP on this level
- **Perk:** After buying any High-Tech item, you receive 30% of its price back next round
- **Back Action: Live Street Performance stream**
  - **Cost:** Spend 2 AP to prepare & launch
  - Others may join by spending 1 AP each
  - If no one joins → no effect
  - Each participant gains +2 Satisfaction
  - If someone participated → Celebrity gains +1 Skill & +150 VIN
  - **D6:** 1-2-3 = +2 satisfaction / 4-5-6 = +4 satisfaction

#### Level 2 – Rising Influencer
- **Salary:** +150 VIN/AP
- **Promotion Requirements:** Knowledge 5, Skills 12, and work for 10 AP on this level
- **Perk:** After buying any High-Tech item, you receive 50% of its price back next round
- **Back Action: Meet & Greet**
  - **Cost:** Spend 1 AP and 200 VIN
  - Others may join by spending 1 AP + 200 VIN each
  - If no one joins → you lose satisfaction (card shows -2 / -4 outcomes)
  - If someone participated → they gain +1 Knowledge & +1 Satisfaction
  - If someone joined: you get satisfaction based on D6 roll: 1-2-3 = +3 / 4-5-6 = +5
  - **Obligation Rule:** Must take at least 1 event card per turn or lose 3 Satisfaction

#### Level 3 – Superstar Icon
- **Salary:** +800 VIN/AP
- **Promotion Requirements:** Knowledge 7, Skills 15, and work for 10 AP on this level & pay 4000 VIN
- **Perk:** After buying any High-Tech item, you receive 70% of its price back next round
- **Back Action: Extended Charity Stream**
  - **Cost:** Spend 2 AP
  - Other players may join multiple times by paying 500 VIN each time
  - For each donation:
    - Donor gains +2 Satisfaction
    - Celebrity gains +2 Satisfaction
    - Celebrity receives NO money
    - Celebrity gains +1 AP obligation
  - **Obligation Rule:** Must take at least two event cards per turn (Celebrity action counts as only one). Each missing event → -3 Satisfaction
  - If Celebrity cannot fulfill all AP obligations → stream collapses; Celebrity loses -4 Satisfaction per missing AP

#### Celebrity – Special Events
- **Special Action 1: Fan Talent Collaboration**
  - **Cost:** Spend 3 AP & 200 VIN
  - **You get:** +4 Satisfaction & +1 Skill
  - Each other player may voluntarily spend 2 AP to support; if they do, they gain +1 Knowledge & +2 Satisfaction
  - If someone supports, Celebrity gets +2 additional Satisfaction (once)

- **Special Action 2: Fan Meetup Backfire**
  - **Cost:** Spend 2 AP & 200 VIN
  - **D6 Outcomes:**
    - 1–2: Chaos & backlash → -1 Health & -2 Satisfaction
    - 3–4: Nice but could be better → +3 Satisfaction
    - 5–6: Enormous love → +7 Satisfaction & +300 VIN

---

### 6. SOCIAL WORKER

#### Level 1 – Community Assistant
- **Salary:** +70 VIN/AP
- **Promotion Requirements:** Knowledge 6, Skills 6, Experience 2 years
- **Perks:**
  - Pay only 50% rent for any rented apartment
  - Once in the game, may use Good Karma without having a card
- **Back Action: Practical workshop**
  - **Cost:** Spend 2 AP
  - Others may join by spending 1 AP
  - If no one joins → no effect
  - Each participating player gains +1 Knowledge OR +1 Skill
  - You gain +1 Satisfaction per participant
  - If all other players join → you gain +1 additional Satisfaction & +1 Skill

#### Level 2 – Family Care Specialist
- **Salary:** +150 VIN/AP
- **Promotion Requirements:** Knowledge 9, Skills 9, Experience 2 years
- **Perks:**
  - Pay only 50% rent
  - Once in the game, may take one Consumable from shop for free
- **Back Action: Community wellbeing session**
  - **Cost:** Spend 2 AP
  - Others may join by spending 1 AP
  - If no one joins → no effect
  - Each participating player gains +2 Satisfaction
  - You gain +1 Satisfaction per participant
  - If any player joins → you gain +2 additional Satisfaction

#### Level 3 – Senior Social Protector
- **Salary:** +250 VIN/AP
- **Award Condition:** "Successfully conduct TWO community events with at least ONE participant each"
- **Perks:**
  - Pay only 50% rent
  - Once in game: take one High-Tech item from shop for free
- **Back Action: Expose a disturbing social case**
  - **Cost:** Spend 3 AP
  - All other players must choose:
    - **Engage deeply** → gain +1 Knowledge and -2 Satisfaction
    - **OR stay ignorant** → gain +1 Satisfaction
  - You gain +3 Satisfaction "for bringing the truth to light and forcing public accountability"

#### Social Worker – Special Events
- **Special Action 1: Homeless Shelter Breakthrough**
  - **Cost:** Spend 2 AP & 100 VIN
  - **D6 Outcomes:**
    - 1–2: Leave before intake finishes → -1 Satisfaction
    - 3–4: Accept temporary shelter → +3 Satisfaction
    - 5–6: Enter long-term support → +7 Satisfaction & +1 Skill

- **Special Action 2: Forced Protective Removal**
  - **Cost:** Spend 3 AP and choose a player who has at least one child to investigate
  - **D6 Outcomes:**
    - 1–2: False alarm / wrongful intervention → you lose -1 Health & -2 Satisfaction; victim gets +3 Satisfaction
    - 3–4: Temporary intervention: child removed for 1 year; parent still pays cost but gains no Satisfaction and spends no AP on the child → you gain +3 Satisfaction
    - 5–6: Permanent removal: child placed in state care permanently; parent loses -6 Satisfaction and no longer pays/spends AP/gains Satisfaction from this child → you gain +4 Satisfaction

---

## 📊 Vocation Structure

### Three-Level Progression System

Each vocation has **3 levels** of advancement:
- **Level 1** (Entry level)
- **Level 2** (Mid-level)
- **Level 3** (Highest level)

### Level Components

Each level has:
1. **Job Title** (e.g., "Shop Assistant", "Manager", "High-Tech Company Owner")
2. **Salary** (money earned per Action Point spent on work)
3. **Promotion Requirements** (Knowledge and Skills needed to advance to next level)
4. **Special Talents** (unique abilities available at this level)

---

## 💰 Work & Salary System

### How Work Income Works

- Players can spend **multiple Action Points** on work during each turn
- **Salary = Money per AP spent on work**
- Salary **varies by vocation and level**

### Salary Summary (All Vocations)

| Vocation | Level 1 | Level 2 | Level 3 |
|----------|---------|---------|---------|
| **Public Servant** | 100 VIN/AP | 200 VIN/AP | 300 VIN/AP |
| **NGO Worker** | 80 VIN/AP | 240 VIN/AP | 450 VIN/AP |
| **Entrepreneur** | 150 VIN/AP | 300 VIN/AP | 500 VIN/AP |
| **Gangster** | 80 VIN/AP | 200 VIN/AP | 450 VIN/AP |
| **Celebrity** | 30 VIN/AP | 150 VIN/AP | 800 VIN/AP |
| **Social Worker** | 70 VIN/AP | 150 VIN/AP | 250 VIN/AP |

**Example Calculation:**
- Entrepreneur Level 2 spends 3 AP on work
- Income = 3 AP × 300 VIN = **900 VIN**

---

## 🎁 Special Talents

Each vocation has **unique talents/abilities** that can be used during turns. Talents are **level-specific** (different talents at different levels).

### Examples Provided

**Social Worker (General):**
- Pay only **50% of rent** for any rented apartment

**Entrepreneur Level 2 (Manager):**
- Spend **1 AP** to use "Network" ability
- Allows self or another player to **reroll a die**

**Status:** More talents to be documented as information is provided.

---

## 🎴 VE (Vocational Events) Cards

**Total Cards:** 24 cards (AD_58 to AD_81)  
**Note:** These are "Vocational Events" cards, NOT "Volunteer Experience" - almost entirely based on vocations.

### Card Structure

Each VE card has **two sections:**

#### Top Section: Crime Opportunity
- **Mechanic:** Player can commit a crime against another player
- **Requires:** D6 die roll (luck-based)
- **Effects if successful:**
  - Steal money from target player
  - Make target player **WOUNDED**

#### Bottom Section: Special Vocation Actions
- **Mechanic:** Always **2 out of 6 vocations** can take special action
- **Which vocations:** Varies per card (different combinations)
- **Action Type:** Each vocation has **2 special actions** total

### Special Action Example: Entrepreneur

**Action Name:** "Aggressive Expansion"
- **Description:** Push to expand your business/office space
- **Cost:**
  - 2 Action Points
  - 300 WIN
- **Mechanic:** Roll die
- **Outcomes:**
  - **Fail:** Lose Satisfaction + additional funds
  - **Moderate Success:** Gain some Satisfaction + some money
  - **Great Success:** Gain a lot of Satisfaction + quite a lot of money

**Status:** All special actions for all vocations to be documented.

---

## 🔗 Connections to Other Systems

### Cards That Depend on Vocations

1. **AD_WORKBONUS** (3 cards: AD_32-34) - Adult deck
   - Work bonus calculation based on vocation
   - **Mechanic:** Player spends **1 AP on EVENT**, receives money equal to work for **4 AP**
   - **Example:** If player's vocation earns 300 WIN per AP, they get 4 × 300 = 1200 WIN for spending 1 AP
   - **Implementation:** Very easy after vocations are implemented
   - **Status:** Not yet implemented

2. **VE Cards** (24 cards: AD_58-81) - Adult deck
   - **Vocational Events** cards (NOT "Volunteer Experience")
   - Almost entirely based on vocations
   - Special actions for specific vocations
   - Crime opportunities
   - **Status:** Choice UI works, but actions not implemented
   - **Note:** Will be implemented at the end (after core vocations system)

3. **HEALTHINSURANCE** (1 card: ISHOP_09)
   - Similar to work bonus system
   - Needs to know how much money player earns per AP
   - **Implementation:** Easy after vocations are implemented
   - **Status:** Not yet implemented

### Cards That Do NOT Depend on Vocations

- **Youth WORK Cards** (YD_17-26, 10 cards) - Youth deck
  - These are **events**, not actual work
  - Part of Youth period when players don't have vocations yet
  - Simple AP → money conversion
  - **Status:** Already working, not connected to vocations

### Work System Integration

- **AP spent on WORK area** → Converted to money based on vocation + level salary
- **Work bonus cards (AD_WORKBONUS)** → Multiplies money per AP (once)
- **Insurance calculations (HEALTHINSURANCE)** → Uses vocation income for lost work calculations

---

## ✅ What Already Exists (Not Part of Vocations System)

### Youth Board
- **Status:** ✅ Exists and works
- **Note:** NOT part of Vocations system
- **Why:** Exists only in Youth period when players don't have vocations yet
- **Purpose:** Preparation for vocations (gathering Knowledge/Skills)
- **Final Version:** Will be hidden during Adult period

### AP Controller - Area Classification
- **Status:** ✅ Areas ARE established (WORK, SCHOOL/LEARNING)
- **How:** Tokens can move to these areas manually via buttons
- **Verification Needed:** Ensure other systems can query AP count in these areas
- **Action:** Check explicit mapping and verify systems can use it correctly

### Adult Board System
- **Status:** ✅ EXISTS
- **What:** Board with Shop and Estate Agency
- **Final Version:** Will NOT be available for Youth players
- **Note:** This is the "Adult Board" - already implemented

### Education Paths (VOC-SCH, HI-SCH, UNI, TECH-ACAD)
- **Status:** ✅ Exist in Youth Board
- **Note:** NOT connected to vocations at all
- **Purpose:** Just ways to raise Knowledge or Skills in different formats
- **Important:** Not needed for vocation development tracking

---

## ❓ Questions to Resolve (Pending Information)

### ✅ Vocation Details - COMPLETE

All 6 vocations have been fully documented with:
- ✅ Level 1-3 job titles
- ✅ Salary per level
- ✅ Promotion requirements (Knowledge/Skills/Experience/Awards)
- ✅ Special talents per level
- ✅ 2 special actions for VE cards

### System Mechanics Questions

1. **Promotion Mechanics:**
   - **Clarified from cards:** Promotions vary by vocation:
     - **Experience-based:** Some require "X years" (tracked via experience tokens)
     - **Work-based:** Some require "work for X AP on this level" (Celebrity: 10 AP per level)
     - **Award-based:** Level 3 often requires Award* with special condition (e.g., "Successfully collect taxes TWO times")
   - **Note:** "You need all 3 for a promotion" = Knowledge + Skill + Experience/Award
   - **Question:** Is promotion automatic when all requirements met, or does player choose when to promote?
   - **Question:** Does promotion cost anything (money, AP, etc.)?

2. **VE Card Distribution:**
   - Which 2 vocations can act on each VE card?
   - Is it random, or fixed per card?
   - How is this determined?
   - **Note:** Will be explained later (easy and brief explanation)

3. **Work Bonus Cards (AD_WORKBONUS):**
   - **Clarified:** Player spends 1 AP on EVENT, receives money equal to work for 4 AP
   - **Calculation:** `workBonus = vocationSalary × 4`
   - **Example:** If vocation earns 300 WIN per AP → bonus = 300 × 4 = 1200 WIN
   - ✅ **Resolved:** Simple calculation based on current vocation salary

4. **Crime Mechanics (VE Cards):**
   - What is the die roll threshold for successful crime?
   - How much money can be stolen?
   - Are there consequences for failed crime attempts?
   - **Note:** Will be resolved much later - not priority now (focus on vocations and SMARTPHONE first)

5. **SMARTPHONE Card:**
   - **Clarified:** Simple check at end of turn
   - Check if AP count in WORK + LEARNING areas ≥ 2
   - If yes: Grant +1 SAT
   - **No historical tracking needed** - just current state check

---

## 📝 Implementation Notes (For Later)

### What's Actually Missing

1. **Profession/Vocation Tracking:**
   - No system to track which vocation each player has chosen
   - No persistence of vocation choice
   - **Action:** Create VocationsController to track this

2. **AP Spending History (for Promotion):**
   - Some vocations need total AP spent on work across multiple turns
   - **Action:** Track AP spent on work per player (cumulative)

3. **Explicit Area Mapping Verification:**
   - WORK area = work activities
   - SCHOOL/LEARNING area = learning activities
   - **Action:** Verify systems can query AP count in these areas

### System Architecture

**Status:** ✅ **VocationsController created!**
- File: `VocationsController.lua` (to be created/implemented)
- Tag: `WLB_VOCATIONS_CTRL` ✅ (already added to object)
- Track per player:
  - Chosen vocation
  - Current level (1, 2, or 3)
  - Promotion progress (Knowledge/Skills toward next level)
  - **Total AP spent on work** (for promotion tracking)

### APIs Needed

- `VOC_GetVocation({color=...})` → returns vocation name
- `VOC_SetVocation({color=..., vocation=...})` → sets vocation (exclusive check)
- `VOC_GetLevel({color=...})` → returns current level (1, 2, or 3)
- `VOC_GetSalary({color=...})` → returns salary per AP for current level
- `VOC_CanPromote({color=...})` → checks if player meets promotion requirements
- `VOC_Promote({color=...})` → advances player to next level
- `VOC_GetTalents({color=...})` → returns available talents for current level
- `VOC_CalculateWorkBonus({color=...})` → calculates work bonus multiplier for AD_WORKBONUS cards
- `VOC_CanUseVEAction({color=..., cardId=...})` → checks if player's vocation can use VE card action
- `VOC_AddWorkAP({color=..., amount=...})` → tracks AP spent on work (for promotion)
- `VOC_GetTotalWorkAP({color=...})` → returns total AP spent on work (cumulative)

### Integration Points

1. **Turn Controller:**
   - Vocation selection at start of Adult period
   - Calculate selection order (Science Points + turn order)

2. **Event Engine:**
   - AD_WORKBONUS cards → Query vocation for bonus calculation
   - VE cards → Check if player's vocation can use special action
   - Apply special action effects

3. **Shop Engine:**
   - HEALTHINSURANCE → May need vocation income for calculations

4. **AP Controller:**
   - Work income calculation when AP spent on WORK area
   - Query AP count in WORK and SCHOOL/LEARNING areas (for SMARTPHONE check)
   - Track AP spent on work (for promotion system)

5. **Stats Controller:**
   - Track Knowledge/Skills for promotion requirements

---

## 🔄 Next Steps

1. **Wait for more information** about:
   - Complete details for all 6 vocations
   - Promotion mechanics
   - All special talents
   - All special actions (2 per vocation = 12 total)
   - VE card distribution rules

2. **Update this document** as information is received

3. **Once complete:** Create implementation plan based on full understanding

---

---

## 📝 Corrections Applied

### ✅ Corrected Understanding

1. **Youth Board:** NOT part of vocations system - exists only in Youth when no vocations exist
2. **AP Controller:** Areas ARE established (WORK, SCHOOL/LEARNING) - just need verification
3. **Youth WORK Cards:** NOT work - they're events during Youth period
4. **Education Paths:** NOT needed for vocations - just ways to raise Knowledge/Skills
5. **Adult Board:** EXISTS (Shop + Estate Agency) - already implemented
6. **Work Bonus:** Easy - just multiplies money per AP (once)
7. **SMARTPHONE:** Simple - check current AP count in WORK + LEARNING at end of turn (≥2 = +1 SAT)
8. **AP Spending History:** NOT needed for SMARTPHONE, BUT needed for promotion tracking
9. **VE Cards:** "Vocational Events" (NOT "Volunteer Experience") - implement at end
10. **Youth WORK Cards:** NOT dependent on vocations

---

---

## 📝 Updates & Clarifications

### ✅ Work Bonus Cards (AD_WORKBONUS) - Clarified
- **Mechanic:** Player spends **1 AP on EVENT**, receives money equal to work for **4 AP**
- **Formula:** `bonus = vocationSalary × 4`
- **Example:** Vocation earns 300 WIN/AP → bonus = 1200 WIN for 1 AP spent

### ✅ VocationsController Status
- **Created:** ✅ Object exists with tag `WLB_VOCATIONS_CTRL`
- **Next:** Implementation will begin after receiving all vocation details

### 📅 Information Timeline
- **Now:** Detailed information about each vocation (one by one)
- **Later:** Special event actions (VE cards) - full descriptions
- **Later:** VE card distribution explanation (easy and brief)
- **Much Later:** Crime mechanics (not priority now)

---

---

## 📋 Implementation Notes from Vocation Cards

### Promotion Types Identified

1. **Standard Promotion (Level 1→2, Level 2→3):**
   - Requires: Knowledge + Skills + Experience (years)
   - Example: Public Servant L1→L2: Knowledge 8, Skills 4, Experience 2 years

2. **Work-Based Promotion:**
   - Requires: Knowledge + Skills + "work for X AP on this level"
   - Example: Celebrity all levels require "work for 10 AP on this level"
   - **Needs:** Track AP spent on work per level (cumulative)

3. **Award-Based Promotion (Level 3):**
   - Requires: Knowledge + Skills + Award* (special condition)
   - Examples:
     - Public Servant: "Successfully collect taxes TWO times at any level"
     - Entrepreneur: "Buy a level 3 or level 4 house + 2 High-Tech items"
     - Gangster: "Commit 2 crimes without getting caught"
     - Social Worker: "Successfully conduct TWO community events with at least ONE participant each"
     - NGO Worker: "Complete 2 social campaigns OR 1 social campaign + 10 AP volunteering work"

### Obligations Identified

1. **Public Servant:** Must work 2–4 AP/year (penalty if not met)
2. **Celebrity:** Must take event cards per turn (penalty if not met)
   - Level 2: At least 1 event card per turn
   - Level 3: At least 2 event cards per turn

### Special Mechanics

1. **Gangster Crime System:** Scales by level (money stolen increases: 300→750→1500 VIN)
2. **Celebrity Hi-Tech Rebate:** Percentage increases by level (30%→50%→70%)
3. **Public Servant Tax Waiver:** Can waive own tax obligation once per level
4. **Heat Level (Gangster):** Some actions raise "heat level by 1" (system to be implemented)

---

---

## 🎮 Player Interaction System

**Status:** ⏸️ **Documented for future implementation**

A separate system (`InteractionController`) will be needed to handle multi-player choices during vocation actions. This is documented in `PLAYER_INTERACTION_SYSTEM_PROPOSAL.md`.

**Key Points:**
- Central tile with color-coded buttons
- 30-second timeout, default to NO
- Sequential choices with cascading timer (Celebrity charity stream)
- Will work alongside EventEngine (not replace it)
- **Timeline:** Implement after vocations system is working

---

**Document Status:** ✅ All vocation details received and documented  
**Next:** Awaiting VE card distribution explanation and any clarifications on promotion mechanics
