# Object #38: WLB Control (DEPRECATED/LEGACY)

## ⚠️ Status: DEPRECATED
**This object is no longer used and will be deleted soon.** Most of its functionality has been moved to other controllers (e.g., `WLB_TURN_CONTROLLER`). This documentation is preserved for historical reference.

## 📋 Overview
The `WLB Control` script (`1b53e4_WLBControl.lua`) was a central control panel for game setup and reset operations. It provided functions for capturing/restoring game layout, collecting satisfaction tokens, resetting game state for new games (Youth/Adult modes), and finding lost game elements. Version 1.3.2.

## 🚀 Functionality (Historical)

### Layout Management
- **CAPTURE LAYOUT**: Captures positions, rotations, and scales of all objects tagged with `WLB_LAYOUT`
- **RESTORE LAYOUT**: Restores previously captured layout (useful for resetting game table after setup)
- **Persistence**: Layout data saved in script state

### Satisfaction Token Management
- **SAT: COLLECT**: Collects all satisfaction tokens (`SAT_TOKEN` tag) near the control panel
- **Reset to 10**: Resets all satisfaction tokens to starting value (10) during new game setup

### New Game Setup
- **YOUTH Mode**: 
  - Restores layout
  - Resets satisfaction tokens to 10
  - Sets Year Token to round 1
  - Resets Stats Controllers, AP Controllers, Money Controllers
  - Resets Youth Event Deck via Event Controller
  - Sets Adult Start mode to false

- **ADULT Mode**:
  - Restores layout
  - Resets satisfaction tokens to 10
  - Sets Year Token to round 6
  - Resets Stats Controllers, AP Controllers, Money Controllers
  - Sets Adult Start mode to true

### Lost Element Finding
- **SAT Collection**: Could find satisfaction tokens by tag or name pattern (fallback)
- **Generic Reset**: Could reset controllers by tag (`WLB_STATS_CTRL`, `WLB_AP_CTRL`, `WLB_MONEY`)

## 🔗 External API

### Layout Functions
- `captureLayout()`: Captures current layout of all `WLB_LAYOUT` tagged objects
- `restoreLayout()`: Restores previously captured layout

### New Game Functions
- `newGameYouth()`: Sets up new game in Youth mode (round 1)
- `newGameAdult()`: Sets up new game in Adult mode (round 6)

### Utility Functions
- `sat_collect()`: Collects satisfaction tokens near control panel
- `resetSatisfactionTo10()`: Resets all satisfaction tokens to value 10
- `resetByTag(tag, label)`: Generic reset function for controllers by tag
- `setTokenYearRound(r)`: Sets Year Token to specific round
- `setAdultStartMode(isAdult)`: Sets Adult Start Manager mode

## ⚙️ Configuration

### Tags Used
- `WLB_LAYOUT`: Tag for objects to capture/restore layout
- `SAT_TOKEN`: Tag for satisfaction tokens
- `WLB_STATS_CTRL`: Tag for Stats Controllers
- `WLB_AP_CTRL`: Tag for AP Controllers
- `WLB_MONEY`: Tag for Money Controllers
- `WLB_EVT_CONTROLLER`: Tag for Event Controller
- `WLB_ADULT_START`: Tag for Adult Start Manager

### GUIDs
- `TOKENYEAR_GUID`: `"465776"` (Year Token GUID)

## 🎮 UI Elements

### Main Menu (when closed)
- **NEW GAME**: Opens menu to choose Youth/Adult

### Main Menu (when open)
- **CAPTURE LAYOUT**: Captures layout of all `WLB_LAYOUT` objects
- **RESTORE LAYOUT**: Restores captured layout
- **SAT: COLLECT**: Collects satisfaction tokens
- **YOUTH**: Starts new game in Youth mode
- **ADULT**: Starts new game in Adult mode
- **BACK**: Closes menu

## ⚠️ Notes

### Deprecation
- **Status**: No longer actively used
- **Reason**: Functionality moved to other controllers (e.g., Turn Controller)
- **Future**: Object will be deleted soon
- **Lost Element Finding**: No longer needed as all elements stay on table

### Known Issues
- **Bug in `newGameAdult()`**: Line calls `resetByTag(TAG_AP, "STATS")` instead of `resetByTag(TAG_STATS, "STATS")` (likely copy-paste error)

### Migration Notes
- New game setup functions likely moved to Turn Controller
- Layout capture/restore may be handled elsewhere or no longer needed
- Satisfaction token collection may be handled by other systems

### Historical Context
- This was likely an early central control system
- Provided unified interface for game setup
- Included utilities for finding "lost" elements (tokens that fell off table, etc.)
- As game matured, functionality was distributed to specialized controllers
