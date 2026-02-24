# Object #41: WLB TURN CTRL

## 📋 Overview
The `WLB TURN CTRL` script (`c9ee1a_TurnController.lua`) is the **central turn management and game start wizard system**. It orchestrates game initialization (Youth/Adult mode selection, player count, turn order via dice rolls), manages turn progression with AP confirmation, handles end-of-turn processing (health from REST, blocked AP from health), and automates per-turn actions (shop refills, status expiration). Version 2.9.0.

## 🚀 Core Functionality

### Start Wizard
A multi-step wizard that guides players through game setup:

1. **HOME Step**: Choose game mode (YOUTH or ADULT)
2. **PLAYERS Step**: Choose player count (2, 3, or 4)
3. **ORDER Step**: Roll physical die to determine turn order
   - Players roll in random order
   - Results determine final turn order (highest roll first, ties broken by roll order)
   - For ADULT mode, roll values are also used for start bonuses (no second roll)
4. **START GAME**: Executes comprehensive start game pipeline

### Start Game Pipeline
When "START GAME" is clicked, the system:
1. Resets satisfaction tokens to 10
2. Resets all controllers (Stats, AP, Money) via `resetNewGame()` calls
3. Calls `Global.WLB_NEW_GAME()` for global reset
4. Triggers Event Controller's new game prep (`WLB_EVT_NEWGAME` or `EVT_NEW_GAME_PREP`)
5. Calls TokenEngine `API_collect()` → waits 3 seconds → `API_prime()` (token setup)
6. Calls ShopEngine `API_reset()` (shop setup)
7. Auto-parks Estates via MarketController `miRequestParkAndScan()` or `miRequestPark()`
8. Sets Year Token to appropriate round (1 for YOUTH, 6 for ADULT)
9. Sets active turn to first player
10. Places player tokens on Apartment L0 via `TokenEngine.API_placePlayerTokens()`
11. (ADULT mode only) Initializes Adult Start bonus allocation UI

### Turn Progression
- **NEXT TURN Button**: Advances to next player's turn (or next round if all players have played)
- **AP Confirmation**: If player has unspent AP, shows confirmation dialog before ending turn
- **Event Track Advancement**: Automatically triggers Event Controller's `EVT_AUTO_NEXT_TURN()` which handles event track progression
- **Round Progression**: Automatically advances to round 2, 3, etc. after all players have taken turns
- **Year Token Update**: Updates Year Token round and color (tinted to active player color)

### End-of-Turn Processing
When a turn ends:
1. **REST AP → Health**: Calculates health delta from REST AP count (REST - 4 = health change)
2. **Health → Blocked AP**: Applies blocked AP next round based on health:
   - Health ≤ 0: 6 AP blocked
   - Health ≤ 3: 3 AP blocked
   - Health ≤ 6: 1 AP blocked
   - Health > 6: 0 AP blocked
3. **AP Finalization**: Calls `Global.WLB_END_TURN()` to finalize AP state
4. **Status Expiration**: Removes one-turn statuses (SICK, WOUNDED) from player

### Per-Turn Automation
- **Start of Turn**: Automatically calls `ShopEngine.API_refill()` to fill empty shop slots (very small delay: 0.05s)
- **End of Turn**: Expires one-turn status tokens (SICK, WOUNDED) via TokenEngine

### Adult Start Bonuses
For ADULT mode games:
- **Uses Order Rolls**: The dice rolls used for turn order are also used for start bonuses (no second roll needed)
- **Bonus Calculation**: `pool = 10 + roll`, `money = 1400 - (200 * roll)`
- **Allocation UI**: Players allocate pool points between Knowledge (K) and Skills (S)
- **Application**: Each player applies bonuses via Stats Controller's `adultStart_apply({k=N, s=N})` method
- **Sequential**: Players allocate one at a time (first player completes before next player's UI appears)

## 🎮 Wizard States

### HOME
- **Buttons**: START YOUTH, START ADULT
- **Purpose**: Choose game mode

### PLAYERS
- **Buttons**: 2 PLAYERS, 3 PLAYERS, 4 PLAYERS
- **Purpose**: Choose player count
- **Displays**: Current mode and round start

### ORDER
- **Buttons**: ROLL NOW button (one player at a time)
- **Purpose**: Roll dice to determine turn order
- **Displays**: Current roll order and results
- **Completion**: "START GAME" button appears after all players have rolled

### RUNNING
- **Buttons**: RESTART, NEXT TURN, (AP confirmation if needed), (Adult allocation UI if applicable)
- **Purpose**: Main game state
- **Displays**: Current round, active player
- **Adult Mode**: Shows allocation UI for current player (if stage is ALLOC)

## 🔗 External API

### Public Functions
- None (internal system, driven by UI buttons)

### Integration Points
- **Event Controller**: 
  - `API_setPlayers(n)` / `setPlayers(n)`
  - `API_setMode(mode)` / `setMode(mode)`
  - `WLB_EVT_NEWGAME({kind, refill})` / `EVT_NEW_GAME_PREP({kind})`
  - `EVT_AUTO_NEXT_TURN()`
- **TokenEngine**:
  - `API_collect()`
  - `API_prime()`
  - `API_placePlayerTokens({colors})`
  - `TE_RemoveStatus_ARGS({color, statusTag})`
- **ShopEngine**:
  - `API_reset()`
  - `API_refill()`
- **MarketController**:
  - `miRequestParkAndScan({delay})` / `miRequestPark({delay})`
- **Global**:
  - `WLB_NEW_GAME({mode, players})`
  - `WLB_END_TURN({color})`
  - `WLB_SET_BLOCKED_INACTIVE({color, count})`
  - `WLB_ON_TURN_CHANGED({newColor, prevColor})`
- **Year Token** (GUID: `465776`):
  - `setRound({round})`
  - `setColor({color})` / `setColorTint()`
- **Physical Die** (GUID: `14d4a4`):
  - `randomize()`, `roll()`, `getValue()`, `resting`

## ⚙️ Configuration

### GUIDs
- `TOKENYEAR_GUID`: `"465776"` (Year Token)
- `DIE_GUID`: `"14d4a4"` (Physical die for turn order)

### Tags
- `WLB_EVT_CONTROLLER` / `WLB_EVT_CTRL`: Event Controller tags
- `WLB_MARKET_CTRL`: Market Controller tag
- `WLB_TOKEN_ENGINE`: Token Engine tag
- `WLB_SHOP_ENGINE`: Shop Engine tag
- `WLB_STATS_CTRL`: Stats Controller tag
- `WLB_MONEY`: Money Controller tag
- `WLB_AP_CTRL`: AP Controller tag
- `SAT_TOKEN`: Satisfaction Token tag
- `WLB_COLOR_*`: Color tags

### Constants
- `MAX_ROUND`: `13` (maximum game rounds)
- `EVT_DEFAULT_MODE`: `"AUTO"` (default Event Controller mode)
- `DEFAULT_COLORS`: `{"Yellow","Blue","Red","Green"}` (player colors)
- `AUTO_TOKEN_PRIME_DELAY`: `3.0` seconds (delay between collect and prime)
- `AUTO_SHOP_RESET_DELAY`: `0.2` seconds (delay for shop reset)
- `AUTO_SHOP_REFILL_DELAY`: `0.05` seconds (delay for shop refill at turn start)
- `AUTO_PARK_DELAY`: `1.2` seconds (delay for estate parking)

### Adult Start Bonus Formula
- **Pool**: `10 + roll` (points to allocate between K and S)
- **Money**: `1400 - (200 * roll)`

## ⚠️ Notes

### State Persistence
- **Persisted**: All wizard state (`W` table) is saved via `onSave()` / `onLoad()`
- **State Structure**:
  - `step`: Current wizard step ("HOME", "PLAYERS", "ORDER", "RUNNING")
  - `startMode`: "YOUTH" or "ADULT"
  - `playersN`: Number of players (2, 3, or 4)
  - `rolls`: `{Yellow=roll, Blue=roll, ...}` (dice roll results)
  - `finalOrder`: `{color1, color2, ...}` (final turn order)
  - `currentRound`: Current game round (1-13)
  - `turnIndex`: Current player index in `finalOrder` (1-based)
  - `adult`: Adult start allocation state (`{stage="IDLE"/"ALLOC"/"DONE", per={color={pool, k, s, active, roll, money}}}`)
  - `endConfirm`: Confirmation state if player has unspent AP (`{color, apLeft}`)

### Turn Order Determination
- **Roll Order**: Players roll in randomized order (shuffled from color list)
- **Sorting**: Turn order sorted by roll value (highest first), ties broken by roll order (earlier roll wins)

### Health → Blocked AP Calculation
- Health ≤ 0: 6 AP blocked next round
- Health 1-3: 3 AP blocked next round
- Health 4-6: 1 AP blocked next round
- Health > 6: 0 AP blocked

### REST → Health Calculation
- Health delta = `REST_AP_COUNT - 4`
- If player has 4 AP in REST, no health change
- If player has < 4 AP in REST, health decreases
- If player has > 4 AP in REST, health increases

### Status Expiration
- **One-turn statuses**: SICK (`WLB_STATUS_SICK`) and WOUNDED (`WLB_STATUS_WOUNDED`)
- **Timing**: Expired at end of player's own turn (window-of-reaction mechanic)
- **Method**: Calls `TokenEngine.TE_RemoveStatus_ARGS({color, statusTag})`

### AP Confirmation System
- **Check**: Before ending turn, checks if player has unspent AP
- **Confirmation**: If AP > 0, shows confirmation dialog with remaining AP count
- **Options**: YES (end turn anyway) or NO (cancel, continue playing)
- **State**: Stored in `W.endConfirm` until resolved

### Adult Start Allocation
- **Stage Management**: `W.adult.stage` can be "IDLE", "ALLOC", or "DONE"
- **Per-Player State**: `W.adult.per[color]` stores allocation state:
  - `pool`: Remaining points to allocate
  - `k`: Knowledge points allocated
  - `s`: Skill points allocated
  - `active`: Whether player still needs to allocate
  - `roll`: Dice roll value (from order determination)
  - `money`: Starting money amount
- **UI**: Shows allocation UI for current active player (one at a time)
- **Completion**: All players must allocate and apply before stage becomes "DONE"

### Integration Notes
- **Robust API Calls**: Tries multiple API method names for compatibility (`API_setPlayers` / `setPlayers` / `api_setPlayers`)
- **Safe Calls**: All external calls use `pcallCall()` wrapper for error handling
- **Global Dependencies**: Relies on Global script for AP finalization and blocked AP management
- **Event Controller**: Must support `EVT_AUTO_NEXT_TURN()` which checks for obligatory cards before advancing

### Version 2.9.0 Features
- **Full rewrite**: Complete rewrite of turn controller
- **Adult start uses order rolls**: No second dice roll needed for Adult mode bonuses
- **Per-turn automation**: Shop refill at turn start, status expiration at turn end
- **AP confirmation**: Warns players if ending turn with unspent AP
- **Comprehensive start pipeline**: Orchestrates all systems during game start
