# AP Controller (Player Board Action Points Controller) - Documentation

**Shared Script**: Used by all 4 AP Controllers (Blue, Green, Red, Yellow)  
**Version:** 2.8  
**Tags:** `WLB_AP_CTRL, WLB_COLOR_[Color], WLB_LAYOUT`

---

## Overview

The AP Controller manages each player's 12 Action Point tokens. It tracks where AP tokens are placed across different areas (Work, Rest, Events, School, Inactive) and provides an API for spending/moving AP. The system uses tag-based identification and probe-based calibration.

---

## Functionality

### Main Purpose
- **AP Token Management**: Manages 12 AP tokens per player
- **Area Tracking**: Tracks AP placement in 5 areas (W, R, E, SC, I)
- **Spending System**: Moves AP tokens from START to action areas
- **Calibration System**: Allows manual calibration of slot positions
- **Reset System**: Resets all AP to START position (soft animated or hard instant)

### Key Features
- Tag-driven token identification (no hardcoded GUIDs)
- Probe-based calibration (uses special probe token)
- Color-agnostic (reads color from self-tag)
- Dual reset modes (soft animated, hard instant)
- Comprehensive UI for manual control
- Engine API for automated AP spending

---

## Game Integration

### Related Objects
- **Player Board** - Board where AP tokens are placed (tag: `WLB_BOARD` + color tag)
- **AP Tokens** - 12 tokens per player (tag: `WLB_AP_TOKEN` + color tag)
- **AP Probe** - 1 probe token per player (tag: `WLB_AP_PROBE` + color tag)
- **Turn Controller** - Calls `WLB_AP_START_TURN()` hook

### Per-Player Instances
Each player has their own AP Controller:
- **PB AP CTRL B** (Blue) - GUID: `c8def5`
- **PB AP CTRL G** (Green) - GUID: `1063c2`
- **PB AP CTRL R** (Red) - GUID: `b2cbfa`
- **PB AP CTRL Y** (Yellow) - GUID: `83e61a`

All use identical script, only differ by:
- Object GUID
- Color tag (`WLB_COLOR_Blue`, `WLB_COLOR_Green`, etc.)
- Optional: `AP_NAME` fallback (e.g., "AP Y", "AP B") - not critical

---

## AP Areas

The system tracks 5 action areas:

1. **W (WORK)** - 9 slots max
2. **R (REST)** - 9 slots max
3. **E (EVENT/EVENTS)** - 9 slots max
4. **SC (SCHOOL)** - 3 slots max
5. **I (INACTIVE)** - 6 slots max

Plus:
- **START** - Starting position (all 12 tokens)

---

## UI Elements

### Setup Buttons
- **AP:BIND** - Binds to 12 AP tokens (excludes probe)
- **AP:START** - Saves starting positions of all 12 tokens
- **AP:RESET** - Soft reset (animated) - returns all AP to START

### Area Selection Buttons
- **WORK** - Select Work area
- **REST** - Select Rest area
- **EVT** - Select Events area
- **SCHOOL** - Select School area
- **INACT** - Select Inactive area
- **+** - Add AP token to selected area
- **-** - Remove AP token from selected area

### Calibration Buttons
- **CAL:W, CAL:R, CAL:E, CAL:SC, CAL:I** - Select calibration mode for area
- **CAL:CLEAR** - Clear calibration for selected area
- **DBG:GO** - Move probe to first saved slot in calibration mode
- **DBG:AP** - Print diagnostic info about AP tokens
- **1-9** - Save slot position (probe position → slot #)

---

## Setup Process

### Initial Setup (One-Time Per Controller)
1. **AP:BIND** - Scans for AP tokens with matching color tag, excludes probe
   - Verifies exactly 12 tokens found
   - Stores their GUIDs
   
2. **AP:START** - Records starting positions of all 12 tokens
   - Converts world positions to local board coordinates
   - Stores for reset functionality

3. **Calibration** - For each area that needs AP placement:
   - Select area (e.g., CAL:W for Work)
   - Position probe token at slot 1, click "1" button
   - Position probe at slot 2, click "2" button
   - Repeat for all slots (up to 9, or 3 for School, 6 for Inactive)

### Calibration Slots
- **Work/Rest/Events**: 9 slots each (1-9)
- **School**: 3 slots (1-3)
- **Inactive**: 6 slots (1-6)

---

## External API Functions

Other scripts can call these functions:

### `canSpendAP(params)`
- **Parameters**: Table with `amount` (number) and `to` (string: "W"/"R"/"E"/"SC"/"I")
- **Returns**: `true` if enough free tokens and slots, `false` otherwise
- **Usage**: Check if player can spend AP before attempting
- **Example**: `canSpendAP({amount=3, to="E"})`

### `spendAP(params)`
- **Parameters**: Table with `amount`, `to`, optional `duration`
- **Returns**: `true` if successful, `false` if failed
- **Usage**: Spend AP (moves tokens from START to area)
- **Example**: `spendAP({amount=2, to="R"})`

### `moveAP(params)`
- **Parameters**: Table with `amount` (positive to move to area, negative to return), `to`, optional `duration`
- **Returns**: Table with `ok`, `moved`, `requested`, `reason`
- **Usage**: Move AP tokens (more detailed than spendAP)
- **Example**: 
  - `moveAP({amount=3, to="W"})` - Move 3 to Work
  - `moveAP({amount=-2, to="W"})` - Return 2 from Work

### `getCount(params)`
- **Parameters**: Table with `field`/`area`/`to` (string: area name or "START")
- **Returns**: Number of tokens in specified area
- **Usage**: Check how many AP are in an area
- **Example**: 
  - `getCount({field="W"})` - Count in Work
  - `getCount({field="START"})` - Count available/unspent

### `getUnspentCount()`
- **Parameters**: None
- **Returns**: Number of tokens at START (available to spend)
- **Usage**: Check remaining AP

### `getState()`
- **Parameters**: None
- **Returns**: Table with complete state info:
  - `ok`, `version`, `colorTag`, `ready`, `reason`
  - `area`, `calMode`
  - `apCount`, `boundTokens`, `startSaved`
  - `counts` table with counts for each area
- **Usage**: Get full diagnostic/state information

### `resetNewGame()`
- **Parameters**: None
- **Returns**: Nothing
- **Usage**: Hard reset all AP to START (instant)
- **Called by**: Game reset systems

### `WLB_AP_START_TURN(params)`
- **Parameters**: Table with `blocked`/`inactive` (number of AP to block)
- **Returns**: Table with `ok`, `blocked`, `reason`
- **Usage**: Called by Turn Controller at start of player's turn
- **Behavior**: 
  - Hard resets all AP to START
  - Then moves specified number to INACTIVE (blocked)
  - Uses `Wait.frames(1)` to avoid physics desync
- **Example**: `WLB_AP_START_TURN({blocked=2})` - Reset, then block 2 AP

---

## Area Mapping

The system maps various names to internal area codes:
- "WORK"/"W" → W
- "REST"/"R" → R
- "EVENT"/"EVT"/"E" → E
- "SCHOOL"/"SC" → SC
- "INACTIVE"/"INACT"/"I" → I

---

## Technical Details

### Token Identification
- Uses tags: `WLB_AP_TOKEN` + player color tag
- Finds all matching tokens
- Excludes probe (tag: `WLB_AP_PROBE` + color tag)
- Verifies exactly 12 tokens

### Position System
- Uses local coordinates relative to player board
- Converts between local and world coordinates
- Stores calibration slots as local positions

### Reset Modes

**Soft Reset (ap_reset):**
- Uses `setPositionSmooth()` - animated movement
- Returns tokens to START positions
- User-friendly for manual use

**Hard Reset (ap_reset_hard):**
- Uses `setPosition()` - instant placement
- Also resets velocity, angular velocity, rotation
- Deterministic, used by engine systems
- Used in `resetNewGame()` and `WLB_AP_START_TURN()`

### Slot Tolerance
- `START_TOL = 0.75` - Distance tolerance for START position detection
- `SLOT_TOL = 0.75` - Distance tolerance for slot position detection

### Safety Features
- Verifies calibration exists before moving tokens
- Checks for free tokens before spending
- Validates free slots in target area
- Returns detailed error information

---

## Usage Examples

### Check Available AP
```lua
local apCtrl = getObjectFromGUID("c8def5") -- Blue player
local available = apCtrl.call("getUnspentCount")
print("Available AP: "..available)
```

### Spend AP (Event)
```lua
local canSpend = apCtrl.call("canSpendAP", {amount=1, to="E"})
if canSpend then
  local success = apCtrl.call("spendAP", {amount=1, to="E"})
  if success then
    print("Spent 1 AP on Event")
  end
end
```

### Check AP Distribution
```lua
local state = apCtrl.call("getState")
print("Work: "..state.counts.W)
print("Rest: "..state.counts.R)
print("Events: "..state.counts.E)
```

### Turn Start (with blocked AP)
```lua
local result = apCtrl.call("WLB_AP_START_TURN", {blocked=2})
if result.ok then
  print("Turn started, "..result.blocked.." AP blocked")
end
```

---

## Integration with Other Systems

### Turn Controller
- Calls `WLB_AP_START_TURN()` at start of each player's turn
- Can specify blocked/inactive AP count

### Event Engine / Shop Engine
- Use `spendAP()` to deduct AP for actions
- Check `canSpendAP()` before allowing actions

### Costs Calculator
- Uses AP spending API indirectly through other engines

---

## Notes

- Script is color-agnostic - determines player from self color tag
- `AP_NAME` fallback may differ per controller but is rarely used
- Requires probe token for calibration
- Calibration must be done once per area
- Hard reset is instant, soft reset is animated
- System prevents spending more AP than available or slots available

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Shared Script** - Used by all 4 AP Controllers (Blue, Green, Red, Yellow)  
✅ **Verified** - All 4 controllers use identical script (color determined from tags)
