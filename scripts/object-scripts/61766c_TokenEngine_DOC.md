# Object #29: TOKEN ENGINE (GUID: 61766c)

## 📋 Overview
The `TOKEN ENGINE` script (`61766c_TokenEngine.lua`) is a comprehensive token management system responsible for managing all status tokens, family tokens (marriage, children), and housing placement for players. It maintains a token pool system, places tokens on player boards and estate cards, manages status slots (6 per player), and provides automatic target color resolution. This engine is a core dependency for Player Status Controller, Event Engine, and other game systems. Version 2.4.0.

## 🚀 Core Functionality

### Token Pool System
- **PRIME**: Extracts all status tokens from a central bag (`BAG_GUID: c10019`), parks them in a grid near the engine, and organizes them into a POOL by tag
- **COLLECT**: Collects all status tokens from the table back into the bag and resets the pool
- **Pool Organization**: Tokens are organized by tag (status type) for efficient retrieval
- **Recycle System**: Removed status tokens are placed in a "recycle lane" (not returned to bag immediately) to keep the table tidy

### Status Token Management (6 Types)
- **Supported Status Tags**:
  - `WLB_STATUS_GOOD_KARMA`: Good Karma status
  - `WLB_STATUS_EXPERIENCE`: Experience status
  - `WLB_STATUS_DATING`: Dating status
  - `WLB_STATUS_SICK`: Sickness status
  - `WLB_STATUS_WOUNDED`: Wounded status
  - `WLB_STATUS_ADDICTION`: Addiction status
- **Per-Player Status Slots**: Each player board has 6 status slots (L0 level)
- **Compact Ordering**: Status tokens are placed in canonical order (Good Karma first, Addiction last)
- **Maximum Limits**: Up to 6 active statuses per player (enforced)

### Family Token Management
- **Marriage Token**: Single marriage token per player (`WLB_STATUS_MARRIAGE`)
- **Children Tokens**: Multiple children per player (`WLB_STATUS_CHILD_BOY`, `WLB_STATUS_CHILD_GIRL`)
- **Family Arrangement**: Family tokens are placed in a specific order:
  1. Player token (slot 1)
  2. Marriage token (slot 2, if present)
  3. Children tokens (slots 3-6, in order added)

### Housing System (L0-L4)
- **L0 (Board)**: Family tokens placed on player board (6 slots)
- **L1-L4 (Estate Cards)**: Family tokens placed on estate cards (6 slots per level)
- **Dynamic Housing**: Housing level can be changed, tokens automatically relocate
- **Estate Card Resolution**: Finds estate cards by name (`ESTATE_L1`, `ESTATE_L2`, etc.) and tag

### Safe Park System
- **Temporary Parking**: Family tokens can be moved to "safe park" positions on player board
- **Non-Destructive**: Safe park allows tokens to be temporarily removed from housing slots without returning to bag
- **RETURN**: Tokens can be returned from safe park back to their housing slots

### Auto-Target Color Resolution
- **Priority Order**:
  1. Explicit `color` argument (always wins - for victim/target scenarios)
  2. Clicking player color (if seated player clicked button)
  3. Active turn color (`Turns.turn_color`)
  4. Last known turn color or "Yellow" (fallback)
- **Benefit**: Eliminates need for manual color selectors; works with active turn or explicit targets

## 🔗 External API

### Core Token Operations

#### Status Token Functions
- `TE_AddStatus(color, statusTag)`: Add a status token to a player
- `TE_RemoveStatus(color, statusTag)`: Remove a status token from a player
- `TE_ClearStatuses(color)`: Remove all status tokens from a player
- `TE_RefreshStatuses(color)`: Refresh status token placement on player board

#### Family Token Functions
- `TE_AddMarriage(color)`: Add marriage token to player
- `TE_AddChild(color, sex)`: Add child token (`sex` = "BOY", "GIRL", or `nil` for random)
- `TE_RemoveOneChild(color)`: Remove last child token (returns to bag)

#### Housing Functions
- `TE_SetHousing(color, levelName, estateObjOrNil)`: Set housing level (L0-L4)
- `TE_PlacePlayerTokenToL0(color)`: Place player token at start position (L0, slot 1)

#### Safe Park Functions
- `TE_RemoveTokensToSafePark(color)`: Move family tokens to safe park positions
- `TE_ReturnTokensFromSafePark(color)`: Return family tokens from safe park to housing

#### Pool Management Functions
- `primeTokenPool()`: Extract tokens from bag and build pool
- `collectAllStatusTokensToBag()`: Collect all status tokens back to bag

### ARG Wrapper Functions (for `object.call` compatibility)
These functions accept arguments as a table and auto-resolve target color:
- `TE_AddStatus_ARGS(args)`: `args = {color=..., statusTag=...}`
- `TE_RemoveStatus_ARGS(args)`: `args = {color=..., statusTag=...}`
- `TE_ClearStatuses_ARGS(args)`: `args = {color=...}`
- `TE_RefreshStatuses_ARGS(args)`: `args = {color=...}`
- `TE_AddMarriage_ARGS(args)`: `args = {color=...}`
- `TE_AddChild_ARGS(args)`: `args = {color=..., sex=...}`

**Note**: `color` is optional in ARG wrappers - auto-resolved to active turn if omitted

### Public API Functions (for other controllers)
- `API_collect(args)`: Triggers collect all status tokens to bag
- `API_prime(args)`: Triggers prime token pool from bag
- `API_placePlayerTokens(args)`: Places player tokens to L0 for specified colors (`args.colors = {color1, color2, ...}`)

## 🔗 Integration with Other Systems

### Player Status Controller
- **Relationship**: Status Controller forwards all status commands to Token Engine
- **Method**: Uses `object.call()` to invoke `*_ARGS` wrapper functions
- **Dependency**: Token Engine must expose `*_ARGS` wrappers (provided)

### Event Engine
- **Relationship**: Event Engine calls Token Engine via Status Controller or directly
- **Usage**: Adds/removes status tokens based on event card effects

### Estate Engine
- **Relationship**: Estate Engine may call `TE_SetHousing()` when players acquire/change estates
- **Usage**: Updates housing level (L1-L4) when estate cards are placed on player boards

### Turn Controller
- **Relationship**: Reads `Turns.turn_color` for auto-target resolution
- **Usage**: Determines active player for operations when color not explicitly specified

## ⚙️ Configuration

### Bag and Tags
- `BAG_GUID`: `"c10019"` (Central token bag containing all status/family tokens)
- `TAG_BOARD`: `"WLB_BOARD"` (Player board tag)
- `TAG_PLAYER_TOKEN`: `"WLB_PLAYER_TOKEN"` (Player token tag)
- `TAG_STATUS_TOKEN`: `"WLB_STATUS_TOKEN"` (Status token tag)
- `TAG_ESTATE_CARD`: `"WLB_ESTATE_CARD"` (Estate card tag)

### Status Tags
- `TAG_STATUS_SICK`: `"WLB_STATUS_SICK"`
- `TAG_STATUS_WOUNDED`: `"WLB_STATUS_WOUNDED"`
- `TAG_STATUS_ADDICTION`: `"WLB_STATUS_ADDICTION"`
- `TAG_STATUS_DATING`: `"WLB_STATUS_DATING"`
- `TAG_STATUS_GOODKARMA`: `"WLB_STATUS_GOOD_KARMA"`
- `TAG_STATUS_EXPERIENCE`: `"WLB_STATUS_EXPERIENCE"`

### Family Tags
- `TAG_MARRIAGE`: `"WLB_STATUS_MARRIAGE"`
- `TAG_CHILD_BOY`: `"WLB_STATUS_CHILD_BOY"`
- `TAG_CHILD_GIRL`: `"WLB_STATUS_CHILD_GIRL"`

### Slot Tables
- **FAMILY_SLOTS_BOARD**: L0 slots on player boards (per color, Yellow as reference)
- **FAMILY_SLOTS_CARD**: L1-L4 slots on estate cards (6 slots per level)
- **STATUS_SLOTS_BOARD**: Status token slots on player boards (6 slots per player, L0)
- **SAFE_PARK_BOARD**: Safe park positions on player boards (6 slots per player)

### Timing Constants
- `STEP_DELAY`: 0.30 seconds (delay between sequential token placements)
- `HOUSING_RETURN_DELAY`: 0.30 seconds (delay for family token returns)
- `TAKE_DELAY`: 0.08 seconds (delay between bag token extractions during PRIME)
- `PARK_ROWSIZE`: 8 (tokens per row in prime/recycle parking)
- `PARK_SPACING_X/Z`: Grid spacing for parking tokens
- `PARK_LIFT_Y`: 0.35 units (vertical offset for parked tokens)

## 🎮 UI Elements

The controller tile provides extensive button UI for manual testing/control:

### Pool Management
- **PRIME**: Extract tokens from bag and build pool
- **COLLECT**: Collect all status tokens back to bag

### Family Actions
- **M+**: Add marriage token (auto-target)
- **K+**: Add child token (auto-target, random gender)

### Housing Selection
- **H0, H1, H2, H3, H4**: Set housing level to L0-L4 (auto-target)

### Family Movement
- **REMOVE TOKENS**: Move family tokens to safe park
- **RETURN TOKENS**: Return family tokens from safe park

### Status Add Buttons
- **+GK, +EXP, +DATE, +SICK, +WND, +ADD**: Add specific status tokens (auto-target)

### Status Remove Buttons
- **-GK, -EXP, -DATE, -SICK, -WND, -ADD**: Remove specific status tokens (auto-target)
- **CLEAR**: Clear all status tokens (auto-target)

## 📊 Slot Placement Logic

### Family Token Order
1. Player token (always slot 1)
2. Marriage token (slot 2, if present)
3. Children tokens (slots 3-6, in order added, max 5 children with marriage)

### Status Token Order (Canonical)
1. Good Karma (slot 1)
2. Experience (slot 2)
3. Dating (slot 3)
4. SICK (slot 4)
5. WOUNDED (slot 5)
6. Addiction (slot 6)

### Housing Placement
- **L0 (Board)**: Tokens placed on player board using `FAMILY_SLOTS_BOARD[color].L0`
- **L1-L4 (Estates)**: Tokens placed on estate card using `FAMILY_SLOTS_CARD[level]`
- Tokens are placed sequentially with delays for smooth animation

## 🔧 Technical Details

### Pool System
- **POOL Structure**: `POOL[tag] = {token1, token2, ...}` - organized by status tag
- **Token Request**: `requestTokenByTag(tag)` removes first token from pool list
- **Token Recycling**: Removed status tokens go to recycle lane (parked near engine) instead of bag
- **Pool Priming**: Sequential extraction from bag with callback chaining

### Color Resolution
- **Yellow as Reference**: Slot tables defined for Yellow, cloned to other colors on load
- **Slot Cloning**: `shallowCloneSlots()` creates copies of Yellow's slot coordinates for other colors
- **Dynamic Resolution**: `resolveTargetColor()` implements 4-tier priority system

### Coordinate System
- **Local Coordinates**: All slots defined in local coordinate space relative to parent (board/estate card)
- **World Conversion**: `worldFromLocal()` converts local coordinates to world positions
- **Sequential Placement**: `placeTokensSequential()` places tokens one by one with delays

### State Management
- **FAMILY[color]**: Stores marriage token, children array, housing level/estate reference
- **STATUSES[color]**: Stores active status tokens by tag
- **POOL**: In-memory pool of available tokens by tag

## ⚠️ Notes

### Important Behaviors
- **PRIME Required**: Most operations require pool to be primed first (tokens extracted from bag)
- **Max 6 Statuses**: Enforced limit of 6 active status tokens per player
- **Family Limit**: Maximum 5 children when marriage present (total 6 slots: player + marriage + 4 children max)
- **Children Return to Bag**: Removing children returns them to bag (unlike status tokens which go to recycle)
- **Recycle vs Bag**: Status tokens go to recycle lane (mid-game tidy), not bag until COLLECT

### Dependencies
- **Token Bag**: Must contain all status/family tokens, tagged appropriately
- **Player Boards**: Must have correct tags (`WLB_BOARD` + color tag) and slot calibrations
- **Estate Cards**: Must have `WLB_ESTATE_CARD` tag and correct names (`ESTATE_L1`, etc.)
- **Turn Controller**: Provides `Turns.turn_color` for auto-target resolution

### Slot Calibration
- Slot positions are hardcoded in script (Yellow reference, cloned to other colors)
- For L0 slots: Calibrated using SCANNER tools (PersoBoard + Apart)
- For L1-L4 slots: Calibrated for estate cards
- For status slots: 6 slots per player board

### Auto-Target Benefits
- **Event Engine**: Can apply effects to active player without specifying color
- **Victim Scenarios**: Can explicitly target other players when needed
- **Manual Testing**: Buttons work with clicking player or active turn
- **Backward Compatible**: Explicit color still supported and takes priority
