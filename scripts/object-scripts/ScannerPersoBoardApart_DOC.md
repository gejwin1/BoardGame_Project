# Object #24: SCANNER PersoBoard + Apart (Family Slot Locator)

## 📋 Overview
The `SCANNER PersoBoard + Apart` script (`ScannerPersoBoardApart.lua`) is an advanced calibration/development tool used to measure family member slot positions. It supports two measurement modes:
- **BOARD Mode**: Measures L0 slots (grandma room) on player boards (per color)
- **CARD Mode**: Measures L1-L4 slots on estate cards (per level)

Unlike simpler locators, this tool uses a probe token (tagged `WLB_PROBE`) to detect positions via raycasting, supports multiple slots per level, and exports comprehensive Lua table structures ready for integration into game engines.

## 🚀 Functionality

### Dual Mode Operation
- **BOARD Mode**: 
  - Measures positions relative to Player Boards (tag: `WLB_BOARD`)
  - Stores data per player color (Yellow, Blue, Red, Green)
  - Only L0 level supported (grandma room printed on board)
  - Uses raycasting to detect board under probe

- **CARD Mode**:
  - Measures positions relative to Estate Cards (tag: `WLB_ESTATE_CARD` or any Card)
  - Stores data per level (L1, L2, L3, L4)
  - Supports multiple slots per level (1-30)
  - Uses raycasting to detect estate card under probe

### Key Features
- **Probe-Based Detection**: Uses a separate probe token (tagged `WLB_PROBE`) for position measurement
- **Raycasting**: Physics raycast downward to detect objects (boards or cards) under the probe
- **Multiple Slots**: Supports up to 30 slots per level (incremented/decremented via buttons)
- **Per-Color Storage**: Board slots stored separately for each player color
- **Per-Level Storage**: Card slots stored separately for each estate level
- **Export System**: Generates complete Lua table structures (`FAMILY_SLOTS_BOARD` and `FAMILY_SLOTS_CARD`)
- **Clear Function**: Clears captured data for current context (board color or card level)

## 🔗 External API
- None explicitly exposed for other scripts to call (primarily a utility tool)
- Exports formatted Lua tables for integration into game engines that manage family member placement

## ⚙️ Configuration
- `DEBUG`: `true` (Controls console logging)
- `TAG_PROBE`: `"WLB_PROBE"` (Tag for the probe token used for measurements)
- `TAG_BOARD`: `"WLB_BOARD"` (Tag for player boards)
- `TAG_ESTATECARD`: `"WLB_ESTATE_CARD"` (Preferred tag for estate cards)
- `COLORS`: `{"Yellow","Red","Blue","Green"}` (Player colors)
- `MODE`: Current mode (`"BOARD"` or `"CARD"`)
- `curLevel`: Current level (`"L0"` for board, `"L1"` through `"L4"` for cards)
- `curIndex`: Current slot number (1-30)

## 🎮 UI Elements

### Button Layout (6 buttons, vertical stack)

1. **MODE Button** (Top):
   - **Label**: "MODE: [BOARD|CARD]"
   - **Function**: Toggles between BOARD and CARD modes
   - **Auto-adjusts**: Level switches to L0 (BOARD) or L1 (CARD) when mode changes

2. **LEVEL Button**:
   - **Label**: "LEVEL: [L0|L1|L2|L3|L4]"
   - **Function**: Cycles through available levels
   - **BOARD mode**: Stays at L0 (only option)
   - **CARD mode**: Cycles L1 → L2 → L3 → L4 → L1

3. **SLOT Button**:
   - **Label**: "SLOT: [1-30]"
   - **Function**: 
     - Normal click: Increment slot number
     - Alt-click: Decrement slot number
   - **Range**: 1 to 30

4. **CAPTURE Button**:
   - **Label**: "CAPTURE"
   - **Function**: Captures current probe position relative to detected board/card
   - **Process**:
     1. Finds probe token (tagged `WLB_PROBE`)
     2. Raycasts down from probe position
     3. Detects board (BOARD mode) or estate card (CARD mode)
     4. Converts probe world position to local coordinates
     5. Stores in appropriate data structure

5. **EXPORT Button**:
   - **Label**: "EXPORT"
   - **Function**: Generates and prints complete Lua table export to console
   - **Output**: Two tables:
     - `FAMILY_SLOTS_BOARD`: Per-color L0 slots
     - `FAMILY_SLOTS_CARD`: Per-level L1-L4 slots

6. **CLEAR Button**:
   - **Label**: "CLEAR"
   - **Function**: Clears captured data for current context
   - **BOARD mode**: Clears L0 slots for detected board color (or Yellow if can't detect)
   - **CARD mode**: Clears slots for current level (L1-L4)

## 🔄 Usage Workflow

### Calibrating Board Slots (L0 - Grandma Room)
1. Switch to BOARD mode (click MODE button)
2. Ensure LEVEL is L0
3. Place probe token on the first slot position
4. Set SLOT to 1
5. Click CAPTURE
6. Move probe to next slot, increment SLOT, repeat
7. Repeat for all player colors (move to different boards)
8. Click EXPORT to get code

### Calibrating Card Slots (L1-L4)
1. Switch to CARD mode (click MODE button)
2. Place an L1 estate card on the table
3. Set LEVEL to L1 (or desired level)
4. Place probe token on first slot position
5. Set SLOT to 1
6. Click CAPTURE
7. Move probe, increment SLOT, repeat for all slots on that card
8. Switch to L2 card, set LEVEL to L2, repeat
9. Repeat for L3 and L4
10. Click EXPORT to get code

## 📊 Export Format

The EXPORT function generates two Lua tables:

```lua
-- === WLB FAMILY SLOTS EXPORT ===
local FAMILY_SLOTS_BOARD = {
  Yellow = { L0 = {
    [1] = {x=1.259, y=0.592, z=-0.238},
    [2] = {x=1.450, y=0.592, z=-0.238},
    -- ... more slots
  } },
  Red = { L0 = {
    -- ... slots
  } },
  Blue = { L0 = {
    -- ... slots
  } },
  Green = { L0 = {
    -- ... slots
  } },
}

local FAMILY_SLOTS_CARD = {
  L1 = {
    [1] = {x=0.500, y=0.100, z=0.300},
    [2] = {x=0.700, y=0.100, z=0.300},
    -- ... more slots
  },
  L2 = {
    -- ... slots
  },
  L3 = {
    -- ... slots
  },
  L4 = {
    -- ... slots
  },
}
```

This structure can be directly integrated into game engines that manage family member token placement.

## 🔧 Technical Details

### Raycasting
- **Origin**: Probe position + 2.0 units up (Y+2)
- **Direction**: Down (0, -1, 0)
- **Max Distance**: 6 units
- **Purpose**: Detects boards/cards directly under the probe

### Coordinate Conversion
- Uses `board.positionToLocal(probeWorldPos)` or `card.positionToLocal(probeWorldPos)`
- Stores as `{x, y, z}` table in local coordinate space
- Coordinates formatted to 3 decimal places

### Data Storage
- **Board Slots**: Nested structure `boardSlots[Color].L0[slotIndex] = {x, y, z}`
- **Card Slots**: Nested structure `cardSlots[Level][slotIndex] = {x, y, z}`
- Sparse arrays: Only captured slots are stored (missing indices skipped)

### Color Detection
- Searches for color tags: `WLB_COLOR_Yellow`, `WLB_COLOR_Blue`, etc.
- Falls back to "Unknown" if no color tag found (with warning)
- Auto-detects board color from probe position

## 🔗 Integration with Other Systems

### Family Member System
The exported tables are designed for integration into systems that:
- Place family member tokens on player boards (L0 slots)
- Place family member tokens on estate cards (L1-L4 slots)
- Manage family member movement between locations

## ⚠️ Notes
- This is a calibration/development tool, not used during gameplay
- Requires a separate probe token tagged with `WLB_PROBE`
- Probe must be placed accurately on slot positions before capturing
- Board mode requires boards to have both `WLB_BOARD` and `WLB_COLOR_*` tags
- Card mode prefers `WLB_ESTATE_CARD` tag but falls back to any Card type
- Export prints to console (not broadcast) - check TTS console log
- Data is not persisted across game reloads (development tool, not runtime)
- Supports up to 30 slots per level (may need adjustment for games with more slots)
