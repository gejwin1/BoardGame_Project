# Work-Life Balance Board Game - Project Documentation

Complete project documentation for the Work-Life Balance board game development.

**Last Updated**: February 14, 2026

---

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Game Overview](#game-overview)
3. [Game Mechanics](#game-mechanics)
4. [Glossary](#glossary)
5. [First Tasks for Contributors](#first-tasks-for-contributors)
6. [Project Status](#project-status)

---

# Quick Start Guide

Welcome! This guide will help you get started with the Work-Life Balance board game project in about 15 minutes.

## 🎯 What You'll Learn

- How to open and navigate the project
- How to make your first change
- How to test changes in Tabletop Simulator
- Where to find more information

## ⏱️ 15-Minute Setup

### Step 1: Understand the Project (3 minutes)

**What is this?**
- A digital board game built in Tabletop Simulator
- Written in Lua scripting language
- 42 scripted objects managing game mechanics

**Key Concept:**
- We edit code in external files (this project)
- Then copy-paste into Tabletop Simulator
- TTS doesn't load external files directly, so we use copy-paste workflow

### Step 2: Prerequisites Check (2 minutes)

**Required:**
- ✅ Tabletop Simulator installed
- ✅ Access to the game save file
- ✅ This project folder open in Cursor (or any code editor)

**Helpful but not required:**
- Basic Lua knowledge (you can learn as you go)
- Understanding of board games

### Step 3: Make Your First Change (5 minutes)

Let's make a simple change to see how the workflow works:

1. **Open a simple script:**
   - Navigate to `scripts/object-scripts/`
   - Open `MoneyController_Shared.lua` (or any `*_DOC.md` file to see what it does)

2. **Find a display message:**
   - Look for text like `"MONEY = "` or similar UI text
   - This is what players see in the game

3. **Make a small change:**
   - Change the text slightly (e.g., add an emoji or change wording)
   - Save the file

4. **Copy to TTS:**
   - Select all (`Ctrl+A`)
   - Copy (`Ctrl+C`)
   - Open Tabletop Simulator
   - Right-click the Money token object
   - Go to Scripting tab
   - Select all existing code (`Ctrl+A`)
   - Paste your new code (`Ctrl+V`)
   - Click "Save & Apply"

5. **Test it:**
   - Load the game in TTS
   - Check if your change appears!

### Step 4: Understand the Workflow (5 minutes)

**Standard Development Cycle:**

```
1. Edit in Cursor (external file)
   ↓
2. Copy entire script (Ctrl+A, Ctrl+C)
   ↓
3. Paste into TTS object (Ctrl+V)
   ↓
4. Save & Apply in TTS
   ↓
5. Test in game
   ↓
6. Report back or iterate
```

**Important Rules:**
- ✅ **DO**: Edit in external files (Cursor)
- ✅ **DO**: Copy entire scripts (don't merge manually)
- ✅ **DO**: Test immediately after pasting
- ❌ **DON'T**: Edit directly in TTS (hard to track changes)
- ❌ **DON'T**: Mix external + TTS edits (one source of truth)

## 📚 Next Steps

Now that you've made your first change, here's what to explore:

### For Understanding the Game:
1. Read the [Game Overview](#game-overview) section below
2. Read the [Game Mechanics](#game-mechanics) section below
3. Play the game to understand how it works

### For Understanding the Code:
1. Browse `scripts/object-scripts/*_DOC.md` files for component details
2. Read `WORKFLOW_GUIDE.md` for detailed workflow instructions
3. Check `scripts/SCRIPTED_OBJECTS_CHECKLIST.md` for all components

### For Development:
1. Read `WORKFLOW_GUIDE.md` (detailed workflow instructions)
2. Check the [First Tasks](#first-tasks-for-contributors) section below for tasks to work on

## 🆘 Getting Help

**If something doesn't work:**
1. Check `WORKFLOW_GUIDE.md` FAQ section
2. Ask for help with specific error messages

**If you're confused:**
1. Start with the [Game Overview](#game-overview) section to understand what the game is
2. Look at existing `*_DOC.md` files for examples
3. Check the [Glossary](#glossary) section for terms

## ✅ Checklist

Before moving on, make sure you:
- [ ] Made your first code change
- [ ] Successfully copied it to TTS
- [ ] Tested it in the game
- [ ] Understand the copy-paste workflow
- [ ] Know where to find more documentation

---

# Game Overview

## Game Name
**Work-Life Balance (WLB)**

## Concept

Work-Life Balance is a **life simulation board game** where players navigate through different life stages, making choices that affect their resources, relationships, health, and personal satisfaction. Players must balance practical needs (money, career, education) with personal fulfillment (satisfaction, relationships, health).

## Core Theme

The game simulates the challenges of modern life:
- **Youth Phase**: Education, early career, relationships, exploration
- **Adult Phase**: Career advancement, family, financial management, life balance

Players experience:
- Resource management (money, time, energy)
- Life events (both positive and challenging)
- Decision-making with consequences
- Long-term planning vs. short-term satisfaction

## Gameplay Summary

### Basic Information
- **Players**: 2-4 players
- **Duration**: ~60-90 minutes
- **Age**: [To be determined]
- **Complexity**: Medium

### Game Structure
- **Total Rounds**: 13 rounds
- **Youth Phase**: Rounds 1-5 (ages ~18-25)
- **Adult Phase**: Rounds 6-13 (ages ~26-40)
- **Turn Structure**: Each player takes a turn per round

### Core Resources
Players manage:
1. **Money (WIN)**: Currency for purchases and expenses
2. **Satisfaction (SAT)**: Personal fulfillment (0-100 scale)
3. **Health**: Physical well-being (0-9 scale)
4. **Knowledge**: Education and learning (0-15 scale)
5. **Skills**: Practical abilities (0-15 scale)
6. **Action Points (AP)**: Time/energy for actions (12 per turn)

## What Makes It Unique

1. **Life Simulation Focus**: Not just resource management, but life choices and consequences
2. **Two-Phase Structure**: Distinct Youth and Adult phases with different challenges
3. **Satisfaction Mechanic**: Balancing practical needs with personal fulfillment
4. **Event-Driven Gameplay**: Life events create narrative and decision points
5. **Family System**: Marriage, children, and relationships affect gameplay
6. **Status Effects**: Health conditions, relationships, and life situations matter

## Game Modes

### Youth Start
- Begin at Round 1
- Start with basic resources
- Focus on education and early experiences
- Full game experience

### Adult Start
- Begin at Round 6
- Start with established resources
- Skip to adult phase
- Faster gameplay for experienced players

## Win Condition

**The winner is the player with the highest satisfaction at the end of the game.**

- Satisfaction is the only win condition
- No other ways to win the game
- Highest satisfaction score wins

## Key Game Systems

### 1. Turn System
- Players take turns in order
- Each turn: 12 Action Points to spend
- Turn ends when player chooses to end it (there is a physical button to end the turn)
- Turn naturally ends when player spends all AP

### 2. Event System
- Two decks of event cards: Youth Deck and Adult Deck
- Event cards are drawn each round and placed on the Event Track
- Players interact with event cards by spending AP
- Events affect resources, stats, and life situations
- **Note**: Vocation card abilities are NOT called "events" - they are "vocational abilities" or "activities"

### 3. Shop System
- Three shop types: Consumables, Hi-Tech, Investments
- Players can purchase items with money and AP
- Items provide various benefits

### 4. Estate System
- Players can rent or buy apartments/estates
- Higher levels provide better benefits
- Estates can house family members

### 5. Vocation System
- Players choose career paths
- Vocations affect available actions and income
- Career progression throughout the game

### 6. Status System
- Status system is connected to tokens that signalize various effects affecting the player
- Main purpose: Inform the player what's happening in the game and allow better planning
- Players can have status effects: Sick, Wounded, Addiction, etc.
- Statuses are represented by tokens on player boards
- Some are temporary, others persistent

## Current Development Status

### ✅ Implemented
- Core turn management system
- Event card system (Youth and Adult) – system works; most Adult cards implemented (obligatory, taxes, Hi-Tech Failure, etc.)
- Shop system (consumables, Hi-Tech, investments) with voucher discounts and Public Servant 50% consumable discount
- Estate/housing system
- Resource management (Money, AP, Stats, Satisfaction)
- Status effect system
- Token management system (including Experience tokens)
- Win condition (highest satisfaction wins)
- **Vocation system (core)** – selection at Adult start, work income via Costs Calculator, promotion (standard/work/award), tiles, summary UI
- **Public Servant (full flow)** – tax campaigns (L1/L2/L3), level perks (Health Monitor, Alarm, Car proxy tiles), 50% consumable discount, tax waiver once per level, work obligation 2–4 AP/year, experience tokens at round end
- **Overworking satisfaction loss** – end of turn: 0–2 AP work → 0, 3–4 → −1, 5–6 → −2, 7–8 → −3, 9 → −4 SAT; NGO Worker exempt
- **Hi-Tech Failure event** – one random hi-tech breaks, 25% repair cost, Repair button on broken card, block use when broken

### 🟡 In Progress
- Remaining vocation perks and actions (Celebrity cashback, Social Worker Good Karma/rent, Entrepreneur “double shop”, Gangster/NGO refinements)
- Award-based Level 3 promotions and “no special award this year” (Public Servant L3)
- Testing and balancing (ongoing process)

### 🔴 Planned
- Full award system for vocation Level 3
- Comprehensive playtesting
- Rulebook finalization

---

# Game Mechanics

This section explains the core game mechanics of Work-Life Balance.

## Action Points (AP) System

### Overview
**Action Points (AP)** represent time and energy. Players use AP to perform actions during their turn.

### AP Allocation
- **Starting AP**: Each player begins their turn with **12 AP**
- **AP Areas**: AP can be allocated to 5 different areas:
  - **Work (W)**: Career and job-related actions
  - **Rest (R)**: Rest and recovery actions
  - **Events (E)**: Interacting with event cards
  - **School (SC)**: Education and learning actions
  - **Inactive (I)**: Blocked or unavailable AP

### Spending AP
- Players spend AP by moving tokens from the **START** area to action areas
- Each action has an AP cost (e.g., "Spend 2 AP to work")
- AP cannot be spent if:
  - Not enough AP available (less than cost)
  - Target area has no available slots
  - Player doesn't meet action requirements

### AP Blocking
AP can be blocked (moved to Inactive) by:
- **Low Health**: 
  - Health ≤ 0: 6 AP blocked next turn
  - Health ≤ 3: 3 AP blocked next turn
  - Health ≤ 6: 1 AP blocked next turn
  - Health > 6: 0 AP blocked
- **Children**: Each child permanently blocks 2 AP
- **Status Effects**: Some statuses (like Addiction) can block AP temporarily

### Turn End
- Turn ends when player chooses to end it (there is a physical button to end the turn)
- Turn naturally ends when player spends all AP
- Players can end their turn with unspent AP (with confirmation)
- Unspent AP is lost (does not carry over)
- All AP resets to START at the beginning of next turn

## Turn Structure

### Turn Flow
1. **Turn Start**
   - Player receives 12 AP
   - Shop automatically refills empty slots
   - Any blocked AP is applied (from previous turn's health)
   - **Obligatory Cards Check**: If there is an obligatory card in the first slot (S1) of the Event Track, it must be resolved at the start of the turn

2. **Player Actions** (during turn)
   - Player spends AP on various actions
   - Can interact with events, shop, estates, etc.
   - Actions can be taken in any order
   - **Note**: If an obligatory card is in the first slot, it must be dealt with before other actions

3. **Turn End**
   - Player ends turn using the "End Turn" button (or turn ends naturally when all AP is spent)
   - **REST AP → Health**: Health changes based on Rest AP spent
   - **Health → Blocked AP**: Calculates AP blocking for next turn
   - **Status Expiration**: One-turn statuses (SICK, WOUNDED) are removed
   - Event track advances automatically

### Round Structure
- **13 rounds total** (Youth: rounds 1-5, Adult: rounds 6-13)
- Each round, all players take one turn in order
- After all players have taken turns, round advances
- Year Token tracks current round

## Resource Management

### Money (WIN)
- **Starting Money**: 200 (Youth mode)
- **Uses**: 
  - Purchase shop items
  - Pay for education (Technical Academy, University)
  - Pay monthly costs (via Costs Calculator)
  - Event card costs
- **Earning**: 
  - Work actions (Youth Board)
  - Event cards
  - Some shop cards (Investments)

### Satisfaction (SAT)
- **Range**: 0-100
- **Starting**: 10
- **Uses**: 
  - **Win condition**: Highest satisfaction at game end wins
  - Affects some event outcomes
- **Earning/Losing**:
  - Event cards (most common)
  - Shop purchases
  - Life choices

### Stats: Health, Knowledge, Skills

#### Health
- **Range**: 0-9
- **Starting**: 9
- **Effects**:
  - Low health blocks AP next turn
  - Health ≤ 0: Severe penalties
- **Gaining**:
  - Rest actions (REST AP → Health conversion)
  - Shop items (Supplements, Cure cards)
  - Event cards
- **Losing**:
  - Not enough Rest
  - Event cards (illness, accidents)
  - Status effects (SICK, WOUNDED)

#### Knowledge (K)
- **Range**: 0-15
- **Starting**: 0
- **Uses**: 
  - Education requirements
  - Some event outcomes
- **Gaining**:
  - Education actions (High School, University)
  - Shop items (Books)
  - Event cards

#### Skills (S)
- **Range**: 0-15
- **Starting**: 0
- **Uses**:
  - Career requirements
  - Some event outcomes
- **Gaining**:
  - Education actions (Vocational School, Technical Academy)
  - Shop items (Mentorship)
  - Event cards

## Event System

**Important**: "Events" specifically refers to the two decks of event cards (Youth Deck and Adult Deck). Vocation card abilities are NOT called "events" - they are called "vocational abilities" or "activities".

### Event Decks
- **Youth Deck (YD)**: 39 event cards (YD_01 to YD_39)
- **Adult Deck (AD)**: 81 event cards (AD_01 to AD_81)
- Events are drawn from the appropriate deck based on current game phase

### Event Track
- **7 slots** on the Event Board (S1-S7)
- Events are dealt from Youth or Adult deck based on current phase
- Players interact with event cards by spending AP

### Event Types
- **Instant**: Effect applied immediately, card discarded (most events are instant)
- **Keep**: Effect applied, card kept in player's area
  - **Note**: Currently there are only a few keep cards (mainly those with discounts)
  - Plans are to exchange all keep cards into statuses/tokens (similar to how Good Karma was converted from a keep card to a token)
  - Discount mechanics could be easily achieved through tokens and statuses
- **Obligatory**: Must be played, cannot be avoided **unless player uses Good Karma token**
  - If an obligatory card is in the first slot (S1) of the Event Track, it must be resolved at the start of the player's turn
  - Player cannot take other actions until the obligatory card is resolved
  - Good Karma token allows player to avoid one obligatory card

### Event Costs
- Events have AP costs (varies by card)
- **Slot Position Costs** (extra AP based on slot position):
  - **Slot 1 (S1)**: 0 AP extra
  - **Slots 2, 3 (S2, S3)**: 1 AP extra
  - **Slots 4, 5 (S4, S5)**: 2 AP extra
  - **Slots 6, 7 (S6, S7)**: 3 AP extra

### Event Effects
Event cards can affect:
- Money (gain or lose)
- Satisfaction (gain or lose)
- Stats (Health, Knowledge, Skills)
- AP (cost or bonus)
- Status effects (add or remove)
- Life events (marriage, children, etc.)

### Vocational Events
- **Vocational Events in Adult Deck**: There are specific vocational event cards in the Adult deck
- These cards can be played by one or two specific vocations
- Each vocation has prepared special activities for those vocational event cards
- **Crime System**: Besides vocational-specific activities, every vocation can use the same vocational event card but only for doing crimes against other players
  - Crimes are penalized
  - **Heat System**: With every crime, heat raises
  - **Police System**: Police can investigate crimes easier as heat rises
  - Punishments get bigger with rising heat

**Note**: Vocation cards also have their own abilities/activities (not events), but vocational events in the Adult deck ARE part of the Event System.

## Shop System

### Shop Types
Three shop rows with different card types:

1. **Consumables (C)**: 28 cards
   - Immediate effects (Cure, Books, Supplements, etc.)
   - One-time use items

2. **Hi-Tech (H)**: 14 cards
   - Technology items
   - Effects are implemented (most of them)

3. **Investments (I)**: 14 cards
   - Long-term investments
   - Effects are implemented (most of them)

### Shop Structure
- Each row has **4 slots**:
  - **1 CLOSED slot**: Deck position (face-down)
  - **3 OPEN slots**: Display cards (face-up, available for purchase)

### Purchasing
- **Entry Cost**: First purchase per turn costs **1 AP** (entry fee)
- **Card Cost**: Each card has money cost (and sometimes extra AP cost)
- **Purchase Process**:
  1. Click card in OPEN slot
  2. Modal appears: YES/NO confirmation
  3. If YES: Money and AP deducted, effect applied
  4. Card returned to deck (not destroyed)

### Shop Refill and Shuffle
- Shop automatically refills empty OPEN slots at start of each turn
- Cards drawn from deck randomly
- **Shuffle Option**: Each player can shuffle one of the rows (Consumables, Hi-Tech, or Investments) in their turn before buying something in the shop
- **Note**: RESET button exists for development/testing purposes but will NOT be available in the final game

## Status Effects

**Important**: The Status System is not standalone - it is strictly connected with tokens. The main purpose is to inform the player what's happening in the game and allow better planning. Tokens signalize various effects that can affect the player.

### Status System Purpose
- **Informational**: Tells players what's happening in the game
- **Planning**: Allows players to plan their actions better
- **Visual**: Statuses are represented by tokens on player boards
- **Token-based**: All statuses are connected to physical tokens

### Temporary Statuses (One-Turn)
- **SICK**: Reduces health, removed at end of turn
- **WOUNDED**: Reduces health, removed at end of turn

### Persistent Statuses
- **ADDICTION**: Blocks AP, requires special treatment to remove
- **DATING**: Relationship status, can lead to marriage
- **GOOD_KARMA**: Positive status, affects certain events (allows avoiding one obligatory card)

### Family Statuses
- **MARRIAGE**: Permanent relationship, unlocks family mechanics
- **BOY**: Male child
- **GIRL**: Female child
- **Placement**: Family statuses (Marriage, Boy, Girl) are placed **NOT in the token area**, but **in the house/property** which the player owns or rents
- **Family Capacity**: Each property has a capacity limit (see Estate/Housing System). If family (including player) exceeds capacity, player doesn't get satisfaction from having family (system not yet implemented)

### Status Management
- Statuses are represented by tokens on player boards
- Tokens signalize various effects affecting the player
- Some statuses can be removed by shop items (Cure cards)
- Statuses affect gameplay in various ways
- **Family Status Placement**: Family statuses (Marriage, Boy, Girl) are placed in the house/property which the player owns or rents, NOT in the token area on the player board

## Health and Rest Mechanics

### REST AP → Health Conversion
At the end of each turn:
- **Formula**: `Health Change = REST AP - 4`
- **Example**: 
  - 6 REST AP → +2 Health
  - 4 REST AP → 0 Health change
  - 2 REST AP → -2 Health

### Health → AP Blocking
Low health blocks AP for the next turn:
- Health ≤ 0: **6 AP blocked**
- Health ≤ 3: **3 AP blocked**
- Health ≤ 6: **1 AP blocked**
- Health > 6: **0 AP blocked**

### Rest Equivalent
Some shop items provide "rest equivalent":
- **Anti-sleeping pills**: Provides rest equivalent
- **Nature trip**: Provides rest equivalent (Note: graphics still need adjustment)
- Counts as REST AP for health calculation
- Does not actually spend AP

## Estate/Housing System

### Housing Levels and Capacity
Each property has a certain amount of spaces that can house people (including the player):

- **L0 (Room in Grandma's house)**: 1 person
- **L1 (Studio apartment)**: 2 people
- **L2 (Flat with three rooms)**: 3 people
- **L3 (Housing in suburbs)**: 5 people
- **L4 (Mansion)**: 6 people

### Family Capacity System
- **Not Implemented Yet**: If player's family (including player) is bigger than the amount of spots in their apartment, they can't live there comfortably
- **Effect**: They don't get satisfaction points from having a family
- **Example**: If you have 4 people but only L1 apartment (2 capacity), you won't get satisfaction from having children each turn until you upgrade to a bigger apartment

### Estate Actions
- **Rent/Buy**: Players can rent or purchase estates
- **Placement**: Estates placed on player boards
- **Family Housing**: Higher level estates can house more family members
- **Cost**: Only the **first** estate action in each turn costs **1 AP** (similar to shop system - entry fee)

### Estate Benefits
1. **More Space for Family**: Bigger estates can house more family members (see capacity above)
2. **Satisfaction Bonus**: Bigger estate brings more satisfaction at the end of each turn
3. **Ownership Bonus**: If you **own** the estate (not rent), you get **double satisfaction** compared to renting

## Vocation System

### Overview
Players choose career paths (vocations) that affect:
- Available actions
- Income potential
- Career progression
- Access to vocational event cards

### Vocation Selection
- **Timing**: Players choose their vocation at the **beginning of the Adult phase** (round 6)
- **Available Vocations**: 6 vocations available:
  1. **Public Servant**
  2. **Social Worker**
  3. **Entrepreneur**
  4. **Gangster**
  5. **NGO Worker**
  6. **Celebrity**
- **Selection Order**: 
  - Player with the **biggest amount of Science Points** chooses first
  - **Science Points** = Knowledge + Skills
  - In case of draws (same Science Points), follow turn order
  - First player chooses first, then second player, etc.
- **Restriction**: Each vocation can be chosen **only once** in the game (no duplicates - cannot have two players with the same vocation)

### Vocation Effects
- [Specific effects to be documented]
- Affects work actions and income
- Determines which vocational event cards can be played
- Each vocation has special activities for specific vocational event cards

## Costs Calculator

**Note**: This system was developed especially for the digital version of the game to help players track recurring costs.

### Recurring Costs
The Costs Calculator tracks various recurring costs per player:
- **Rental costs** per term
- **Course costs** (term-based)
- **Children costs** (term-based, connected with having children)
- **Investment costs** (if you have investments)
- **Loan costs** (if you have loans)

### Functionality
- **Cost Display**: Shows what kind of costs you will have to pay until the end of the turn
- **Manual Payment**: You can click the PAY button whenever you want during your turn
- **Automatic Payment**: Costs will be paid automatically at the end of your turn if not paid manually

### Payment System
- **Insufficient Funds**: If you don't have enough money, you will be punished (mechanics already implemented)
- **Social Support System**: 
  - Every 200 WIN you lack will be paid by social security services
  - However, you will lose satisfaction for every 200 missing WIN
  - This system helps players who can't afford costs but comes with satisfaction penalties

---

# Glossary

Common terms, abbreviations, and concepts used in the Work-Life Balance board game project.

## Game Terms

### AP (Action Points)
- Resource players spend to perform actions
- Each player has 12 AP per turn
- Can be allocated to: Work, Rest, Events, School, Inactive

### SAT (Satisfaction)
- Player satisfaction score (0-100)
- Tracked on Satisfaction Board
- Starts at 10
- Affected by events, choices, and actions

### WLB (Work-Life Balance)
- The game's theme and abbreviation
- Used in tag names and system identifiers

### Youth Phase
- Rounds 1-5 of the game
- Players start as young adults
- Focus on education and early career

### Adult Phase
- Rounds 6-13 of the game
- Players are established adults
- Focus on career, family, and life management

## Card Types

### YD (Youth Deck)
- Youth Event Cards
- Numbered YD_01 to YD_39
- 39 total cards

### AD (Adult Deck)
- Adult Event Cards
- Numbered AD_01 to AD_81
- 81 total cards

### CSHOP (Consumable Shop)
- Consumable shop cards
- Numbered CSHOP_01 to CSHOP_28
- 28 total cards
- Effects: Cure, Karma, Books, Supplements, etc.

### HSHOP (Hi-Tech Shop)
- Hi-Tech shop cards
- Numbered HSHOP_01 to HSHOP_14
- 14 total cards

### ISHOP (Investment Shop)
- Investment shop cards
- Numbered ISHOP_01 to ISHOP_14
- 14 total cards

## Technical Terms

### GUID (Global Unique Identifier)
- Unique identifier for each object in Tabletop Simulator
- Format: 6-character hex string (e.g., `c9ee1a`)
- Used to find objects in code
- Example: `c9ee1a` = Turn Controller

### Tag
- Label attached to objects for identification
- Used for finding objects without knowing GUID
- Format: `WLB_*` for game objects
- Examples:
  - `WLB_COLOR_Blue` = Blue player objects
  - `WLB_LAYOUT` = Objects that should be positioned
  - `WLB_AP_CTRL` = Action Point Controllers

### TTS (Tabletop Simulator)
- The platform where the game runs
- Steam application for digital board games
- Uses Lua scripting for automation

### Lua
- Programming language used for TTS scripts
- Simple, lightweight scripting language
- All game logic is written in Lua

## System Components

### Turn Controller
- **GUID**: `c9ee1a`
- Central game orchestrator
- Manages turn progression, game start, round tracking

### Event Engine
- **GUID**: `7b92b3`
- Processes event cards
- Applies card effects (money, stats, choices)

### Events Controller
- **GUID**: `1339d3`
- Manages event track UI
- Handles card dealing and player interactions

### Shop Engine
- **GUID**: `d59e04`
- Manages shop card system
- Handles purchasing and card effects

### Estate Engine
- **GUID**: `fd8ce0`
- Manages housing/apartment system
- Handles renting, buying, placing estates

### Token Engine
- **GUID**: `61766c`
- Manages all game tokens
- Handles status tokens, family tokens, placement

### Player Status Controller (PSC)
- Manages player status effects
- Bridge between Event Engine and Token Engine
- Handles: SICK, WOUNDED, ADDICTION, etc.

## Player Colors

- **Blue** (B)
- **Green** (G)
- **Red** (R)
- **Yellow** (Y)

Used in:
- Tag names: `WLB_COLOR_Blue`
- Object names: "MONEY B", "PB AP CTRL B"
- File references

## Housing Levels

### L0 (Level 0 - Room in Grandma's house)
- Starting apartment
- Capacity: 1 person
- Basic housing

### L1 (Studio apartment)
- Capacity: 2 people
- Upgraded estate

### L2 (Flat with three rooms)
- Capacity: 3 people
- Upgraded estate

### L3 (Housing in suburbs)
- Capacity: 5 people
- Upgraded estate

### L4 (Mansion)
- Capacity: 6 people
- Highest level estate

## Status Effects

### SICK
- One-turn status
- Reduces health
- Can be cured with shop cards

### WOUNDED
- One-turn status
- Reduces health
- Can be cured with shop cards

### ADDICTION
- Persistent status
- Negative effects
- Requires special treatment

### DATING
- Relationship status
- Can lead to marriage

### MARRIAGE
- Relationship status
- Unlocks family mechanics
- Placed in house/property (not token area)

### BOY
- Male child
- Family status
- Placed in house/property (not token area)
- Each child permanently blocks 2 AP

### GIRL
- Female child
- Family status
- Placed in house/property (not token area)
- Each child permanently blocks 2 AP

### GOOD_KARMA
- Positive status (token)
- Allows player to avoid one obligatory card
- Previously was a keep card, now converted to token system

## File Naming Conventions

### Script Files
- Format: `{GUID}_{ComponentName}.lua`
- Example: `c9ee1a_TurnController.lua`

### Documentation Files
- Format: `{GUID}_{ComponentName}_DOC.md`
- Example: `c9ee1a_TurnController_DOC.md`

### Shared Scripts
- Format: `{ComponentName}_Shared.lua`
- Example: `MoneyController_Shared.lua`
- Used when multiple objects share the same script

## Common Abbreviations in Code

- **API** = Application Programming Interface (functions other scripts can call)
- **UI** = User Interface
- **CTRL** = Controller
- **ENGINE** = Core system component
- **SCANNER** = Calibration/utility tool
- **PSC** = Player Status Controller
- **TE** = Token Engine
- **SE** = Shop Engine
- **EE** = Event Engine
- **EC** = Events Controller
- **TC** = Turn Controller

## Version Numbers

Scripts use version numbers like `v2.9.2`:
- **Major version** (2): Major changes, breaking changes
- **Minor version** (9): New features, significant improvements
- **Patch version** (2): Bug fixes, small changes

---

# First Tasks for Contributors

**Note**: This is an AI-generated list of suggested tasks. Step-by-step tasks will be updated when we discuss them together.

Welcome! This guide suggests tasks to help you get familiar with the project. Start with easy tasks and work your way up.

## 🟢 Easy Tasks (Good for First Contribution)

These tasks help you learn the codebase without requiring deep understanding.

### 1. Documentation Tasks
- [ ] **Add missing card descriptions** - Review card documentation and add descriptions for cards that are missing details
- [ ] **Improve code comments** - Add helpful comments to scripts that need better documentation
- [ ] **Fix typos** - Find and fix spelling/grammar errors in UI messages or documentation
- [ ] **Translate UI text** - Help translate remaining Polish text to English

### 2. Testing Tasks
- [ ] **Playtest a feature** - Play the game and test a specific system (e.g., Shop, Events)
- [ ] **Report bugs** - Document any issues you find while playing
- [ ] **Test edge cases** - Try unusual scenarios and see if they work correctly
- [ ] **Verify card effects** - Test that card effects work as documented

### 3. Small Code Tasks
- [ ] **Improve error messages** - Make error messages more helpful and user-friendly
- [ ] **Add debug logging** - Add console.log statements to help with debugging
- [ ] **Clean up code** - Remove commented-out code or unused variables
- [ ] **Standardize formatting** - Ensure consistent code style

## 🟡 Medium Tasks (Requires Some Understanding)

These tasks require understanding how the systems work together.

### 1. Feature Implementation
- [ ] **Complete a card effect** - Implement a TODO card effect (check code for `-- TODO:` comments)
- [ ] **Add a new shop card** - Add a new consumable card with effects
- [ ] **Improve UI feedback** - Add better visual feedback for player actions
- [ ] **Add validation** - Add input validation to prevent invalid actions

### 2. System Improvements
- [ ] **Optimize a function** - Improve performance of a slow operation
- [ ] **Refactor duplicate code** - Extract common code into reusable functions
- [ ] **Improve error handling** - Add better error handling and recovery
- [ ] **Add diagnostic tools** - Create tools to help debug issues

### 3. Documentation
- [ ] **Write component documentation** - Document a component that's missing docs
- [ ] **Create architecture diagrams** - Visualize how systems interact
- [ ] **Write game mechanics guide** - Explain a specific game mechanic in detail
- [ ] **Create player guide** - Write a guide for players (non-technical)

## 🔴 Hard Tasks (Requires Deep Understanding)

These tasks require understanding the entire system architecture.

### 1. Major Features
- [ ] **Complete remaining vocation perks** - Finish Celebrity cashback, Social Worker perks, Entrepreneur “double shop”, award system (vocation core and Public Servant are done)
- [ ] **Implement Win Condition** - Add win condition logic and UI (highest satisfaction wins)
- [ ] **Add Hi-Tech Shop Effects** - Complete all Hi-Tech shop card implementations
- [ ] **Add Investment Shop Effects** - Complete all Investment shop card implementations

### 2. System Refactoring
- [ ] **Refactor tag system** - Improve or standardize tag usage
- [ ] **Optimize performance** - Improve game speed and responsiveness
- [ ] **Improve state management** - Better handling of game state
- [ ] **Add save/load system** - Implement game state persistence

### 3. Architecture
- [ ] **Create API documentation** - Document all inter-component APIs
- [ ] **Design new system** - Design and implement a new game system
- [ ] **Improve modularity** - Make systems more independent and testable

## ✅ Before Starting a Task

1. **Read relevant documentation**
   - Component docs in `scripts/object-scripts/*_DOC.md`
   - Game mechanics in this document
   - `WORKFLOW_GUIDE.md` for development workflow

2. **Understand the context**
   - What system does this affect?
   - What other components interact with this?
   - Are there any dependencies?

3. **Ask questions**
   - If something is unclear, ask!
   - Better to ask than to make assumptions

4. **Test your changes**
   - Always test in Tabletop Simulator
   - Verify the change works as expected
   - Check for side effects

## 📝 After Completing a Task

1. **Document your changes**
   - Update relevant documentation
   - Add comments to code if needed
   - Note any breaking changes

2. **Test thoroughly**
   - Test the specific feature
   - Test related features (regression testing)
   - Test edge cases

3. **Report completion**
   - Note what was done
   - Mention any issues encountered
   - Suggest next steps if applicable

## 🆘 Getting Help

**Stuck on a task?**
- Review component documentation
- Ask for clarification

**Need to understand something?**
- Read the [Quick Start Guide](#quick-start-guide) for basics
- Read the [Glossary](#glossary) for terms
- Check component documentation

**Found a bug?**
- Document it clearly
- Include steps to reproduce
- Note what you expected vs. what happened

---

# Project Status

**Last Updated**: February 14, 2026

## Current Phase
**Development** – Core and vocation systems implemented; adding remaining vocation perks and polish

## Overall Completion

### Core Systems: 95% ✅
- ✅ Turn Management System (v2.9.2) – includes overwork SAT loss at end of turn, round-end vocation hook
- ✅ Event System (Event Engine, Events Controller)
- ✅ Shop System (Shop Engine) – consumables, Hi-Tech, investments; voucher + Public Servant 50% consumable discount
- ✅ Estate System (Estate Engine)
- ✅ Token System (Token Engine) – including Experience tokens (WLB_STATUS_EXPERIENCE)
- ✅ Resource Controllers (Money, AP, Stats, Satisfaction)
- ✅ Status System (Player Status Controller)
- ✅ VocationsController – selection, work income, promotion, work obligation, experience tokens, tax waiver, Public Servant flows

### UI/UX: 72% 🟡
- ✅ Functional UI for all major systems
- ✅ Vocation summary panel and action buttons
- ✅ Public Servant tax waiver status line (“Tax can be waived” / “Tax obligation”)
- 🟡 Needs polish and visual improvements
- 🟡 Translation to English (partially done)
- 🔴 Some UI elements need refinement

### Content: 72% 🟡
- ✅ All Youth Event Cards (39 cards)
- ✅ Adult Event Cards – most implemented (obligatory, Luxury/Property tax with waiver, Hi-Tech Failure, etc.)
- ✅ Consumable Shop Cards (28 cards) – Public Servant 50% discount applied
- ✅ Hi-Tech Shop Cards (14 cards) – effects and Repair-for-broken flow
- ✅ Investment Shop Cards (14 cards)
- ✅ Vocation system – core and Public Servant complete; other vocations’ actions/perks partly done
- 🟡 Remaining: Celebrity cashback, Social Worker perks, Entrepreneur “double shop”, award system

### Testing: 35% 🔴
- 🟡 Basic and feature testing done
- 🔴 Full playthrough and balance testing needed
- 🔴 Edge case and multi-player testing needed

### Documentation: 50% 🟡
- ✅ Technical documentation (component docs)
- ✅ Script inventory and checklist
- ✅ Workflow guide
- ✅ Game design documentation (this document)
- ✅ Vocations implementation roadmap (refreshed 31 Jan)
- 🟡 Architecture documentation (in progress)
- 🔴 Player guide and complete rulebook needed

## Recent Achievements (late Jan 2026)

### Completed
- ✅ **Public Servant (full)** – Tax campaigns L1/L2/L3; perks (Health Monitor, Alarm, Car as tiles); 50% consumable discount; tax waiver once per level; work obligation 2–4 AP/year; experience tokens at round end
- ✅ **Overworking satisfaction** – End-of-turn SAT loss by work AP (0–2→0, 3–4→−1, 5–6→−2, 7–8→−3, 9→−4); NGO Worker exempt
- ✅ **Experience tokens** – Round end: TokenEngine gives Experience token; Public Servant only if 2–4 work AP; promotion uses experience years earned
- ✅ **Hi-Tech Failure** – One random hi-tech breaks; 25% repair cost; Repair button on card; use blocked when broken; Event card moves to used immediately
- ✅ **Proxy tiles** – Health Monitor, Alarm, Car as Tiles (GUIDs 657dd1, f9d04d, 1f3658); parking with staggered delays; no merge with cards
- ✅ **Script fix** – VocationsController `VOC_OnRoundEnd` goto scope error fixed
- ✅ Turn Controller v2.9.2, Shop Engine, Event Engine, all 42 scripted objects documented

### In Progress
- 🟡 Remaining vocation perks (Celebrity cashback/obligation, Social Worker Good Karma/rent, Entrepreneur double shop, etc.)
- 🟡 Award system for Level 3 and “no special award this year”
- 🟡 Playtesting and balancing

## Current Focus Areas

### Priority 1: Content completion
- Finish remaining vocation perks and actions (see VOCATION_SUMMARIES_AND_BUTTONS.md)
- Implement award system for vocation Level 3
- **Goal**: All vocation and card content functional

### Priority 2: Documentation
- Keep PROJECT_DOCUMENTATION and roadmap up to date
- Complete architecture documentation
- **Goal**: Clear picture of done vs. to-do

### Priority 3: Polish and testing
- UI improvements and error messages
- Comprehensive playtesting and balance
- **Goal**: Stable, polished gameplay

## Blockers

**None currently** – Project progressing smoothly

## Known Limitations

1. **Award-based promotions** – Level 3 Public Servant (and others) have award text; full award tracking not yet implemented.
2. **Some vocation perks** – Celebrity hi-tech cashback, Social Worker Good Karma grant/rent discount, Entrepreneur “double shop”, etc. still to implement.
3. **Playtesting** – Broader playtesting and balance passes still needed.

## Next Milestones

### Short-term (Next 2–4 weeks)
- [ ] Implement remaining vocation perks (Celebrity, Social Worker, Entrepreneur, Gangster, NGO as per docs)
- [ ] Award system for Level 3 vocations and “no special award this year”
- [ ] Continue playtesting and balancing

### Medium-term (Next 1–3 months)
- [ ] Complete all card effects and edge cases
- [ ] Comprehensive playtesting
- [ ] Balance adjustments
- [ ] Rulebook creation

### Long-term (Future)
- [ ] Player guide
- [ ] Publish complete rulebook
- [ ] Consider expansions or variants

## Statistics

- **Total Scripted Objects**: 42
- **Lines of Code**: ~15,000+ (estimated)
- **Documentation Files**: 50+
- **Card Types**: 5 (Youth Events, Adult Events, Consumables, Hi-Tech, Investments)
- **Total Cards**: 176+ cards

## Health Indicators

- 🟢 **Code Quality**: Good - Well organized, documented
- 🟢 **Progress**: Steady - Regular updates and improvements
- 🟡 **Testing**: Needs improvement - More playtesting required
- 🟡 **Documentation**: Improving - Structure created, content in progress
- 🟢 **Stability**: Good - Core systems stable

## Notes

- Project is in active development
- Focus is shifting from implementation to documentation and polish
- Ready for additional contributors with proper onboarding
- All core systems are functional and stable

---

**End of Documentation**
