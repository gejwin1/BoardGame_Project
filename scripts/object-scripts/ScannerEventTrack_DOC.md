# Object #23: SCANNER Event Track (Event Track Locator)

## 📋 Overview
The `SCANNER Event Track` script (`ScannerEventTrack.lua`) is a calibration/development tool used to measure the positions of various locations on the Event Board. It helps configure the Event Engine by finding local coordinates for the deck position, used pile position, and all 7 event card slots (S1-S7). This is a setup/calibration utility, not a gameplay tool.

## 🚀 Functionality
- **Position Measurement**: Measures positions of event track locations relative to the Event Board
- **Multiple Targets**: Supports 9 different target positions:
  - `DECK`: Event deck position
  - `USED`: Used event cards pile position
  - `S1` through `S7`: Individual event card slots (1-7)
- **Coordinate Conversion**: Converts world coordinates to local board coordinates
- **Code Generation**: Outputs ready-to-paste Lua code for Event Engine configuration
- **Validation**: Verifies coordinate conversion accuracy

## 🔗 External API
- None explicitly exposed for other scripts to call (primarily a utility tool)
- Outputs formatted code for integration into Event Engine's position tables

## ⚙️ Configuration
- `EVENT_BOARD_GUID`: `"d031d9"` (GUID of the Event Board, used as anchor for coordinate conversion)
- `DECIMALS`: `3` (Number of decimal places for coordinate formatting)
- `target`: Current target selection (`"DECK"`, `"USED"`, or `"S1"` through `"S7"`)

## 🎮 UI Elements
The tool provides a user interface with:
1. **Header Button** (Top): Displays current target mode and instruction
2. **Row 1**: 
   - `DECK` button: Set target to deck position
   - `USED` button: Set target to used pile position
3. **Row 2**: 
   - `S1`, `S2`, `S3`, `S4` buttons: Set target to slots 1-4
4. **Row 3**: 
   - `S5`, `S6`, `S7` buttons: Set target to slots 5-7
5. **PRINT LOCAL Button** (Bottom): Calculates and prints local coordinates for current target

## 📊 Output Format
When PRINT is clicked, outputs detailed information including:
```
=== EVENT TRACK LOCATOR v1 ===
CLICKED BY: [player color]
TARGET=[target] ([key])
EVENT_BOARD GUID=[guid]
TOKEN WORLD = {x, y, z}
BOARD WORLD = {x, y, z}
LOCAL@EVENT_BOARD = {x, y, z}
WORLD(check) = {x, y, z} | ERR=[error]

PASTE LINE:
  [key] = {x=X.XXX, y=Y.YYY, z=Z.ZZZ},
```

**Example Output for Slot 1:**
```
PASTE LINE:
  slot1 = {x=1.259, y=0.592, z=-0.238},
```

This can be directly copied into the Event Engine's position configuration tables.

## 🔄 Usage Workflow
1. **Place Tile**: Physically move the scanner tile to the desired point on the Event Track
2. **Select Target**: Click the appropriate button (DECK, USED, or S1-S7) to set the target
3. **Print**: Click "PRINT LOCAL" to calculate and output local coordinates
4. **Copy to Code**: Paste the output line into Event Engine's configuration

## 🔗 Integration with Other Systems
- **Event Engine**: Uses the measured coordinates in position tables for:
  - Event deck placement
  - Used pile placement
  - Event card slot positions (1-7)

## ⚠️ Notes
- This is a calibration/development tool, not used during gameplay
- Must be placed physically on the desired position before printing
- Output is validated (error calculation shows conversion accuracy)
- Coordinates are in local board space (relative to Event Board)
- Tool is for one-time setup of event track positions
- The Event Board GUID (`d031d9`) is hardcoded and should match your game's Event Board
