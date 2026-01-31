# Year Token (Round Tracker) - Documentation

**GUID:** `465776`  
**Tags:** `WLB_LAYOUT, WLB_YEAR`  
**Type:** Tile  
**Version:** 3.0

---

## Overview

The Year Token is a visual round tracker that moves across the Calendar Board to indicate the current game round. It tracks rounds 1-13, with special handling for Youth Age (rounds 1-5) and Adult Age (rounds 6-13).

---

## Functionality

### Main Purpose
- **Round Tracking**: Visually tracks the current game round (1-13)
- **Position Management**: Moves to predefined positions on the Calendar Board for each round
- **Color Tinting**: Can change color to indicate player turn or game phase
- **State Persistence**: Saves current round and color between game sessions

### Key Features
- No UI buttons (clean interface)
- Automatic movement between round positions
- External API for other scripts to control the round
- Color tinting support (Yellow, Blue, Red, Green, White)
- Anti-sink protection (lifts token slightly on load)

---

## Game Integration

### Related Objects
- **Calendar Board** (GUID: `4aa064`) - The board this token moves across

### Round Structure
- **Rounds 1-5**: Youth Age (learning phase)
- **Rounds 6-13**: Adult Age (main game phase)
- **Maximum**: 13 rounds total

---

## External API Functions

Other scripts can call these functions to interact with the Year Token:

### `getRound()`
- **Returns**: Current round number (1-13)
- **Usage**: Check what round the game is on

### `setRound(params)`
- **Parameters**: Can be a number, or table with `round`/`r`/`[1]` field
- **Usage**: Set the round to a specific number
- **Example**: `setRound({round = 5})` or `setRound(5)`

### `nextRound()`
- **Usage**: Advance to the next round
- **Behavior**: Automatically moves token to next position

### `prevRound()`
- **Usage**: Go back one round
- **Behavior**: Moves token to previous position

### `resetToYouth()`
- **Usage**: Reset to round 1 (start of Youth Age)
- **Behavior**: Moves token to position 1

### `resetToAdult()`
- **Usage**: Reset to round 6 (start of Adult Age)
- **Behavior**: Moves token to position 6

### `setColor(params)`
- **Parameters**: Can be a string or table with `color`/`c`/`[1]` field
- **Valid colors**: "Yellow", "Blue", "Red", "Green", "White"
- **Usage**: Change token color/tint
- **Example**: `setColor({color = "Blue"})` or `setColor("Blue")`

### `getColor()`
- **Returns**: Current color string (e.g., "Yellow")
- **Usage**: Check what color the token currently is

---

## Technical Details

### State Variables
- `currentRound`: Current round number (1-13)
- `currentColor`: Current color tint (string)
- `localPositions`: Array of positions for each round [1..13]

### Persistence
- Saves round, color, and positions on game save
- Restores state on game load

### Movement System
- Uses local positions relative to Calendar Board
- Converts local positions to world coordinates
- Supports smooth movement (animated) or instant movement

### Error Handling
- Shows warning if Calendar Board not found
- Shows warning if position for round is missing
- Clamps round values to valid range (1-13)

---

## Notes

- Token has no visible name/description (cleared on load)
- Has backward-compatibility function `setLabel()` that does nothing
- Y_OFFSET prevents token from sinking into board

---

## Status

✅ **Documented** - Script analyzed and documented
