# Vocations System - Implementation Roadmap

**Status:** READY TO START IMPLEMENTATION  
**Last Updated:** 2026-01-XX  
**Purpose:** Step-by-step implementation plan for Vocations system

---

## 📊 Current Status

### ✅ Completed (Documentation & Design)
- ✅ **VOCATIONS_SYSTEM_ANALYSIS.md** - Complete vocation mechanics documented
- ✅ **PLAYER_INTERACTION_SYSTEM_PROPOSAL.md** - Interaction system designed (for future)
- ✅ **VOCATION_CARDS_UX_ANALYSIS.md** - UX design confirmed (Panel-First approach)
- ✅ **VocationsController object** - Created with tag `WLB_VOCATIONS_CTRL`
- ✅ **Vocation Tiles** - Being finished (one per player with all info)
- ✅ **Vocation Cards** - Planned (visual + clickable trigger)

### ❌ Not Yet Implemented (Code)
- ❌ **VocationsController.lua** - Script doesn't exist yet (object exists, needs script)
- ❌ **Vocation selection** - At Adult period start
- ❌ **Vocation tracking** - Per-player state
- ❌ **Work income system** - AP spent on WORK → money based on vocation salary
- ❌ **Promotion system** - Level advancement mechanics
- ❌ **Vocation actions** - Level-specific and special event actions
- ❌ **Integration** - With Event Engine, Shop Engine, AP Controller

---

## 🎯 Implementation Phases (Prioritized)

### **PHASE 1: Foundation - VocationsController Core** (2-3 hours)
**Goal:** Create the core tracking system

**Tasks:**
1. **Create `VocationsController.lua` script**
   - Basic structure with tag `WLB_VOCATIONS_CTRL`
   - State tracking: `vocations[color] = vocationName`
   - State tracking: `levels[color] = 1` (start at Level 1)
   - State tracking: `workAP[color] = 0` (cumulative AP spent on work)
   - Save/load state persistence

2. **Implement Basic APIs:**
   - `VOC_GetVocation({color=...})` → returns vocation name or nil
   - `VOC_SetVocation({color=..., vocation=...})` → sets vocation (with exclusive check)
   - `VOC_GetLevel({color=...})` → returns current level (1, 2, or 3)
   - `VOC_GetSalary({color=...})` → returns salary per AP for current level
   - `VOC_AddWorkAP({color=..., amount=...})` → tracks AP spent on work

3. **Vocation Data Structure:**
   - Define vocation constants (names: "PUBLIC_SERVANT", "CELEBRITY", etc.)
   - Define salary lookup table per vocation and level
   - Define promotion requirements per vocation and level

**Deliverable:** VocationsController can track and query vocation state

---

### **PHASE 2: Vocation Selection at Adult Start** (2-3 hours)
**Goal:** Implement selection mechanics when Adult period begins

**Tasks:**
1. **Integrate with Turn Controller:**
   - Detect when Adult period starts (round 6 or Adult mode start)
   - Calculate selection order (Science Points = Knowledge + Skills)
   - Handle turn order tie-breaker

2. **Selection UI/Flow:**
   - Show available vocations to player
   - Enforce exclusivity (can't choose if already taken)
   - Set vocation via `VOC_SetVocation()`
   - Place vocation card in Character slot

3. **Adult Start Bonus (if starting from Adult):**
   - Grant bonus Knowledge/Skills
   - Allow player to distribute points
   - Calculate Science Points after distribution

**Deliverable:** Players can select vocations at Adult start, system enforces exclusivity

---

### **PHASE 3: Vocation Tiles & Cards Integration** (2-3 hours)
**Goal:** Connect tiles/cards to VocationsController with click-to-open/close interaction

**Tasks:**
1. **Vocation Tile Script (`VocationTile.lua`):**
   - Tag: `WLB_VOCATION_TILE` + color tag + level tag (e.g., `WLB_VOC_LEVEL_1`)
   - **Tile Structure:** 18 tiles total (3 levels × 6 vocations)
   - **Type:** Tile (not Card) - prevents merging into decks when stacked
   - **Tile Identity:** Each tile represents specific vocation + level
   - **Tile Swapping:** Only tile matching current level is on board
     - Level 1 → Level 1 tile on board
     - Level 2 → Level 2 tile replaces Level 1
     - Level 3 → Level 3 tile replaces Level 2
   - **Always visible** on board in Character slot (one tile at a time)
   - **Clickable:** Click tile → Opens Vocation Panel tile
   - **Tile Management:** System swaps tiles when level changes

2. **Vocation Panel Script (`VocationPanel.lua`):**
   - Tag: `WLB_VOCATION_PANEL` + color tag
   - Queries VocationsController for current state on open
   - Displays all vocation information (all 3 levels, actions, etc.)
   - Positions above player board (Y offset)
   - **Close Methods:**
     - "Close" button (prominent, always visible)
     - Click outside detection (optional, more complex)
   - **State tracking:** Prevents multiple panels per player

3. **Interaction Flow:**
   - Player clicks card → Panel appears above board
   - Player interacts with panel (views info, clicks actions)
   - Player clicks "Close" OR clicks outside → Panel disappears
   - Card remains on board, ready to click again (reusable)

4. **Panel Updates:**
   - Panel queries VocationsController on open
   - Shows current level, salary, promotion status
   - Buttons for actions (initially disabled/placeholder)
   - Updates when vocation state changes (if panel is open)

**Deliverable:** 
- Tile shows current vocation + level on board
- Click tile → Panel opens with full info
- Click close/outside → Panel closes
- Tile remains clickable for repeated use
- **Tiles don't merge into decks** when stored together

---

### **PHASE 4: Basic Work Income System** (2-3 hours)
**Goal:** AP spent on WORK → money based on vocation salary

**Tasks:**
1. **AP Controller Integration:**
   - Detect when AP is spent on WORK area
   - Query VocationsController for player's vocation and level
   - Calculate income: `AP × salary`
   - Grant money to player

2. **Integration Points:**
   - Hook into AP spending system
   - Or check at end of turn (count AP in WORK area)
   - Grant money via Money Controller

3. **Edge Cases:**
   - Handle players without vocation (shouldn't happen in Adult)
   - Handle Level 0 (shouldn't exist, but safety check)

**Deliverable:** Players earn money when spending AP on work, based on vocation salary

---

### **PHASE 5: Promotion System** (3-4 hours)
**Goal:** Players can advance from Level 1 → 2 → 3

**Tasks:**
1. **Promotion Requirements Checking:**
   - Query Stats Controller for Knowledge/Skills
   - Query VocationsController for Experience (years) or Work AP
   - Check Award conditions (if Level 3)
   - `VOC_CanPromote({color=...})` → returns true/false + reason

2. **Promotion Execution:**
   - `VOC_Promote({color=...})` → advances to next level
   - Update level state
   - Update panel/tile display
   - Broadcast promotion message

3. **Experience Tracking:**
   - Track "years" (experience tokens) for standard promotions
   - Track Work AP for work-based promotions (Celebrity)
   - Track Award conditions for award-based promotions

**Deliverable:** Players can promote when requirements are met

---

### **PHASE 6: Vocation Actions (Basic)** (4-6 hours)
**Goal:** Implement level-specific actions and special events

**Tasks:**
1. **Action Button System:**
   - Buttons on Vocation Panel for each action
   - Validate costs (AP/money) before allowing
   - Execute action logic

2. **Simple Actions First:**
   - Actions that don't require player interactions
   - Example: Entrepreneur "Network" (reroll die)
   - Example: Social Worker passive perks (50% rent)

3. **Complex Actions (Later):**
   - Actions requiring player interactions (use Interaction System later)
   - Example: Celebrity "Live Stream" (others can join)
   - Example: Gangster "Crime" (target player choice)

**Deliverable:** Basic vocation actions work, complex ones marked for Interaction System

---

### **PHASE 7: Integration with Other Systems** (2-3 hours)
**Goal:** Connect vocations to existing card systems

**Tasks:**
1. **AD_WORKBONUS Cards:**
   - Query VocationsController for salary
   - Calculate: `bonus = salary × 4`
   - Grant money to player

2. **SMARTPHONE Card:**
   - End of turn: Check AP count in WORK + SCHOOL areas
   - If ≥2: Grant +1 SAT

3. **HEALTHINSURANCE Card:**
   - Query vocation salary
   - Calculate lost income based on blocked AP
   - Grant insurance payment

**Deliverable:** Existing cards that depend on vocations now work

---

## 🎯 Recommended Starting Point

### **Start with PHASE 1: VocationsController Core**

**Why Start Here:**
1. **Foundation:** Everything else depends on this
2. **No Dependencies:** Can be built independently
3. **Quick Win:** Creates working system immediately
4. **Enables Testing:** Can test vocation selection and tracking

**What You'll Build:**
- Core tracking system
- Basic APIs for other systems to use
- Vocation data structures
- State persistence

**After Phase 1:**
- You can test vocation selection (Phase 2)
- You can connect tiles/cards (Phase 3)
- You can implement work income (Phase 4)

---

## 📋 Detailed Phase 1 Implementation

### Step 1.1: Create VocationsController.lua Structure

```lua
-- =========================================================
-- WLB VOCATIONS CONTROLLER v1.0.0
-- GOAL: Track player vocations, levels, and promotion progress
-- =========================================================

local DEBUG = true
local VERSION = "1.0.0"

-- Tags
local TAG_SELF = "WLB_VOCATIONS_CTRL"

-- Vocation Names (Constants)
local VOC_PUBLIC_SERVANT = "PUBLIC_SERVANT"
local VOC_CELEBRITY = "CELEBRITY"
local VOC_SOCIAL_WORKER = "SOCIAL_WORKER"
local VOC_GANGSTER = "GANGSTER"
local VOC_ENTREPRENEUR = "ENTREPRENEUR"
local VOC_NGO_WORKER = "NGO_WORKER"

-- State
local vocations = { Yellow=nil, Blue=nil, Red=nil, Green=nil }
local levels = { Yellow=1, Blue=1, Red=1, Green=1 }
local workAP = { Yellow=0, Blue=0, Red=0, Green=0 }

-- Vocation Data (salaries, requirements, etc.)
local VOCATION_DATA = {
  -- Will be populated with all vocation details
}

-- Basic APIs to implement
function VOC_GetVocation(params) ... end
function VOC_SetVocation(params) ... end
function VOC_GetLevel(params) ... end
function VOC_GetSalary(params) ... end
function VOC_AddWorkAP(params) ... end
```

### Step 1.2: Implement Vocation Data

Populate `VOCATION_DATA` table with:
- Salaries per level (from analysis document)
- Promotion requirements (Knowledge, Skills, Experience/Award)
- Job titles per level

### Step 1.3: Implement Basic APIs

- Get/Set vocation
- Get level
- Get salary (lookup based on vocation + level)
- Track work AP

---

## ⚠️ Dependencies to Verify

Before starting, verify these systems exist and work:

1. **Stats Controller:**
   - Can query Knowledge/Skills per player
   - Needed for: Promotion requirements, Science Points calculation

2. **AP Controller:**
   - Can query AP count in WORK area
   - Can track AP spent on work
   - Needed for: Work income, promotion tracking

3. **Money Controller:**
   - Can grant money to player
   - Needed for: Work income, bonuses

4. **Turn Controller:**
   - Detects Adult period start
   - Manages turn order
   - Needed for: Vocation selection timing

5. **Player Board:**
   - Character slot exists
   - Can place card in slot
   - Needed for: Vocation card placement

---

## 🔄 Implementation Order Recommendation

### **Tonight's Session (3-4 hours):**

1. **Phase 1: VocationsController Core** (2-3 hours)
   - Create script structure
   - Implement basic APIs
   - Define vocation data
   - Test: Can set/get vocation, can query salary

2. **Phase 2: Vocation Selection** (1-2 hours)
   - Integrate with Turn Controller
   - Implement selection flow
   - Test: Players can select vocations at Adult start

**Result:** Foundation working, players can select and track vocations

### **Next Session:**

3. **Phase 3: Tiles & Cards** (2-3 hours)
   - Connect tiles to VocationsController
   - Implement card click → panel open
   - Test: Clicking card shows panel with vocation info

4. **Phase 4: Work Income** (2-3 hours)
   - Implement AP → money conversion
   - Test: Spending AP on work grants money

**Result:** Basic vocation system functional

---

## ❓ Questions to Resolve Before Implementation

1. **Promotion Timing:**
   - Is promotion automatic when requirements met?
   - Or does player click "Promote" button?
   - Can player choose when to promote?

2. **Experience Tracking:**
   - How are "years" (experience) tracked?
   - Is there an experience token system?
   - Or is it based on turns/rounds?

3. **Work AP Tracking:**
   - Should we track AP spent on work per turn?
   - Or cumulative across all turns?
   - When does it reset (if ever)?

4. **Vocation Selection UI:**
   - How should players choose vocation?
   - Buttons on Turn Controller?
   - Cards they click?
   - Modal dialog?

---

## ✅ Ready to Start?

**Recommended First Steps:**

1. ✅ **Create VocationsController.lua** - Core tracking system
2. ✅ **Define Vocation Data** - All 6 vocations with salaries, requirements
3. ✅ **Implement Basic APIs** - Get/Set vocation, Get level, Get salary
4. ✅ **Test Basic Functionality** - Can set vocation, query state

**Then:**
5. Integrate with Turn Controller for selection
6. Connect tiles/cards to display vocation info
7. Implement work income system
8. Add promotion mechanics

---

**Status:** Ready to begin Phase 1 implementation  
**Next Action:** Create VocationsController.lua script
