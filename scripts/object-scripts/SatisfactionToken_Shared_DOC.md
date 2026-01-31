# Objects #34-37: Satisfaction Tokens (Shared Script)

## 📋 Overview
The `Satisfaction Token` script (`SatisfactionToken_Shared.lua`) is used by all four player-specific satisfaction tokens (Yellow, Blue, Red, Green). Its primary function is to track and visually represent each player's satisfaction score (0-100) by moving a physical token along the Satisfaction Board. The token automatically calculates its position based on value using anchor points, supports staggered movement to prevent collisions between multiple tokens, and provides an external API for other game systems to modify satisfaction values. Version 2.4.

## 🚀 Functionality

### Satisfaction Value Management
- **Value Range**: 0 to 100 (clamped)
- **Starting Value**: 10 (at game start)
- **Persistence**: Saves and loads current satisfaction value using JSON encoding

### Visual Movement on Satisfaction Board
- **Board Integration**: Moves token along Satisfaction Board (GUID: `c2d811`)
- **Anchor-Based Positioning**: Uses 5 anchor points (p0, p9, p10, p11, p100) to calculate position:
  - **Values 0-9**: Linear interpolation between p0 and p9
  - **Value 10**: Uses p10 (special starting position)
  - **Values 11-100**: Grid layout between p11 and p100 (10 columns, 9 rows)
- **Color-Specific Slot**: Determines slot index (0-3) from color tag for staggered movement

### Anti-Collision System
- **Staggered Movement**: Tokens move with delays based on color slot to prevent simultaneous collisions
  - Yellow: slot 0 (no delay)
  - Red: slot 1 (0.35s delay)
  - Blue: slot 2 (0.70s delay)
  - Green: slot 3 (1.05s delay)
- **Lock During Movement**: Token is locked during movement to prevent physics interference
- **Movement Queue**: Multiple rapid changes are queued (only last change executed)

### Anchor Resolution
- **Priority 1**: Attempts to fetch anchors from Satisfaction Board via `board.call("getSatAnchors")`
- **Priority 2**: Attempts to read anchors from Satisfaction Board's `SAT_ANCHORS` variable
- **Fallback**: If anchors unavailable, token can change value but won't move (warning displayed)

## 🔗 External API

### Value Modification
- `addSat(params)`: Adds a delta to satisfaction value
  - Accepts: `{delta=N}` or `{amount=N}` table, or direct number
  - Example: `addSat({delta=5})` or `addSat(5)`
  
- `setSatValue(params)`: Sets satisfaction to a specific value
  - Accepts: `{value=N}` table or direct number
  - Example: `setSatValue({value=50})` or `setSatValue(50)`

### Value Query
- `getSatValue()`: Returns current satisfaction value (0-100)

### Reset Functionality
- `resetToStart(params)`: Resets satisfaction to START_VAL (10) and places token at starting position
  - Accepts: `{slot=0..3}` or `{i=0..3}` table
  - Uses slot parameter for positioning multiple tokens during reset

## ⚙️ Configuration

### Board and Anchors
- `BOARD_GUID`: `"c2d811"` (GUID of Satisfaction Board)
- `Y_OFFSET`: `0.25` (Vertical offset to prevent token sinking into board)

### Value Bounds
- `MIN_VAL`: `0` (Minimum satisfaction)
- `MAX_VAL`: `100` (Maximum satisfaction)
- `START_VAL`: `10` (Starting satisfaction value)

### Movement Timing
- `MOVE_GAP`: `0.35` seconds (Delay between token movements for anti-collision)
- `LOCK_TIME`: `0.70` seconds (Duration token stays locked during movement)

### Anchor Points (Local coordinates on Satisfaction Board)
- `p0`: Position for value 0
- `p9`: Position for value 9
- `p10`: Position for value 10 (starting position)
- `p11`: Position for value 11 (start of grid)
- `p100`: Position for value 100 (end of grid)

## 🎮 UI Elements

The token provides four buttons for manual satisfaction adjustment:
- **-5**: Decrease satisfaction by 5
- **-1**: Decrease satisfaction by 1
- **+1**: Increase satisfaction by 1
- **+5**: Increase satisfaction by 5

Buttons are arranged in a compact 2x2 grid on the token.

## 🔧 Technical Details

### Position Calculation Algorithm

**For values 0-9**:
- Linear interpolation between p0 and p9
- `dx = (p9.x - p0.x) / 9`
- `position = p0 + (dx * value)`

**For value 10**:
- Uses p10 anchor directly

**For values 11-100**:
- Grid layout: 10 columns, 9 rows
- `idx = value - 11` (0-89)
- `col = idx % 10` (0-9)
- `row = floor(idx / 10)` (0-8)
- `dx = (p9.x - p0.x) / 9` (column spacing)
- `dz = (p100.z - p11.z) / 8` (row spacing)
- `position = p11 + (dx * col, dz * row)`

### Slot Determination
Slot index based on color tags (for staggered movement):
- `WLB_COLOR_Yellow` → slot 0
- `WLB_COLOR_Red` → slot 1
- `WLB_COLOR_Blue` → slot 2
- `WLB_COLOR_Green` → slot 3

### Movement Queue System
- `pendingValue`: Stores queued value change
- `moveScheduled`: Flag prevents multiple simultaneous schedules
- If multiple rapid changes occur, only the last change is executed

## 🔗 Integration with Other Systems

### Satisfaction Board
- **Relationship**: Token fetches anchor positions from Satisfaction Board
- **Methods**: Attempts `board.call("getSatAnchors")` or reads `board.getVar("SAT_ANCHORS")`
- **Purpose**: Board provides calibrated anchor positions for token movement

### Other Game Systems
- **Event Engine**: May call `addSat()` when events affect satisfaction
- **Shop Engine**: May call `addSat()` for satisfaction-granting consumables
- **Turn Controller**: May reset satisfaction at game start using `resetToStart()`

## ⚠️ Notes

### Important Behaviors
- **Color-Agnostic**: Script automatically identifies player color from tags (`WLB_COLOR_*`)
- **Staggered Movement**: Prevents all 4 tokens from moving simultaneously and colliding
- **Queue System**: Rapid value changes are optimized (only last change executed)
- **Anchor Dependency**: Token requires anchors from Satisfaction Board to move; value changes work without anchors

### Reset Positioning
- During `resetToStart()`, tokens are positioned with horizontal spread (SPREAD = 1.60) based on slot
- Prevents multiple tokens from stacking at same position during simultaneous reset
- Rotation set to `{0, 180, 0}` for consistent orientation

### Persistence
- Saves: `value`, and all anchor positions (p0, p9, p10, p11, p100)
- On load: Restores value and anchors, then moves token to current position instantly

### Limitations
- Maximum value: 100 (hardcoded)
- Minimum value: 0 (hardcoded)
- Requires Satisfaction Board to have anchor data for movement to work
