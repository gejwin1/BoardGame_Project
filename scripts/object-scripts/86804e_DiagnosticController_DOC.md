# Diagnostic Controller - Documentation

**GUID:** `86804e`  
**Tags:** `WLB_DIAGNOSTIC_CTRL`  
**Type:** Tile  
**Version:** 0.6.1

---

## Overview

The Diagnostic Controller is a comprehensive diagnostic and inventory tool for the board game. It scans the entire game table, validates game setup, tracks all objects, and provides detailed reports for debugging and documentation purposes.

This tool was developed and enhanced during the documentation process to help identify and catalog all scripted objects in the game.

---

## Functionality

### Main Purpose
- **Game Health Checks**: Validates that all required game components are present
- **Player Registry**: Tracks all player-specific objects (boards, tokens, AP controllers)
- **Full Inventory**: Lists ALL objects with GUIDs, tags, and script status
- **Scripted Objects List**: Generates filtered list of only scripted objects for documentation
- **Tag Inventory**: Shows all tags used in the game and which objects have them

### Key Features
- Safe method calls to avoid crashes with Custom Tiles
- Chunked console output to avoid truncation issues
- Notes integration for summary reports
- External API for other controllers to use
- Automatic self-tagging

---

## UI Buttons

The Diagnostic Controller has 4 buttons (arranged vertically):

### 1. RUN CHECK (Top Button)
- **Function**: Runs full diagnostic check
- **Output**: 
  - Summary saved to Notes tab
  - Full details printed to Console
- **Checks**:
  - Player boards (all 4 colors)
  - Player tokens (all 4 colors)
  - All controllers/engines
  - Core tokens (SAT, HEALTH, KNOWLEDGE, SKILLS)
  - Deck sanity (Youth and Adult decks)
  - Status tag validation
  - Near-board scan (scripted objects near each player board)
  - Full tag inventory
  - Script inventory

### 2. PLAYER REG (Second Button)
- **Function**: Dumps player registry to Notes
- **Output**: Complete registry of all player-specific objects
- **Shows**:
  - All system controllers and their GUIDs
  - Per-player breakdown:
    - Board
    - Player Token
    - AP Controller
    - Core tokens (SAT, HEALTH, KNOWLEDGE, SKILLS)
    - AP token count (expected: 12 per player)
    - AP probe count (expected: 1 per player)

### 3. FULL INVENTORY (Third Button)
- **Function**: Lists ALL objects on the table
- **Output**: 
  - Summary to Notes (first 50 objects)
  - Complete list to Console (all objects)
- **Format**: `[GUID] Name | Type | Scripted: YES/NO | Tags: {...}`
- **Purpose**: Complete catalog for copy-paste documentation

### 4. SCRIPTED ONLY (Bottom Button)
- **Function**: Lists ONLY scripted objects (filtered list)
- **Output**: Complete list to Console
- **Format**: Numbered list with Name, GUID, Type, Tags
- **Purpose**: Easy identification of all scripted objects for documentation

---

## Diagnostic Checks

### Player Boards
- Checks that all 4 player boards exist (Yellow, Blue, Red, Green)
- Flags duplicates or missing boards

### Player Tokens
- Validates one token per color
- Checks for missing or duplicate tokens

### Controllers/Engines
Validates presence of:
- Token System (WLB_TOKEN_SYSTEM)
- Market Controller (WLB_MARKET_CTRL)
- Event Engine (WLB_EVENT_ENGINE)
- Events Controller (WLB_EVT_CONTROLLER)
- Shop Engine (WLB_SHOP_ENGINE)
- Costs Calculator (WLB_COSTS_CALC)
- Turn Controller (WLB_TURN_CTRL)
- Diagnostic Controller (WLB_DIAGNOSTIC_CTRL)

### Core Tokens
- SAT tokens (1 per player)
- HEALTH tokens (1 per player)
- KNOWLEDGE tokens (1 per player)
- SKILLS tokens (1 per player)
- YEAR token (1 total)

### Deck Sanity
- Youth Deck: Expected 39 cards
- Adult Deck: Expected 81 cards
- Reports total, decks count, and cards count

### Status Tags
- Checks for deprecated tags (WLB_STATUS_SEEK)
- Validates required tags (WLB_STATUS_SICK)

### Near-Board Scan
- Scans area around each player board (radius: 6.0)
- Lists scripted/tagged objects near each board
- Shows distance and script status
- Limited to 10 closest objects per board

---

## External API Functions

Other scripts can call these functions:

### `D_FindOneByTag(tag)`
- **Parameters**: Tag string
- **Returns**: Object and count
- **Usage**: Find object(s) by tag

### `D_FindBoards()`
- **Returns**: Table mapping color to board object
- **Usage**: Get all player boards by color

### `D_ScanNearBoard(color, radius, limit)`
- **Parameters**: Player color, scan radius, result limit
- **Returns**: Array of objects near specified player board
- **Usage**: Find objects near a specific player's board

### `D_BuildRegistry()`
- **Returns**: Complete player registry structure
- **Usage**: Get full registry of all game objects

### `D_GetRegistry()`
- **Returns**: Cached registry (or builds if not cached)
- **Usage**: Quick access to player registry

### `D_RunAllToNotes()`
- **Returns**: Diagnostic status and problem count
- **Usage**: Run full diagnostic and save to Notes

---

## Technical Details

### Safe Method Calls
The script uses `safeCallMethod()` to safely call methods on objects without crashing. This is critical because some Custom Tile objects throw errors when accessing script state directly.

### Chunked Printing
Large outputs are printed in chunks (50 lines at a time with 0.2s delays) to avoid console truncation issues in Tabletop Simulator.

### Tag System
Tracks all tags across all objects:
- Counts how many objects have each tag
- Shows sample objects for each tag (up to 5 samples)
- Sorts tags alphabetically

### Script Detection
Detects scripted objects by checking:
- `getLuaScript()` - returns non-empty string
- `getLuaScriptState()` - returns non-empty string

---

## Expected Values

- **AP Tokens per Player**: 12
- **AP Probes per Player**: 1
- **Youth Deck Cards**: 39
- **Adult Deck Cards**: 81
- **Player Colors**: Yellow, Blue, Red, Green

---

## Output Formats

### Notes Output (Summary)
- Limited to prevent Notes from becoming too large
- Shows summary and first N items
- Directs to Console for full details

### Console Output (Full Details)
- Complete lists of all objects
- Easy to copy-paste for documentation
- Chunked to avoid truncation
- Clear start/end markers for selection

---

## Status Indicators

Diagnostic results use status indicators:
- **✔** = Pass (found, correct count)
- **⚠** = Warning (duplicate, unexpected count)
- **✖** = Fail (missing, wrong count)

---

## Development History

- **v0.6.1**: Enhanced with full inventory features, scripted objects filter, safe method calls
- **v0.5.0**: Basic diagnostic snapshot and player registry

---

## Notes

- Automatically tags itself with `WLB_DIAGNOSTIC_CTRL` on load
- Caches player registry for faster subsequent access
- All outputs include timestamps
- Console output is optimized for easy copy-paste operations

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Active Development Tool** - Used during game documentation process
