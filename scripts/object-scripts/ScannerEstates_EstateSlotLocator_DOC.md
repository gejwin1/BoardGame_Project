# SCANNER Estates (Estate Slot Locator) - Documentation

**GUID:** `[Need to verify - likely one of the SCANNER objects]`  
**Tags:** (no tags)  
**Type:** Tile  
**Version:** 3.0

---

## Overview

The Estate Slot Locator is a calibration/development tool used to find the local coordinates of estate slots on player boards. It helps configure the Estate Engine by measuring where estate cards should be placed on each player's board. This is a setup/calibration utility, not a gameplay tool.

---

## Functionality

### Main Purpose
- **Position Measurement**: Measures the position of an estate slot relative to a player board
- **Coordinate Conversion**: Converts world coordinates to local board coordinates
- **Code Generation**: Outputs ready-to-paste Lua code for Estate Engine configuration

### Key Features
- Automatic board detection (finds nearest board)
- Manual board selection (force specific color)
- Local coordinate calculation
- Validation (checks coordinate conversion accuracy)
- Ready-to-paste output format

---

## Game Integration

### Related Objects
- **Player Boards** - Boards where estates are placed (tag: `WLB_BOARD` + color tag)
- **Estate Engine** - Uses the output coordinates for estate placement

### Usage Workflow
1. **Place Token**: Physically place the scanner token on the estate slot of a player board
2. **Select Board**: Choose target board (AUTO or force color)
3. **Print**: Get local coordinates relative to that board
4. **Copy to Code**: Paste the output into Estate Engine's `ESTATE_SLOT_LOCAL` table

---

## UI Elements

### Mode Display Button (Top)
- **Label**: "MODE: [mode]\n(click=Auto)"
- **Function**: Click to set AUTO mode
- **Tooltip**: "Click to set AUTO mode (nearest board)."

### Color Selection Buttons (Middle Row)
- **Y** (Yellow) - Force target board = Yellow
- **B** (Blue) - Force target board = Blue
- **R** (Red) - Force target board = Red
- **G** (Green) - Force target board = Green

### PRINT LOCAL Button (Bottom)
- **Label**: "PRINT\nLOCAL"
- **Function**: Calculates and prints local coordinates
- **Tooltip**: "Print LOCAL offset of token relative to chosen board (AUTO or forced)."

---

## How It Works

### AUTO Mode
1. Gets scanner token's world position
2. Finds all player boards (by tags)
3. Calculates distance to each board
4. Selects nearest board automatically

### Manual Mode (Color Selection)
1. User clicks Y/B/R/G button
2. System finds board with matching color tag
3. Uses that board for calculation

### Coordinate Calculation
1. **Get Positions**:
   - Token world position (current position of scanner)
   - Board world position (center of selected board)

2. **Convert to Local**:
   - Uses `board.positionToLocal(tokenWorld)` to get local coordinates
   - Local coordinates are relative to board's origin

3. **Validate**:
   - Converts local back to world: `board.positionToWorld(localPos)`
   - Calculates error distance
   - Shows error for verification

4. **Output**:
   - Prints detailed information
   - Provides ready-to-paste code for Estate Engine

---

## Output Format

When PRINT is clicked, outputs:

```
=== ESTATE SLOT LOCATOR v3 ===
CLICKED BY: [player color] | MODE: [mode]
TARGET: [chosen color]
BOARD: [board name] ([board GUID])
TOKEN WORLD = {x, y, z}
BOARD WORLD = {x, y, z}
LOCAL@BOARD = {x, y, z}
WORLD(check) = {x, y, z} | ERR=[error]

PASTE INTO MARKETENGINE:
  [Color] = {x=X.XXX, y=Y.YYY, z=Z.ZZZ},
```

**Example Output:**
```
PASTE INTO MARKETENGINE:
  Yellow = {x=1.259, y=0.592, z=-0.238},
```

This can be directly copied into the Estate Engine's `ESTATE_SLOT_LOCAL` table.

---

## Technical Details

### Coordinate System
- **World Coordinates**: Absolute 3D position on table
- **Local Coordinates**: Position relative to board's local origin
- **Conversion**: Uses Tabletop Simulator's `positionToLocal()` and `positionToWorld()`

### Board Finding
- Uses tag-based search: `WLB_BOARD` + `WLB_COLOR_[Color]`
- If multiple boards match, selects largest (by area/bounds)
- Distance calculated using 2D distance (ignores Y height)

### Precision
- Coordinates formatted to 3 decimal places
- Error calculation shows conversion accuracy
- Low error (< 0.001) indicates good measurement

---

## Usage Examples

### Calibrate Yellow Player Estate Slot
1. Place scanner token on Yellow player's estate slot
2. Click "Y" button (force Yellow board)
3. Click "PRINT LOCAL"
4. Copy output: `Yellow = {x=1.259, y=0.592, z=-0.238},`
5. Paste into Estate Engine code

### Auto-Detect Nearest Board
1. Place scanner token on any estate slot
2. Click "MODE" button (ensure AUTO mode)
3. Click "PRINT LOCAL"
4. System automatically finds nearest board
5. Copy output code

---

## Integration with Other Systems

### Estate Engine
- Uses the measured coordinates in `ESTATE_SLOT_LOCAL` table:
  ```lua
  local ESTATE_SLOT_LOCAL = {
    Yellow = {x=1.259, y=0.592, z=-0.238},  -- From this tool
    Blue   = {x=1.265, y=0.592, z=-0.198},  -- From this tool
    -- etc.
  }
  ```

---

## Notes

- This is a calibration/development tool, not used during gameplay
- Must be placed physically on the estate slot before printing
- Output is validated (error calculation)
- Coordinates are in local board space (relative to board)
- Tool is for one-time setup of estate slot positions

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Utility Tool** - Used for calibration/development, not gameplay
