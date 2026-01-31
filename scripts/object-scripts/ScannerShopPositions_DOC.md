# Object #26: SCANNER Shop Positions (Shop Slot Locator)

## 📋 Overview
The `SCANNER Shop Positions` script (`ScannerShopPositions.lua`) is a calibration/development tool used to measure shop slot positions on the Shops Board. It helps configure the Shop Engine by finding local coordinates for where shop cards should be placed. The tool supports three shop rows (Consumables, Hi-Tech, Investments) and four slot positions per row (Closed, Open1, Open2, Open3). This is a setup/calibration utility, not a gameplay tool.

## 🚀 Functionality
- **Position Measurement**: Measures the position of shop slots relative to the Shops Board
- **Multiple Rows**: Supports three shop categories:
  - **C**: Consumables
  - **H**: Hi-Tech
  - **I**: Investments
- **Multiple Slots**: Supports four slot positions per row:
  - **C**: Closed (dark slot)
  - **O1**: Open slot 1
  - **O2**: Open slot 2
  - **O3**: Open slot 3
- **Coordinate Conversion**: Converts world coordinates to local board coordinates
- **Code Generation**: Outputs ready-to-paste Lua code for Shop Engine configuration
- **Validation**: Checks coordinate conversion accuracy

## 🔗 External API
- None explicitly exposed for other scripts to call (primarily a utility tool)
- Outputs formatted code for integration into Shop Engine's position tables

## ⚙️ Configuration
- `TAG_SHOP_BOARD`: `"WLB_SHOP_BOARD"` (Tag required on the Shops Board anchor object)
- `DECIMALS`: `3` (Number of decimal places for coordinate formatting)
- `selRow`: Current row selection (`"C"`, `"H"`, or `"I"`)
- `selSlot`: Current slot selection (`"C"`, `"O1"`, `"O2"`, or `"O3"`)

## 🎮 UI Elements

### Header Button (Top)
- **Label**: "ROW: [selRow] ([rowName])\nSLOT: [selSlot] ([keyName])"
- **Function**: Display only (noop function)
- **Shows**: Current row and slot selection with friendly names

### Row Selection Buttons (Middle Row)
- **C**: Set row to Consumables
- **H**: Set row to Hi-Tech
- **I**: Set row to Investments

### Slot Selection Buttons (Lower Row)
- **C**: Set slot to Closed (dark slot)
- **O1**: Set slot to Open 1
- **O2**: Set slot to Open 2
- **O3**: Set slot to Open 3

### PRINT LOCAL Button (Bottom)
- **Label**: "PRINT\nLOCAL"
- **Function**: Calculates and prints local coordinates
- **Tooltip**: "Print LOCAL@SHOPBOARD for the token position."

## 📊 Output Format

When PRINT is clicked, outputs:

```
=== SHOP SLOT LOCATOR v1 ===
CLICKED BY: [player color]
ROW=[selRow] ([rowName]) | SLOT=[selSlot] ([keyName])
SHOPBOARD: [board name] ([board GUID])
TOKEN WORLD = {x, y, z}
BOARD WORLD = {x, y, z}
LOCAL@SHOPBOARD = {x, y, z}
WORLD(check) = {x, y, z} | ERR=[error]

PASTE LINE:
  [RowName].[keyName] = {x=X.XXX, y=Y.YYY, z=Z.ZZZ},
```

**Example Output for Consumables Closed slot:**
```
PASTE LINE:
  CONSUMABLES.closed = {x=1.259, y=0.592, z=-0.238},
```

**Example Output for Hi-Tech Open 2 slot:**
```
PASTE LINE:
  HITECH.open2 = {x=0.450, y=0.592, z=0.120},
```

This can be directly copied into the Shop Engine's position configuration tables.

## 🔄 Usage Workflow

### Calibrate Shop Slots
1. Place scanner token on the desired shop slot position on the Shops Board
2. Select **ROW** (C, H, or I) corresponding to the shop category
3. Select **SLOT** (C, O1, O2, or O3) corresponding to the slot position
4. Click **PRINT LOCAL**
5. Copy the output line (format: `[RowName].[keyName] = {x, y, z},`)
6. Paste into Shop Engine code

### Example: Calibrate All 12 Positions (3 rows × 4 slots)
- Consumables: closed, open1, open2, open3
- Hi-Tech: closed, open1, open2, open3
- Investments: closed, open1, open2, open3

For each position:
1. Place token on slot
2. Select appropriate row and slot
3. Click PRINT
4. Copy output line

## 🔧 Technical Details

### Shop Board Detection
- Searches for objects with tag `WLB_SHOP_BOARD`
- If multiple objects found, selects the largest one (by area/bounds)
- Uses `getBoundsNormalized()` to calculate surface area

### Coordinate System
- **World Coordinates**: Absolute 3D position on table
- **Local Coordinates**: Position relative to Shops Board's local origin
- **Conversion**: Uses Tabletop Simulator's `positionToLocal()` and `positionToWorld()`

### Precision
- Coordinates formatted to 3 decimal places
- Error calculation shows conversion accuracy
- Low error (< 0.001) indicates good measurement

### Key Naming Convention
- **Row Names**: `CONSUMABLES`, `HITECH`, `INVEST`
- **Slot Keys**: `closed`, `open1`, `open2`, `open3`
- **Output Format**: `[RowName].[keyName]` (e.g., `CONSUMABLES.closed`)

## 🔗 Integration with Other Systems

### Shop Engine
- Uses the measured coordinates in position tables for:
  - Card placement in shop slots
  - Opening/closing shop slots
  - Managing shop card inventory positions

**Example Integration:**
```lua
local SHOP_SLOT_POSITIONS = {
  CONSUMABLES = {
    closed = {x=1.259, y=0.592, z=-0.238},  -- From this tool
    open1  = {x=1.450, y=0.592, z=-0.238},  -- From this tool
    open2  = {x=1.641, y=0.592, z=-0.238},  -- From this tool
    open3  = {x=1.832, y=0.592, z=-0.238},  -- From this tool
  },
  HITECH = {
    closed = {x=0.500, y=0.592, z=0.000},   -- From this tool
    open1  = {x=0.691, y=0.592, z=0.000},   -- From this tool
    -- ... etc
  },
  INVEST = {
    -- ... etc
  },
}
```

## ⚠️ Notes
- This is a calibration/development tool, not used during gameplay
- Must be placed physically on the shop slot before printing
- Output is validated (error calculation shows conversion accuracy)
- Coordinates are in local board space (relative to Shops Board)
- Tool is for one-time setup of shop slot positions
- The Shops Board must have the `WLB_SHOP_BOARD` tag
- Supports 12 total positions (3 rows × 4 slots)
