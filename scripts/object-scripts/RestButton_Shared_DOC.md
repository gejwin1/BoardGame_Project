# REST Button - Documentation

**Shared Script**: Used by all 4 REST Buttons (Blue, Green, Red, Yellow)  
**Version:** 1.1.0  
**Tags:** `WLB_COLOR_[Color]`

---

## Overview

The REST Button is a simple controller that allows players to quickly move Action Points to/from the REST area. It integrates with the AP Controller and Stats Controller to show a forecast of health changes based on resting.

---

## Functionality

### Main Purpose
- **Quick REST Control**: Simple +/- buttons to move AP to/from REST area
- **Health Forecast**: Shows predicted health change after clicking
- **Integration**: Works with AP Controller and Stats Controller

### Key Features
- Two large buttons: REST + and REST -
- Automatic forecast display after each action
- Color-agnostic (reads color from self-tag)
- Integrates with AP Controller to move tokens
- Calculates health change based on REST count

---

## Game Integration

### Related Objects
- **AP Controller** - Moves AP tokens to/from REST area (tag: `WLB_AP_CTRL` + color tag)
- **Stats Controller** - Reads current health value (tag: `WLB_STATS_CTRL` + color tag)

### Per-Player Instances
Each player has their own REST Button:
- **REST Button B** (Blue) - GUID: `79d9c9`
- **REST Button G** (Green) - GUID: `48686a`
- **REST Button R** (Red) - GUID: `3a4e5f`
- **REST Button Y** (Yellow) - GUID: `7f8a9b`

All use identical script, only differ by:
- Object GUID
- Color tag (`WLB_COLOR_Blue`, `WLB_COLOR_Green`, etc.)

---

## UI Elements

### REST + Button (Left, Green)
- **Label**: "+"
- **Position**: Left side of tile (x: -2.20)
- **Color**: Green background
- **Tooltip**: "REST +1"
- **Function**: Moves 1 AP token to REST area

### REST - Button (Right, Red)
- **Label**: "−" (minus symbol)
- **Position**: Right side of tile (x: 2.20)
- **Color**: Red background
- **Tooltip**: "REST -1"
- **Function**: Removes 1 AP token from REST area

---

## How It Works

### REST + (Add AP to REST)
1. Player clicks REST + button
2. System finds player's AP Controller by color tag
3. Calls `moveAP({to="REST", amount=1})` on AP Controller
4. AP Controller moves 1 token from START to REST area
5. System shows forecast of health change

### REST - (Remove AP from REST)
1. Player clicks REST - button
2. System finds player's AP Controller by color tag
3. Calls `moveAP({to="REST", amount=-1})` on AP Controller
4. AP Controller moves 1 token from REST area back to START
5. System shows forecast of health change

### Forecast Display
After each action, shows broadcast message with:
- **AP on REST**: Current count of AP tokens in REST area
- **End-turn Health change**: Calculated as `REST count - 4`
  - If REST count > 4: Positive health change
  - If REST count < 4: Negative health change
  - If REST count = 4: No health change
- **Health now**: Current health value
- **Health after turn**: Predicted health after turn ends

**Formula**: `deltaH = REST_count - 4`

---

## Technical Details

### Integration with AP Controller
- Finds AP Controller using tags: `WLB_AP_CTRL` + player color tag
- Calls `moveAP()` function with `to="REST"` and `amount=1` or `-1`
- Handles return value: `{ok=true/false, moved=..., requested=..., reason=...}`

### Integration with Stats Controller
- Finds Stats Controller using tags: `WLB_STATS_CTRL` + player color tag
- Reads current health using multiple fallback methods:
  1. `getState()` → `{h=...}`
  2. `getHealth()`
  3. `getHealthValue()`

### REST Count Reading
Tries multiple methods to read REST count from AP Controller:
1. `getCount({area="REST"})`
2. `getCount({area="R"})`
3. `countArea({area="REST"})`
4. `getRestCount()`

Uses first method that returns a valid number.

### Health Calculation
- **Current Health**: Read from Stats Controller (0-9)
- **Delta Calculation**: `REST_count - 4`
  - REST count of 4 = no health change
  - REST count > 4 = health increases
  - REST count < 4 = health decreases
- **Predicted Health**: Clamped to 0-9 range

---

## Error Handling

- Shows error if AP Controller not found
- Shows error if Stats Controller not found
- Handles cases where `moveAP()` fails (no free tokens/slots)
- Shows forecast even if action is blocked (so player knows current state)

---

## Usage Examples

### Player Clicks REST +
1. Button clicked
2. 1 AP moved to REST area
3. Forecast shown:
   ```
   AP on REST = 3
   End-turn Health change = -1
   Health now = 7
   Health after turn = 6
   ```

### Player Clicks REST - (when REST count is 5)
1. Button clicked
2. 1 AP removed from REST area
3. Forecast shown:
   ```
   AP on REST = 4
   End-turn Health change = 0
   Health now = 7
   Health after turn = 7
   ```

---

## Integration with Other Systems

### Turn Controller
- Uses same health calculation logic: `deltaH = REST_count - 4`
- REST Button provides quick access for players to adjust REST AP

### AP Controller
- REST Button calls `moveAP()` to move tokens
- AP Controller handles actual token movement

### Stats Controller
- REST Button reads current health for forecast
- Stats Controller manages health value

---

## Notes

- Script is color-agnostic - determines player from self color tag
- Forecast is shown after every action (even if blocked)
- Health change formula: REST count - 4 (4 is the neutral point)
- Large buttons for easy clicking
- No external API - only UI buttons

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Shared Script** - Used by all 4 REST Buttons (Blue, Green, Red, Yellow)  
✅ **Simple Controller** - Minimal functionality, focused on REST AP management
