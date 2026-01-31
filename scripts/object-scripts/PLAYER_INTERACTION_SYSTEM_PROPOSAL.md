# Player Interaction System - Design Proposal

**Status:** DESIGN PHASE  
**Purpose:** Handle multi-player choices during vocation events and other player actions  
**Priority:** HIGH - Required for vocation system to function

---

## 🎯 Problem Statement

Many vocation actions require **other players** (not the active player) to make choices:

### Examples from Vocation Cards:

1. **Join/Don't Join Events:**
   - Celebrity: "Live Street Performance" - others may join by spending 1 AP
   - Celebrity: "Meet & Greet" - others may join by spending 1 AP + 200 VIN
   - Social Worker: "Practical workshop" - others may join by spending 1 AP
   - NGO Worker: "International Crisis Appeal" - others choose Join or Ignore

2. **Pay/Refuse Payments:**
   - Gangster: "Protection Racket" - each player chooses Pay or Refuse
   - NGO Worker: "Advocacy Pressure Campaign" - others choose YES or NO

3. **Multiple Choice Scenarios:**
   - Social Worker: "Expose a disturbing social case" - all players choose "Engage deeply" OR "Stay ignorant"
   - Celebrity: "Extended Charity Stream" - others may join multiple times

**Current Problem:** No system exists for non-active players to make choices during another player's turn.

---

## 💡 Proposed Solution: Interaction Controller

### Concept: Central Interaction Tile

A **central tile** placed in the middle of the table that:
- Displays information about the current interaction
- Shows buttons for each player who needs to respond
- Collects responses from all relevant players
- Provides clear visual feedback

### Design Approach

**Option A: Single Central Tile (Recommended)**
- One tile in the center of the table
- Dynamic buttons that appear for each player who needs to respond
- Color-coded buttons (Yellow, Blue, Red, Green)
- Text display showing the choice/question
- Timer/auto-response if players don't respond

**Option B: Per-Player Buttons**
- Buttons appear on each player's board
- More distributed, but harder to coordinate
- Risk of players missing the interaction

**Recommendation:** Option A (Central Tile) - easier to see, clearer coordination

---

## 📋 Interaction Types Identified

### Type 1: Binary Choice (YES/NO, JOIN/IGNORE, PAY/REFUSE)
- **Examples:**
  - Join event? (YES/NO)
  - Pay protection money? (PAY/REFUSE)
  - Support campaign? (YES/NO)
- **Implementation:** Two buttons per player (or one button that toggles)

### Type 2: Optional Participation with Cost
- **Examples:**
  - Join by spending 1 AP
  - Join by spending 1 AP + 200 VIN
  - Join multiple times (pay 500 VIN each time)
- **Implementation:** Button to join + automatic cost deduction

### Type 3: Multiple Choice (2+ options)
- **Examples:**
  - "Engage deeply" OR "Stay ignorant"
  - "Join" OR "Ignore"
- **Implementation:** Multiple buttons per player

### Type 4: Sequential Choices
- **Examples:**
  - Celebrity charity stream: players can join multiple times
  - Each donation triggers another opportunity
- **Implementation:** Button remains active until player chooses to stop

---

## 🏗️ System Architecture

### InteractionController.lua

**Tag:** `WLB_INTERACTION_CTRL`

**State:**
```lua
local activeInteraction = nil  -- Current interaction being processed
local playerResponses = {}      -- [color] = response
local waitingFor = {}           -- List of colors who need to respond
```

**APIs:**

1. **`INT_StartInteraction(params)`**
   - Starts a new interaction
   - Parameters:
     - `initiator` (color) - Player who triggered the interaction
     - `type` (string) - "BINARY", "OPTIONAL_COST", "MULTIPLE_CHOICE", "SEQUENTIAL"
     - `question` (string) - Text to display
     - `options` (table) - Available choices
     - `targets` (table) - Colors who must respond (or "ALL" for all other players)
     - `costs` (table, optional) - Cost per option (e.g., {join={ap=1, money=200}})
     - `timeout` (number, optional) - Seconds to wait (default: 30, auto-defaults to NO)
     - `onComplete` (function, optional) - Callback when all responses collected

2. **`INT_Respond(params)`**
   - Player submits their response
   - Parameters:
     - `color` (string) - Player making the choice
     - `choice` (string) - Their choice (e.g., "YES", "NO", "JOIN", "IGNORE")
     - `repeatCount` (number, optional) - For sequential choices

3. **`INT_GetResponses(params)`**
   - Get all collected responses
   - Returns: Table of {color = choice}

4. **`INT_CancelInteraction(params)`**
   - Cancel current interaction (if initiator changes mind)

---

## 🎨 UI Design

### Central Tile Layout

**Layout:** Four corners for player buttons, center for question/description

```
┌─────────────────────────────────────┐
│  [YELLOW]        [BLUE]             │
│  ┌─────┐                  ┌─────┐  │
│  │ YES │                  │ YES │  │
│  │ NO  │                  │ NO  │  │
│  └─────┘                  └─────┘  │
│                                     │
│        Question/Description         │
│        (e.g., "Join Live Stream?")  │
│        Short description of         │
│        situation needing reaction    │
│                                     │
│  ┌─────┐                  ┌─────┐  │
│  │ YES │                  │ YES │  │
│  │ NO  │                  │ NO  │  │
│  └─────┘                  └─────┘  │
│  [RED]                    [GREEN]  │
│                                     │
│   Waiting for: [Blue, Red]          │
│   Timer: 25 seconds                 │
└─────────────────────────────────────┘
```

**Design Details:**
- **Center:** Question/situation description (short text)
- **Four Corners:** Each corner has a group of buttons for one player
  - **Top-Left:** Yellow player buttons
  - **Top-Right:** Blue player buttons
  - **Bottom-Left:** Red player buttons
  - **Bottom-Right:** Green player buttons
- **Color Coding:** Each corner group uses the player's color
- **Button Layout:** Buttons arranged vertically or horizontally within each corner group
- **Status Display:** Shows who is waiting and timer (can be at bottom or integrated)

### Button States

- **Available:** Normal color, clickable
- **Responded:** Enlarged, color changed/effect added, shows choice made
- **Waiting:** Highlighted, shows "Waiting..."
- **Timeout:** Auto-selects default (NO/IGNORE after 30 seconds)

---

## 🔄 Interaction Flow

### Example: Celebrity "Live Street Performance"

1. **Celebrity (active player) triggers action:**
   ```lua
   INT_StartInteraction({
     initiator = "Yellow",
     type = "OPTIONAL_COST",
     question = "Join Live Street Performance?",
     options = {"JOIN", "IGNORE"},
     targets = "ALL_OTHERS",  -- All other players
     costs = {JOIN = {ap = 1}},
     timeout = 30,
     onComplete = function(responses)
       -- Process responses
       for color, choice in pairs(responses) do
         if choice == "JOIN" then
           -- Deduct 1 AP, grant +2 Satisfaction
         end
       end
     end
   })
   ```

2. **Interaction Tile displays:**
   - Question: "Join Live Street Performance?"
   - Buttons for Blue, Red, Green (not Yellow - they're the initiator)
   - Each button: "JOIN (1 AP)" or "IGNORE"

3. **Other players click their buttons:**
   - Blue clicks "JOIN" → Response recorded, 1 AP deducted
   - Red clicks "IGNORE" → Response recorded
   - Green clicks "JOIN" → Response recorded, 1 AP deducted

4. **All responses collected:**
   - Callback executes
   - Celebrity gains +1 Skill & +150 VIN
   - Each joiner gains +2 Satisfaction
   - Interaction tile clears

---

## ⚙️ Implementation Details

### Integration Points

1. **VocationsController:**
   - Calls `INT_StartInteraction()` when vocation action requires player choices
   - Processes responses in callback

2. **Event Engine:**
   - May also use this system for event cards that require player choices

3. **AP Controller:**
   - Automatically deducts AP when player chooses option with AP cost

4. **Money Controller:**
   - Automatically deducts money when player chooses option with money cost

### Error Handling

- **Timeout:** If player doesn't respond in time, default to "NO"/"IGNORE" (or configurable default)
- **Player Disconnect:** Skip their response, continue with others
- **Invalid Choice:** Reject, show error, allow retry

### State Persistence

- Save active interaction state (for game saves)
- Resume interaction after load if it was in progress

---

## 📊 Complexity Assessment

### Difficulty: **MEDIUM-HIGH**

**Challenges:**
1. **UI Coordination:** Ensuring all players see the same state
2. **Timing:** Handling timeouts and auto-responses
3. **State Management:** Tracking who has responded, who is waiting
4. **Cost Deduction:** Automatically handling AP/money costs
5. **Multiple Simultaneous Interactions:** (Should be prevented - one at a time)

**Advantages:**
1. **Centralized:** All interactions in one place
2. **Clear:** Visual feedback for all players
3. **Reusable:** Can be used for any multi-player choice scenario
4. **Extensible:** Easy to add new interaction types

---

## 🎯 Recommended Implementation Phases

### Phase 1: Basic Binary Choice (2-3 hours)
- Simple YES/NO or JOIN/IGNORE
- One interaction at a time
- Basic timeout (30 seconds, default to NO)
- **Test with:** Simple vocation action (e.g., Celebrity Live Stream)

### Phase 2: Cost Integration (2-3 hours)
- Add AP/money cost deduction
- Validate player can afford before allowing choice
- **Test with:** Actions that require payment (e.g., Meet & Greet)

### Phase 3: Multiple Choice & Sequential (2-3 hours)
- Support 3+ options
- Sequential choices (multiple donations)
- **Test with:** Complex actions (e.g., Social Worker "Expose case")

### Phase 4: Polish & Edge Cases (1-2 hours)
- Better UI feedback
- Handle disconnects
- State persistence
- Error recovery

**Total Estimated Time:** 7-11 hours

---

## ✅ Design Decisions (Confirmed)

1. **Button Placement:** ✅ **Four corners, color-coded by player**
   - **Top-Left:** Yellow player buttons
   - **Top-Right:** Blue player buttons
   - **Bottom-Left:** Red player buttons
   - **Bottom-Right:** Green player buttons
   - Center shows question/situation description
   - Clear visual identification and organized layout

2. **Timeout Behavior:** ✅ **30 seconds, default to NO**
   - If player doesn't respond in 30 seconds, automatically choose NO/IGNORE
   - Simple and clear

3. **Visual Feedback:** ✅ **Easy implementation**
   - Enlarge button when selected
   - Change color or add color effect
   - Show which players have responded clearly

---

## ✅ Clarifications Received

### A) Sequential Choices (Same Interaction) - CLARIFIED

**Example:** Celebrity "Extended Charity Stream"

**Mechanic:**
1. **Initial Phase:** 30 seconds for players to join (click "pay 500 VIN")
2. **Extension Phase:** After last reaction, additional 10 seconds to decide if they want to pay more
3. **Cascading Timer:** If someone pays more during those 10 seconds, timer resets to 10 seconds again
4. **Completion:** If 10 seconds pass without any reaction, stream finishes

**Implementation:**
- Initial 30-second timer for first round of donations
- After last player responds, start 10-second extension timer
- Each new donation resets extension timer to 10 seconds
- Stream completes when 10 seconds pass with no donations

### B) Simultaneous Different Interactions - CLARIFIED

**Answer:** This will **NEVER happen** in the game.
- Players only react to one situation at a time
- Not a risk, no need to handle this case
- **Implementation:** No queue system needed, just prevent multiple interactions (safety check)

---

## ✅ Integration Decision

**Integration with Existing Systems:**
- ✅ **Work alongside EventEngine** (NOT replace it)
- EventEngine already works and handles active player choices
- InteractionController will handle **other players' choices** during vocation actions
- **Reason:** Don't want to make scripts too big (ShopEngine is already too big and slows down game)
- Keep systems separate and focused

---

## ⏸️ Implementation Timeline

**Status:** This system is for **FUTURE implementation**

**Current Priority:**
1. ✅ **First:** Implement Vocations system with primal mechanics
2. ⏸️ **Later:** After vocations are implemented, then step into interactions

**This proposal is documented for future reference when we're ready to implement the interaction system.**

---

## 💡 Alternative Approaches

### Option B: Broadcast + Response System
- Broadcast message to all players
- Each player responds via their own board/button
- No central tile needed
- **Pro:** Less UI complexity
- **Con:** Harder to coordinate, players might miss it

### Option C: Card-Based Choices
- Show choice on the event card itself
- Buttons appear on the card
- **Pro:** Context is clear (choice is on the card)
- **Con:** Only active player can see card clearly, others might miss it

**Recommendation:** Stick with Option A (Central Tile) - most visible and coordinated

---

## ✅ Next Steps

1. **Confirm Design:** Review this proposal, decide on approach
2. **Create InteractionController:** Basic structure and APIs
3. **Implement Phase 1:** Binary choices only
4. **Test with Simple Action:** Celebrity Live Stream
5. **Iterate:** Add features based on testing

---

---

## 📝 Sequential Choice Timer System (Detailed)

### Celebrity "Extended Charity Stream" Example

**Flow:**
1. **Start Interaction:** Celebrity triggers action
2. **Initial Timer:** 30 seconds for first round
   - Players can click "JOIN (500 VIN)" or "IGNORE"
   - Each join deducts 500 VIN immediately
3. **Extension Phase Begins:** After last player responds (or 30s timeout)
   - Start 10-second extension timer
   - Button remains active: "JOIN AGAIN (500 VIN)"
4. **Cascading Resets:**
   - If any player joins during extension: Reset timer to 10 seconds
   - Repeat until 10 seconds pass with no donations
5. **Stream Completes:** After 10 seconds of inactivity

**Implementation Notes:**
- Track last reaction time
- Reset extension timer on each donation
- Complete interaction when extension timer expires

---

**Status:** ✅ Design documented, ready for future implementation  
**Current Focus:** Implement Vocations system first, then interactions later
