# Object #42: Youth Board

## 📋 Overview
The `Youth Board` script (`89eb00_YouthBoard.lua`) provides **action buttons for Youth phase activities** (education and work). It offers 5 actions that allow players to spend AP to gain skills, knowledge, or money during the Youth phase of the game. All actions are tied to the active player determined by `Turns.turn_color`. Version 1.3.

## 🚀 Core Functionality

### Action Buttons
The board provides 5 action buttons for Youth phase activities:

1. **VOC-SCH (Vocational School)**: 2 AP → +1 Skill
2. **TECH-ACAD (Technical Academy)**: Pay 300/year (once per year), then 3 AP → +2 Skill
3. **JOB**: 1 AP → +50 Money
4. **HI-SCH (High School)**: 2 AP → +1 Knowledge
5. **UNI (University)**: Pay 300/year (once per year), then 3 AP → +2 Knowledge

### Active Player System
- **Always uses active player**: All actions are tied to the current active player from `Turns.turn_color`
- **No manual player selection**: Does not use `playerColor` parameter from button clicks
- **Color normalization**: Normalizes turn color to ensure only valid colors (Yellow, Blue, Red, Green)
- **Blocking**: Actions are blocked if `Turns.turn_color` is invalid or not set

### Yearly Payment System
- **Tech Academy**: Requires 300 money payment once per year before use (tracked via `paidTechThisYear[color]`)
- **University**: Requires 300 money payment once per year before use (tracked via `paidUniThisYear[color]`)
- **Reset**: Year flags reset at start of new Youth game via `resetYearFlags()` or `resetNewGameYouth()`

### AP System Integration
- **Always to EVENT**: All AP spending goes to `EVENT` area (via `spendAP({to="EVENT", amount=N})`)
- **Pre-check**: Uses `canSpendAP()` to check availability before spending
- **Failure handling**: Logs warnings if AP spending fails

## 🔗 External API

### Public Functions
- `resetYearFlags()`: Resets `paidTechThisYear` and `paidUniThisYear` flags for all colors (unlocks Tech Academy and University for new year)
- `resetNewGameYouth()`: Same as `resetYearFlags()` (called during new game setup)

### Action Functions (Button Handlers)
- `actionVocSchool(cardObj, playerColor)`: Vocational School action (2 AP → +1 Skill)
- `actionHighSchool(cardObj, playerColor)`: High School action (2 AP → +1 Knowledge)
- `actionJob(cardObj, playerColor)`: Job action (1 AP → +50 Money)
- `actionTechAcademy(cardObj, playerColor)`: Technical Academy action (300/year + 3 AP → +2 Skill)
- `actionUniversity(cardObj, playerColor)`: University action (300/year + 3 AP → +2 Knowledge)

**Note**: The `playerColor` parameter is ignored; actions always use `Turns.turn_color` as the actor.

## ⚙️ Configuration

### Tags
- `WLB_AP_CTRL`: Tag for AP Controllers
- `WLB_STATS_CTRL`: Tag for Stats Controllers
- `WLB_MONEY`: Tag for Money Controllers
- `WLB_COLOR_*`: Color tags (`WLB_COLOR_Yellow`, `WLB_COLOR_Blue`, etc.)

### Valid Colors
- `VALID_COLORS`: `{Yellow=true, Blue=true, Red=true, Green=true}` (only these colors are accepted)

### Year Flags
- `paidTechThisYear[color]`: Tracks if player has paid Tech Academy fee this year (per color)
- `paidUniThisYear[color]`: Tracks if player has paid University fee this year (per color)

## 🎮 UI Elements

### Button Layout
Five buttons arranged horizontally:
- **VOC-SCH** (x=-2.2): Vocational School
- **TECH-ACAD** (x=-1.1): Technical Academy
- **JOB** (x=0.0): Job
- **HI-SCH** (x=1.1): High School
- **UNI** (x=2.2): University

All buttons are positioned at `y=0.2, z=-1.3` with `width=520, height=180, font_size=90`.

## ⚠️ Notes

### Active Player Dependency
- **Requires Turns system**: Relies on `Turns.turn_color` being set correctly
- **No fallback**: Actions are completely blocked if `Turns.turn_color` is invalid
- **Broadcast warning**: Broadcasts warning message to all players if active player cannot be determined

### Yearly Payment Mechanics
- **Once per year**: Tech Academy and University require 300 money payment once per year per player
- **Reset timing**: Year flags should be reset at start of each new Youth game or year
- **Per-player tracking**: Each color has its own payment flag (independent tracking)

### Money Safety
- **Cannot go below 0**: Money spending is blocked if it would result in negative balance
- **Robust API**: Tries multiple API methods to read money (`getMoney()`, `getValue()`, `getAmount()`, `getState()`)
- **Pre-check**: Uses `canAfford()` before attempting negative money operations

### Integration Notes
- **AP Controller**: Requires `canSpendAP({to="EVENT", amount=N})` and `spendAP({to="EVENT", amount=N})` methods
- **Stats Controller**: Requires `applyDelta({s=N})` for skills and `applyDelta({k=N})` for knowledge
- **Money Controller**: Requires `addMoney({amount=N})` or `addMoney({delta=N})` and readable getter methods
- **Turns System**: Requires `Turns.turn_color` to be set to valid color (Yellow, Blue, Red, or Green)

### Version 1.3 Changes
- **Full rewrite**: Complete replacement of previous version
- **Active turn color only**: All actions now use `Turns.turn_color` instead of button click `playerColor`
- **No "strange colors"**: Only accepts Yellow, Blue, Red, Green (normalized)
- **AP always to EVENT**: All AP spending goes to EVENT area
- **Per-player yearly flags**: Tech Academy and University payment tracking per color
