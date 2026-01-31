# Vocation Cards - UX Design Analysis

**Status:** DESIGN DECISION NEEDED  
**Purpose:** Determine best way to present vocation information in digital version  
**Priority:** HIGH - Affects how players interact with vocations

---

## 🎯 Problem Statement

### Physical Version (Tabletop)
- Each player receives **4 cards** at game start:
  - Level 1 card (double-sided: front = level info, back = level action)
  - Level 2 card (double-sided: front = level info, back = level action)
  - Level 3 card (double-sided: front = level info, back = level action)
  - Special Events card (double-sided: 2 special actions)
- **Advantages:**
  - Easy to flip cards to see both sides
  - Can spread cards out to see all levels
  - Familiar physical interaction
  - Can pass cards around, read together

### Digital Version Challenges
- **Flipping cards:** Possible but less intuitive (right-click? button?)
- **Reading both sides:** Need to remember what's on back, or flip frequently
- **Managing 4 cards:** Takes up space, harder to see all info at once
- **Interaction:** Buttons on cards might be small, hard to click
- **Visibility:** Other players can't easily see your vocation cards

---

## 📊 Information Requirements

### What Players Need to See:

1. **Current Level Information:**
   - Job title
   - Salary (per AP)
   - Promotion requirements (Knowledge, Skills, Experience/Award)
   - Level perks/talents (always-on abilities)

2. **Current Level Actions:**
   - Level-specific actions (e.g., "Yearly income tax collection campaign")
   - Costs and outcomes
   - When/how to use them

3. **Special Events:**
   - 2 special actions available
   - Costs and outcomes
   - When/how to use them

4. **Progression Status:**
   - Current level (1, 2, or 3)
   - Progress toward next level (Knowledge/Skills/Experience)
   - Award conditions (if applicable)

### What Players Need to Do:

1. **View Information:** Read current level details, actions, requirements
2. **Trigger Actions:** Use level actions (e.g., "Spend 2 AP to collect taxes")
3. **Check Promotion:** See if they can promote to next level
4. **Promote:** Advance to next level when requirements met
5. **Reference:** Quickly check salary, perks, available actions

---

## 💡 Design Options

### Option A: Keep Cards (Physical Version Style)

**Implementation:**
- Each player gets 4 cards (Level 1, 2, 3, Special Events)
- Cards placed near player board (like Hi-Tech cards)
- Double-sided cards (flip with right-click or button)
- Buttons on cards for actions

**Pros:**
- ✅ Matches physical game (familiar)
- ✅ Cards can be moved, organized by player
- ✅ Each card is focused (one level at a time)
- ✅ Can see progression (stack of cards)

**Cons:**
- ❌ Hard to see all info at once (need to flip cards)
- ❌ Managing 4 cards per player (16 cards total for 4 players)
- ❌ Buttons on cards might be small
- ❌ Other players can't easily see your vocation
- ❌ Need to flip cards frequently to see back actions
- ❌ Harder to see progression status across levels

---

### Option B: Single Vocation Tile Per Player (Recommended)

**Implementation:**
- One **large tile** per player (placed near player board)
- Shows all 3 levels + special events in one view
- Current level highlighted/emphasized
- Buttons for actions on the tile
- All information visible at once

**Layout Concept:**
```
┌─────────────────────────────────────┐
│  [VOCATION TILE - ENTREPRENEUR]     │
│                                     │
│  Current Level: 2 (Manager)         │
│  Salary: 300 VIN/AP                 │
│                                     │
│  ┌─────────┬─────────┬─────────┐  │
│  │ Level 1 │ Level 2 │ Level 3 │  │
│  │ Shop    │ Manager │ Hi-Tech │  │
│  │ Asst.   │         │ Owner   │  │
│  │ 150/AP  │ 300/AP  │ 500/AP  │  │
│  │ ✅      │ ⭐CURRENT│ ⏳LOCKED│  │
│  └─────────┴─────────┴─────────┘  │
│                                     │
│  [Level 2 Actions]                 │
│  [Button: Use Network (1 AP)]       │
│  [Button: Commercial Training]      │
│                                     │
│  [Special Events]                   │
│  [Button: Aggressive Expansion]     │
│  [Button: Employee Training]        │
│                                     │
│  [Promotion Status]                 │
│  Knowledge: 7/7 ✅                  │
│  Skills: 11/11 ✅                    │
│  Experience: 2/3 ⏳                  │
│  [Button: Promote to Level 3]       │
└─────────────────────────────────────┘
```

**Pros:**
- ✅ **All information visible at once** - no flipping needed
- ✅ **Clear progression** - see all 3 levels side-by-side
- ✅ **Easy interaction** - buttons on tile, not small cards
- ✅ **Better visibility** - other players can see your vocation
- ✅ **Status at a glance** - promotion progress visible
- ✅ **Less clutter** - 1 tile per player vs 4 cards
- ✅ **Better for digital** - optimized for screen interaction

**Cons:**
- ❌ Different from physical version (less familiar)
- ❌ Larger object (takes more space)
- ❌ More complex UI (need to organize all info)

---

### Option C: Hybrid Approach (Original Concept)
- **Vocation Tile:** Shows current level info + actions (main interaction)
- **Reference Cards:** Optional cards for other players to see your vocation
- **Special Events Card:** Separate card for special events (can be on tile or separate)

**Note:** This was superseded by Option D (Panel-First approach)

---

### Option D: Panel-First, Cards as Reference (✅ CONFIRMED APPROACH)

**Implementation:**
- **1 Vocation Card** in Character slot on player board (trigger/button)
- **Vocation Panel Tile** (popup overlay) - appears above board when card clicked
- **Reference Cards** (4 cards per vocation) - optional, in deck/box for reference

**User Flow:**
1. Player has 1 vocation card in Character slot
2. Player clicks card → Panel appears above player board
3. Panel shows all vocation info + buttons
4. Player clicks action button → Action executes, panel closes
5. Or player clicks "Close" → Panel disappears

**Pros:**
- ✅ **Best of both worlds:** Cards for identity, panel for interaction
- ✅ **Space efficient:** Only 1 card on board, panel on demand
- ✅ **No flipping needed:** All info in panel
- ✅ **Preserves physical design:** Cards still exist and are used
- ✅ **Clean UX:** Card = identity, Panel = mechanics
- ✅ **Fits existing board:** Uses Character slot perfectly

**Cons:**
- ⚠️ Requires panel spawning/positioning logic
- ⚠️ Need to handle panel state (open/closed)

---

## 🎯 Recommendation: Option B (Single Vocation Tile)

### Why Single Tile is Better for Digital:

1. **Information Density:**
   - All 3 levels visible at once
   - Current level clearly marked
   - Promotion status visible
   - No need to flip cards

2. **Interaction:**
   - Larger buttons (easier to click)
   - All actions in one place
   - Clear visual hierarchy

3. **Visibility:**
   - Other players can see your vocation
   - Easy to check what others have
   - Better for multiplayer awareness

4. **Progression Clarity:**
   - See where you are (Level 2)
   - See where you came from (Level 1, completed)
   - See where you're going (Level 3, locked)
   - See requirements for next level

5. **Space Efficiency:**
   - 1 tile per player (4 tiles total)
   - vs 4 cards per player (16 cards total)
   - Less clutter on table

---

## 🏗️ Proposed Tile Design

### Tile Structure

**Section 1: Header**
- Vocation name (e.g., "ENTREPRENEUR")
- Current level indicator (e.g., "Level 2 - Manager")
- Current salary (e.g., "300 VIN/AP")

**Section 2: Level Overview (3 columns)**
- **Level 1:** Job title, salary, status (✅ Completed)
- **Level 2:** Job title, salary, status (⭐ Current)
- **Level 3:** Job title, salary, status (⏳ Locked)

**Section 3: Current Level Details**
- **Perks/Talents:** Always-on abilities (e.g., "50% discount on Consumables")
- **Actions:** Buttons for level-specific actions
  - Each action shows: Cost, Description, Button to trigger

**Section 4: Special Events**
- **Special Action 1:** Button + description
- **Special Action 2:** Button + description

**Section 5: Promotion Status**
- **Requirements for Next Level:**
  - Knowledge: X/Y ✅/⏳
  - Skills: X/Y ✅/⏳
  - Experience: X/Y ✅/⏳
  - Award: Condition + status
- **Promote Button:** (enabled when all requirements met)

---

## 🎨 Visual Design

### Tile Layout (Detailed)

```
┌─────────────────────────────────────────────────────┐
│  ENTREPRENEUR                    [Level 2 - Manager] │
│  Salary: 300 VIN/AP                                  │
├─────────────────────────────────────────────────────┤
│  ┌───────────┬───────────┬───────────┐              │
│  │ Level 1   │ Level 2   │ Level 3   │              │
│  │ Shop      │ Manager   │ Hi-Tech   │              │
│  │ Assistant │ ⭐CURRENT │ Owner     │              │
│  │ 150/AP    │ 300/AP    │ 500/AP    │              │
│  │ ✅ DONE   │ ⭐ACTIVE  │ ⏳LOCKED  │              │
│  └───────────┴───────────┴───────────┘              │
├─────────────────────────────────────────────────────┤
│  LEVEL 2 PERKS:                                      │
│  • Network: Spend 1 AP → reroll die (self/other)    │
│  • Passive: +1 SAT if most money                     │
├─────────────────────────────────────────────────────┤
│  LEVEL 2 ACTIONS:                                    │
│  [Commercial Training Course]                        │
│  Cost: 2 AP | Others pay 200 VIN to join            │
├─────────────────────────────────────────────────────┤
│  SPECIAL EVENTS:                                     │
│  [Aggressive Expansion] [Employee Training Boost]   │
├─────────────────────────────────────────────────────┤
│  PROMOTION TO LEVEL 3:                                │
│  Knowledge: 7/9 ⏳  Skills: 11/13 ⏳                 │
│  Award: Buy L3/L4 house + 2 Hi-Tech ⏳              │
│  [Promote] (disabled until requirements met)        │
└─────────────────────────────────────────────────────┘
```

### Button States

- **Available Actions:** Normal button, clickable
- **Locked Actions:** Grayed out, shows "Locked" or requirement
- **Current Level:** Highlighted with ⭐ or border
- **Completed Level:** Checkmark ✅
- **Promotion Button:** Enabled when all requirements met

---

## ⚙️ Implementation Considerations

### Panel Placement & Spawning

**Method 1: Dynamic Spawning (Recommended)**
- Panel tile created/spawned when card is clicked
- Positioned above player board (Y offset: +2 to +4 units)
- Anchored to player board position
- Destroyed/hidden when closed

**Method 2: Pre-Placed Hidden**
- Panel tile exists but hidden (scaled to 0 or moved under table)
- Shown/moved when card clicked
- Hidden again when closed

**Positioning:**
- Calculate player board position
- Offset Y coordinate (above board)
- Keep X/Z aligned with board center
- Use `setPositionSmooth()` for animation

### Card in Character Slot

- **Placement:** In "Character" slot on player board (where silhouette is)
- **Function:** Visual identity + trigger button
- **Content:** Can show vocation name, current level, or just be a trigger
- **Interaction:** Click card → Open panel

### Interaction Methods

1. **Action Buttons:**
   - Click button on tile → Triggers action
   - Validates costs (AP/money) before allowing
   - Shows results/outcomes

2. **Promotion:**
   - Check requirements automatically
   - Enable "Promote" button when ready
   - Player clicks to promote (or automatic?)

3. **Information Display:**
   - All info visible (no flipping needed)
   - Can add tooltips for detailed descriptions
   - Color coding for status (completed/current/locked)

### State Management

- **VocationsController** tracks:
  - Current level per player
  - Promotion progress
  - Tile updates automatically when level changes

---

## 📋 Comparison Table

| Feature | Cards (Option A) | Tile (Option B) | Hybrid (Option C) | Panel-First (Option D) ✅ |
|---------|------------------|-----------------|-------------------|---------------------------|
| **Info Visibility** | Need to flip | All visible | Partial | All visible (in panel) |
| **Interaction** | Small buttons | Large buttons | Mixed | Large buttons (in panel) |
| **Space Usage** | 16 cards (4 players) | 4 tiles | 4 tiles + cards | 4 cards + panels on demand |
| **Progression Clarity** | Hard to see | Very clear | Moderate | Very clear (in panel) |
| **Other Players' View** | Hard to see | Easy to see | Moderate | Card visible, panel on demand |
| **Familiarity** | Matches physical | Different | Mixed | Matches physical (card) |
| **Implementation** | Medium | Medium-High | High (complex) | Medium-High |
| **UX Quality** | Low (friction) | High | Medium | **Highest** ✅ |

---

## ✅ Final Recommendation: **Option D - Hybrid: Panel-First, Cards as Reference** (CONFIRMED)

### **Approach: Card as Trigger + Popup Panel**

**Physical Objects:**
- **1 Vocation Card** per player in "Character" slot on player board
  - **Card Selection:** Only the card matching current level is on board
    - Level 1 → Level 1 card on board
    - Level 2 → Level 2 card on board (replaces Level 1)
    - Level 3 → Level 3 card on board (replaces Level 2)
  - **Card Pool:** 3 cards per vocation (Level 1, 2, 3) = 18 cards total
  - **Card Swapping:** When player promotes, system swaps card to match new level
  - **Function:** Visual identity (shows current level) + clickable trigger
  - Always visible on board (one card at a time)
  - Clickable to open panel (reusable)

- **Vocation Panel Tile** (hidden/spawned on demand)
  - Large interactive tile/board
  - Appears **above player board** when card is clicked
  - Contains all vocation information and buttons
  - **Closes when:**
    - Player clicks "Close" button
    - Player clicks outside tile (on table/other objects)
    - After action completion (optional)
  - **After closing:** Card remains on board, ready to click again

**Card Management:**
- **18 cards total:** 3 levels × 6 vocations
- Cards stored in deck/box when not in use
- Only 1 card per player on board (matching current level)
- When level changes → Swap card on board

### **Why This Wins:**

1. **Preserves Physical Design:**
   - ✅ Cards still exist and are used
   - ✅ One card in Character slot matches physical layout
   - ✅ Maintains visual continuity

2. **Optimized for Digital:**
   - ✅ No flipping needed during play
   - ✅ All info visible in panel
   - ✅ Large buttons, clear interaction
   - ✅ Panel appears only when needed

3. **Space Efficient:**
   - ✅ Only 1 card per player on board (4 cards total)
   - ✅ Panel appears on demand, doesn't clutter table
   - ✅ Panel closes after use

4. **User Experience:**
   - ✅ Card = "Who I am" (identity)
   - ✅ Click card = "What can I do?" (interaction)
   - ✅ Panel = Full mechanics and actions
   - ✅ Intuitive and clean

### **Implementation:**

**Card Script (`VocationCard.lua`):**
- Tag: `WLB_VOCATION_CARD` + color tag + level tag (e.g., `WLB_VOC_LEVEL_1`)
- **Card Structure:** 18 cards total (3 levels × 6 vocations)
- **Card Identity:** Each card represents specific vocation + level
- **Card Swapping:** Only card matching current level is on board
  - Level 1 → Level 1 card on board
  - Level 2 → Level 2 card replaces Level 1
  - Level 3 → Level 3 card replaces Level 2
- **Function:** Visual identity (shows current level) + clickable trigger
- **Interaction:** Click card → Opens Vocation Panel tile (shows all 3 levels info)
- **State:** Card always visible on board in Character slot (one card at a time)

**Panel Script (`VocationPanel.lua`):**
- Tag: `WLB_VOCATION_PANEL` + color tag
- **Shows all vocation information:**
  - Current level, salary
  - All 3 levels overview
  - Current level perks/talents
  - Action buttons
  - Special events buttons
  - Promotion status + Promote button
- **Buttons trigger actions via VocationsController**
- **Close Methods:**
  - "Close" button on tile (explicit close)
  - Click outside tile (detect click on table/other objects)
  - Auto-close after action completion (optional)

**Placement:**
- Panel spawns/positions **above player board** (Y offset)
- Anchored to player board position
- Large enough to show all info clearly
- **Disappears when closed** → Card becomes clickable again

**Interaction Flow:**
1. Player sees card on board (shows vocation + level)
2. Player clicks card → Tile appears above board
3. Player interacts with tile (views info, clicks actions)
4. Player clicks "Close" OR clicks outside tile → Tile disappears
5. Card remains on board, ready to click again

---

## 🎯 Next Steps

1. ✅ **Design Confirmed:** Panel-First approach (Option D)
2. **Create Vocation Card Script:** `VocationCard.lua` - trigger button in Character slot
3. **Create Vocation Panel Script:** `VocationPanel.lua` - popup tile with all info and buttons
4. **Implement Panel Spawning:** Position panel above player board on card click
5. **Integrate with VocationsController:** Panel updates based on vocation state
6. **Test:** Verify card click → panel opens → actions work → panel closes

---

## 📋 Technical Implementation Details

### VocationCard.lua (Card in Character Slot)

**Tag:** `WLB_VOCATION_CARD` + color tag + level tag (e.g., `WLB_VOC_LEVEL_1`)

**Card Structure:**
- **18 cards total:** 3 levels × 6 vocations
- Each card is a **specific level** of a **specific vocation**
- Cards stored in deck/box when not in use
- Only **1 card per player** on board (matching current level)

**Functions:**
- `onClick()` - Opens Vocation Panel (shows all 3 levels info, not just current card's level)
- `getVocation()` - Returns which vocation this card represents
- `getLevel()` - Returns which level this card represents (1, 2, or 3)
- `isOnBoard(color)` - Checks if this card is currently on player's board

**Card Swapping (Handled by VocationsController or Card Manager):**
- `findCardForLevel(vocation, level)` - Finds card matching vocation + level
- `placeCardOnBoard(card, color)` - Places card in Character slot
- `removeCardFromBoard(color)` - Removes current card from board
- `swapCardOnPromotion(color, oldLevel, newLevel)` - Swaps cards when level changes

**Card Display:**
- Each card shows its specific level info (front side)
- Example: "ENTREPRENEUR - Level 2 - Manager"
- Visual design matches physical card front

**Interaction:**
- Click card → Opens panel (if panel not already open)
- Panel shows all vocation info (all 3 levels), not just current card's level
- If panel already open → Does nothing (or closes it?)

### VocationPanel.lua (Popup Tile)

**Tag:** `WLB_VOCATION_PANEL` + color tag

**Functions:**
- `openPanel(color, vocationData)` - Spawns/positions panel above player board
- `closePanel()` - Hides/destroys panel (removes or moves off-screen)
- `updateDisplay(vocationData)` - Updates all info based on current state
- `onActionButton(actionName)` - Handles action button clicks
- `onCloseButton()` - Explicit close button handler
- `checkClickOutside()` - Detects clicks outside panel (optional)

**Panel Content:**
- All sections as described in Option B tile design
- Buttons for all actions
- **"Close" button** (prominent, easy to find)
- Auto-closes after action completion (optional)

**Close Detection Methods:**

**Method 1: Close Button (Recommended)**
- Large "Close" button on tile
- Most reliable and explicit
- Clear user intent

**Method 2: Click Outside Detection**
- Monitor for clicks on table/other objects
- Use `onObjectHover` or global click detection
- More complex but more intuitive

**Method 3: Hybrid (Best UX)**
- Close button always available
- Click outside also closes (if detected)
- Fallback to close button if detection fails

**Positioning:**
```lua
local board = findPlayerBoard(color)
local boardPos = board.getPosition()
local panelPos = {boardPos.x, boardPos.y + 3, boardPos.z}  -- Above board
panel.setPositionSmooth(panelPos, false, true)
```

**State Management:**
- Track if panel is open: `panelOpen[color] = true/false`
- Prevent multiple panels for same player
- On close: Set `panelOpen[color] = false`, card becomes clickable again

---

**Status:** ✅ Design confirmed - Panel-First approach (Option D)  
**Implementation:** Ready to proceed with VocationCard + VocationPanel scripts
