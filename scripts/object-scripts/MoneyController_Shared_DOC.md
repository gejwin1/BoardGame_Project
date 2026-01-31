# Money Controller - Documentation

**Shared Script**: Used by all 4 Money tokens (Blue, Green, Red, Yellow)  
**Version:** 1.5  
**Tags:** `WLB_RESETTABLE, WLB_MONEY, WLB_COLOR_[Color], WLB_LAYOUT`

---

## Overview

The Money Controller tracks and displays each player's money. All four money tokens (one per player color) use the exact same script. The script provides a simple display showing "MONEY = X" and offers a comprehensive API for other scripts to manage player finances.

---

## Functionality

### Main Purpose
- **Money Tracking**: Tracks player's money amount (starts at 200)
- **Visual Display**: Shows "MONEY = X" on a button (display only, not clickable)
- **Persistence**: Saves money amount across game sessions
- **API Integration**: Provides functions for other scripts to add, set, get, and spend money

### Key Features
- Simple, clean display
- Safe spending (blocks if insufficient funds)
- Multiple API aliases for compatibility
- Reset function for new games
- Integer clamping (no decimals)

---

## Game Integration

### Related Objects
- **Costs Calculator** - Uses `addMoney({delta = -amount})` to deduct costs
- **Shop Engine** - Uses `API_spend()` to purchase items
- **Estate Engine** - (Future: Will use for estate purchases)

### Per-Player Instances
Each player has their own Money token:
- **MONEY B** (Blue) - GUID: `b39f0e`
- **MONEY G** (Green) - GUID: `a373e9`
- **MONEY R** (Red) - GUID: `e2d3e1`
- **MONEY Y** (Yellow) - GUID: `99d96c`

All use identical script, only differ by:
- Object GUID
- Color tag (`WLB_COLOR_Blue`, `WLB_COLOR_Green`, etc.)

---

## UI Elements

### Display Button
- **Label**: "MONEY = [amount]"
- **Type**: Display only (noop click function)
- **Position**: Center of tile
- **Color**: Light gray background, dark text
- **Updates**: Automatically updates when money changes

---

## External API Functions

Other scripts can call these functions to interact with Money tokens:

### `getMoney()`
- **Parameters**: None
- **Returns**: Current money amount (number)
- **Usage**: Check player's current money
- **Example**: `local amount = moneyTile.call("getMoney")`

### `setMoney(params)`
- **Parameters**: 
  - Table with `amount` or `delta` field, OR
  - Direct number
- **Returns**: New money amount after setting
- **Usage**: Set money to specific amount
- **Example**: `setMoney({amount = 500})` or `setMoney(500)`

### `addMoney(params)`
- **Parameters**: 
  - Table with `amount` or `delta` field, OR
  - Direct number (positive to add, negative to subtract)
- **Returns**: New money amount after adding
- **Usage**: Add or subtract money (most common operation)
- **Example**: 
  - `addMoney({delta = 100})` - Add 100
  - `addMoney({delta = -50})` - Subtract 50
  - `addMoney(100)` - Add 100

### `resetNewGame()`
- **Parameters**: None
- **Returns**: Money amount (200)
- **Usage**: Reset money to starting amount (200) for new game
- **Example**: `resetNewGame()`

### `rebuildUI()`
- **Parameters**: None
- **Returns**: Nothing
- **Usage**: Force refresh of display button
- **Example**: Call after manual state changes

### `API_spend(params)` / `spendMoney(params)` / `spend(params)`
- **Parameters**: 
  - Table with `amount` or `delta` field, OR
  - Direct number
- **Returns**: Table with:
  - `ok` (boolean) - Whether spending succeeded
  - `spent` (number) - Amount actually spent
  - `requested` (number) - Amount requested
  - `reason` (string, if failed) - "insufficient_funds"
  - `money` (number) - Current money after operation
- **Usage**: Safe spending - only deducts if player has enough
- **Example**: 
  ```lua
  local result = moneyTile.call("API_spend", {amount = 50})
  if result.ok then
    print("Spent "..result.spent)
  else
    print("Not enough money! Reason: "..result.reason)
  end
  ```

**Note**: All three function names (`API_spend`, `spendMoney`, `spend`) do the same thing - provided for compatibility with different engines.

---

## Technical Details

### Starting Money
- **Default**: 200
- Set via `START_MONEY` constant
- Applied on first load or when `resetNewGame()` is called

### Integer Handling
- All amounts are clamped to integers
- Uses `clampInt()` function:
  - Positive numbers: `math.floor(x + 0.00001)`
  - Negative numbers: `math.ceil(x - 0.00001)`
- No decimal money values

### Persistence
- Saves money amount on game save
- Restores on game load
- Save version: 3 (for future migrations)

### Safe Spending
The `API_spend()` function:
- Checks if player has enough money
- Only deducts if sufficient funds
- Returns detailed result table
- Never goes negative (blocks insufficient spending)

---

## Usage Examples

### Adding Money (Reward)
```lua
local moneyTile = getObjectFromGUID("b39f0e") -- Blue player
moneyTile.call("addMoney", {delta = 100})
```

### Subtracting Money (Cost)
```lua
moneyTile.call("addMoney", {delta = -50})
```

### Safe Purchase (Shop)
```lua
local result = moneyTile.call("API_spend", {amount = 75})
if result.ok then
  -- Purchase successful
  print("Purchased! Remaining: "..result.money)
else
  -- Not enough money
  print("Can't afford! Need "..result.requested..", have "..result.money)
end
```

### Check Balance
```lua
local balance = moneyTile.call("getMoney")
print("Player has "..balance.." money")
```

### Reset for New Game
```lua
moneyTile.call("resetNewGame")
```

---

## Integration with Other Systems

### Costs Calculator
- Calls `addMoney({delta = -due})` to deduct monthly costs
- Uses negative delta to subtract

### Shop Engine
- Calls `API_spend({amount = price})` for purchases
- Checks `result.ok` to verify purchase succeeded

### Estate Engine
- (Future) Will use for estate purchases
- Currently has placeholder price system

---

## Notes

- Display button is non-interactive (noop function)
- Money can go negative if using `addMoney()` or `setMoney()` directly
- Only `API_spend()` prevents negative balances
- All four money tokens are identical - only differ by GUID and color tag
- Script is resettable (tag: `WLB_RESETTABLE`) for game reset functionality

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Shared Script** - Used by all 4 Money tokens (Blue, Green, Red, Yellow)
