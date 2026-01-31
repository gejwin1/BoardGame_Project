# Costs Calculator - Documentation

**GUID:** `bccb71`  
**Tags:** `WLB_COSTS_CALC`  
**Type:** Tile  
**Version:** 1.1  
**Status:** ⚠️ Partially implemented (planned for future functionality)

---

## Overview

The Costs Calculator tracks monthly/recurring costs per player. It helps players plan their budget by showing remaining fixed costs that appear every month (or round). The UI automatically updates based on which player's turn is active.

**Note:** This script is not entirely working yet - it's planned for future functionality related to monthly costs that players will need to pay.

---

## Functionality

### Main Purpose
- **Cost Tracking**: Tracks remaining costs per player (Yellow, Blue, Red, Green)
- **Budget Planning**: Shows players how much they need to pay for recurring monthly costs
- **Active Player Display**: UI automatically shows costs for the currently active player
- **Payment System**: Allows players to pay accumulated costs, deducting from their money tile

### Key Features
- Per-player cost buckets (separate tracking for each color)
- Dynamic UI that changes based on active player color
- PAY button to deduct costs from player's money
- Automatic UI refresh when active player changes
- Integration with Money tiles and Round token
- External API for other scripts to manage costs

---

## Game Integration

### Related Objects
- **Round Token** (GUID: `465776`) - Source of active player color
- **Money Tiles** - Objects with tags `WLB_MONEY` + `WLB_COLOR_[Color]` (e.g., `WLB_COLOR_Yellow`)

### How It Works
1. Other scripts/events can add costs to a player using the API
2. The UI label shows "REMAINING COSTS: X" for the active player
3. Label background color matches the active player's color
4. Player can click PAY button to deduct costs from their money
5. Costs are automatically paid when turn ends (if configured)

---

## UI Elements

### Label Button (Index 0)
- **Label**: "REMAINING COSTS: [amount]"
- **Position**: Front of tile (z: 0.35)
- **Color**: Changes based on active player color (light tint)
- **Tooltip**: "Shows remaining fixed costs for active player"
- **Function**: Display only (noop click function)

### PAY Button (Index 1)
- **Label**: "PAY"
- **Position**: Back of tile (z: -0.35)
- **Color**: Green background
- **Tooltip**: "Pay remaining costs for active player"
- **Function**: Deducts costs from player's money tile

---

## External API Functions

Other scripts can call these functions to interact with the Costs Calculator:

### `getCost(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc`, or no params (uses active player)
- **Returns**: Current cost amount for specified/active player
- **Usage**: Check how much a player owes
- **Example**: `getCost({color = "Yellow"})` or `getCost()` (uses active player)

### `setCost(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc` and `amount`/`value`, OR just amount (uses active player)
- **Returns**: New cost amount after setting
- **Usage**: Set cost to a specific amount
- **Example**: `setCost({color = "Blue", amount = 50})` or `setCost(100)` (uses active player)

### `clearCost(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc`, or no params (uses active player)
- **Returns**: Always 0
- **Usage**: Reset costs to zero for a player
- **Example**: `clearCost({color = "Red"})`

### `addCost(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc` and `amount`/`delta`, OR just amount (uses active player)
- **Returns**: New total cost after adding
- **Usage**: Add to existing costs (most common operation)
- **Example**: `addCost({color = "Green", amount = 25})` or `addCost(10)` (uses active player)

### `pay(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc`, or no params (uses active player)
- **Returns**: `true` if successful, `false` if failed
- **Usage**: Pay all costs for a player (deducts from money tile)
- **Example**: `pay({color = "Yellow"})`

### `rebuildUI()`
- **Parameters**: None
- **Returns**: Nothing
- **Usage**: Force refresh of UI buttons
- **Example**: Call after manual state changes

### `onTurnEnd(params)`
- **Parameters**: Table with `color`/`playerColor`/`pc`
- **Returns**: Table with `ok`, `paid`, `due`, `reason`
- **Usage**: Called by Turn Controller when player's turn ends - automatically pays costs if any
- **Example**: `onTurnEnd({color = "Blue"})`

---

## Active Player Detection

The calculator determines the active player using this priority:

1. **Round Token Color** (GUID: `465776`) - Primary source of truth
   - Calls `getColor()` on Round Token
   - This is the preferred method
   
2. **Turns.turn_color** - Fallback
   - Uses global Turns system if Round Token unavailable

If neither is available, returns `nil` and uses default display.

---

## Payment Process

When PAY is clicked or `pay()` is called:

1. Checks if player color is valid
2. Gets current cost amount from bucket
3. If cost ≤ 0, clears bucket and returns success
4. Finds player's Money tile (by tags: `WLB_MONEY` + `WLB_COLOR_[Color]`)
5. Calls `addMoney({delta = -due})` on Money tile to deduct cost
6. Sets cost bucket to 0
7. Updates UI

**Error Handling:**
- Returns error if Money tile not found
- Returns error if Money tile payment fails
- Shows broadcast messages on failure

---

## Technical Details

### State Variables
- `costs`: Table with per-player costs `{Yellow=0, Blue=0, Red=0, Green=0}`
- `lastActiveColor`: Cached active player color for change detection

### UI Refresh System
- Polls active player color every 0.5 seconds
- Updates label text and background color when active player changes
- Also updates if costs change without color change

### Color Tints
Label background uses light, readable versions:
- **Yellow**: `{1.00, 0.95, 0.45}`
- **Blue**: `{0.55, 0.75, 1.00}`
- **Red**: `{1.00, 0.60, 0.60}`
- **Green**: `{0.60, 1.00, 0.70}`
- **Default**: Light gray `{0.95, 0.95, 0.95}`

### Persistence
- Saves cost buckets on game save
- Restores costs on game load
- Version: 1 (SAVE_VERSION)

---

## Planned Future Functionality

Based on the user's note, this will be used for:
- **Monthly Recurring Costs**: Costs that appear every month/round
- **Budget Planning**: Help players plan their spending more carefully
- **Automated Cost Application**: Automatically apply monthly costs when rounds advance

---

## Notes

- Script checks for Money tiles by tags (`WLB_MONEY` + color tag)
- All cost amounts are clamped to integers
- UI automatically refreshes when active player changes
- Costs are tracked per-player, independent of each other
- Payment only works if Money tile exists and has `addMoney()` function

---

## Status

✅ **Documented** - Script analyzed and documented  
⚠️ **Note**: Partially implemented - planned for future monthly cost functionality
