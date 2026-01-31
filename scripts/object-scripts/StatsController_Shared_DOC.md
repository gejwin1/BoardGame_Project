# Stats Controller (Player Board Stats Controller) - Documentation

**Shared Script**: Used by all 4 Stats Controllers (Blue, Green, Red, Yellow)  
**Version:** 2.1  
**Tags:** `WLB_STATS_CTRL, WLB_COLOR_[Color], WLB_LAYOUT`

---

## Overview

The Stats Controller manages each player's three core stats: Health (H), Knowledge (K), and Skills (S). It tracks these values and positions the corresponding tokens on the player board. Similar to the AP Controller, it uses tag-based identification and calibration system for token positioning.

---

## Functionality

### Main Purpose
- **Stat Tracking**: Tracks 3 stats per player:
  - **Health (H)**: Range 0-9 (starts at 9)
  - **Knowledge (K)**: Range 0-15 (starts at 0)
  - **Skills (S)**: Range 0-15 (starts at 0)
- **Token Positioning**: Moves stat tokens to calibrated positions on player board
- **Calibration System**: Allows manual calibration of token positions for each stat value
- **External API**: Provides functions for other scripts to read/modify stats

### Key Features
- Tag-driven token identification (finds tokens by color + stat tag)
- Color-agnostic (reads color from self-tag)
- Calibration system for positioning (like AP Controller)
- Manual +/- controls for each stat
- External API for automated stat changes
- Persistence across game saves

---

## Game Integration

### Related Objects
- **Player Board** - Board where stat tokens are placed (tag: `WLB_BOARD` + color tag)
- **Health Token** - Token showing health level (tag: `WLB_HEALTH_TOKEN` + color tag)
- **Knowledge Token** - Token showing knowledge level (tag: `WLB_KNOWLEDGE_TOKEN` + color tag)
- **Skills Token** - Token showing skills level (tag: `WLB_SKILLS_TOKEN` + color tag)

### Per-Player Instances
Each player has their own Stats Controller:
- **PB STATS CTRL B** (Blue) - GUID: `810632`
- **PB STATS CTRL G** (Green) - GUID: `e16455`
- **PB STATS CTRL R** (Red) - GUID: `3cefbd`
- **PB STATS CTRL Y** (Yellow) - GUID: `9c7a4a`

All use identical script, only differ by:
- Object GUID
- Color tag (`WLB_COLOR_Blue`, `WLB_COLOR_Green`, etc.)

---

## Stat Ranges

- **Health (H)**: 0-9 (default: 9)
- **Knowledge (K)**: 0-15 (default: 0)
- **Skills (S)**: 0-15 (default: 0)

---

## UI Elements

### Stat Control Buttons
- **H-** / **H+** - Decrease/Increase Health (0-9)
- **K-** / **K+** - Decrease/Increase Knowledge (0-15)
- **S-** / **S+** - Decrease/Increase Skills (0-15)

### Calibration Buttons
- **CAL:H** - Select Health calibration mode (slots 0-9)
- **CAL:K** - Select Knowledge calibration mode (slots 0-15)
- **CAL:S** - Select Skills calibration mode (slots 0-15)
- **0-15** - Save slot position (current token position → slot #)

---

## Setup Process

### Calibration (One-Time Per Stat)

1. **Position Token**: Move the stat token (Health, Knowledge, or Skills) to desired position for value 0
2. **Select Mode**: Click CAL:H, CAL:K, or CAL:S
3. **Save Position**: Click "0" button
4. **Repeat**: Move token to position for value 1, click "1", etc.
   - Health: Calibrate positions 0-9
   - Knowledge: Calibrate positions 0-15
   - Skills: Calibrate positions 0-15

Once calibrated, tokens automatically move to correct positions when stats change.

---

## External API Functions

Other scripts can call these functions:

### `getHealth()`
- **Parameters**: None
- **Returns**: Current health value (0-9)
- **Usage**: Check player's current health
- **Example**: `local health = statsCtrl.call("getHealth")`

### `getState()`
- **Parameters**: None
- **Returns**: Table with all three stats: `{h=health, k=knowledge, s=skills}`
- **Usage**: Get all stats at once
- **Example**: 
  ```lua
  local stats = statsCtrl.call("getState")
  print("Health: "..stats.h..", Knowledge: "..stats.k..", Skills: "..stats.s)
  ```

### `applyDelta(params)`
- **Parameters**: Table with `h`, `k`, `s` fields (delta values)
- **Returns**: Table with `ok`, `h`, `k`, `s` (new values after applying)
- **Usage**: Modify stats by delta values (can be positive or negative)
- **Example**: 
  ```lua
  statsCtrl.call("applyDelta", {h=-1, k=+2, s=0}) -- Lose 1 health, gain 2 knowledge
  ```

### `adultStart_apply(params)`
- **Parameters**: Table with `k` and `s` fields (knowledge and skills to add)
- **Returns**: Table with `ok`, `addedK`, `addedS`, `beforeK`, `beforeS`, `afterK`, `afterS`
- **Usage**: Add knowledge and skills at start of Adult age (transition from Youth)
- **Example**: `adultStart_apply({k=5, s=3})` - Add 5 knowledge and 3 skills

### `resetNewGame()`
- **Parameters**: None
- **Returns**: Nothing
- **Usage**: Reset all stats to starting values (H=9, K=0, S=0)
- **Called by**: Game reset systems

---

## Technical Details

### Token Identification
- Uses tags to find tokens:
  - Health: `WLB_HEALTH_TOKEN` + player color tag
  - Knowledge: `WLB_KNOWLEDGE_TOKEN` + player color tag
  - Skills: `WLB_SKILLS_TOKEN` + player color tag

### Position System
- Uses local coordinates relative to player board
- Stores calibrated positions in arrays:
  - `healthPos[0..9]` - Positions for health values 0-9
  - `knowledgePos[0..15]` - Positions for knowledge values 0-15
  - `skillsPos[0..15]` - Positions for skills values 0-15
- Converts local positions to world coordinates for token placement

### Persistence
- Saves state as custom string format:
  - Current stat values (H, K, S)
  - Calibration mode (M)
  - All calibrated positions (HP:, KP:, SP:)
- Restores state on load

### Stat Clamping
- All stats are clamped to valid ranges:
  - Health: 0-9
  - Knowledge: 0-15
  - Skills: 0-15
- Values outside range are automatically corrected

---

## Usage Examples

### Check Player Stats
```lua
local statsCtrl = getObjectFromGUID("810632") -- Blue player
local health = statsCtrl.call("getHealth")
local stats = statsCtrl.call("getState")
print("Health: "..health..", Knowledge: "..stats.k..", Skills: "..stats.s)
```

### Modify Stats (Event Effect)
```lua
-- Player gains 2 knowledge, loses 1 health
local result = statsCtrl.call("applyDelta", {h=-1, k=2, s=0})
if result.ok then
  print("Stats updated: H="..result.h.." K="..result.k.." S="..result.s)
end
```

### Adult Age Transition
```lua
-- At start of Adult age, add accumulated knowledge/skills from Youth
local result = statsCtrl.call("adultStart_apply", {k=5, s=3})
print("Added "..result.addedK.." knowledge and "..result.addedS.." skills")
```

### Reset for New Game
```lua
statsCtrl.call("resetNewGame")
-- Health reset to 9, Knowledge and Skills reset to 0
```

---

## Integration with Other Systems

### Turn Controller / Event Engine
- May call `applyDelta()` when events modify player stats
- Uses `getState()` to check current stat values

### Youth → Adult Transition
- Calls `adultStart_apply()` to transfer accumulated stats from Youth age
- Adds knowledge and skills earned during Youth phase

---

## Notes

- Script is color-agnostic - determines player from self color tag
- Token positioning requires calibration before use
- All stat changes automatically move tokens to correct positions
- Stats are persistent across game saves
- Health starts at 9 (max), Knowledge and Skills start at 0

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Shared Script** - Used by all 4 Stats Controllers (Blue, Green, Red, Yellow)  
✅ **Similar to AP Controller** - Uses same tag-driven, calibration-based approach
