# Object #40: WLB EVENTS CONTROLLER

## 📋 Overview
The `WLB EVENTS CONTROLLER` script (`1339d3_EventsController.lua`) is the **UI and track management system for event cards**. It manages the 7-slot event track, deals cards from Youth/Adult decks, handles player interactions (clicking cards to play them), enforces obligatory card rules, charges extra AP for deeper slots, and coordinates with the Event Engine for card resolution. Version 3.6.0.

## 🚀 Core Functionality

### Event Track Management
- **7-Slot Track**: Manages 7 slots on the Event Board where event cards are displayed
- **Position-Based Tracking**: Uses world position vectors (not zones) to track cards on slots
- **Slot Positioning**: Cards are placed on slots using local coordinates relative to Event Board (GUID: `d031d9`)
- **Track State**: Persists slot assignments in script state (`state.track.slots[1-7]`)

### Card Dealing and Refilling
- **Refill Empty Slots**: Automatically deals cards from active deck (Youth/Adult) to fill empty slots
- **Deal Direction**: Fills slots from back to front (slot 7 → slot 1)
- **Auto vs. Manual**: Supports AUTO mode (automatic refill after NEXT) or MANUAL mode (refill on button press)
- **Card Tagging**: Ensures cards/decks have proper tags (`WLB_EVT_CARD`, `WLB_DECK_YOUTH`/`WLB_DECK_ADULT`, etc.)

### Turn Progression (NEXT)
- **Discard Front Cards**: At turn end, discards N cards from front (N = discard count for player count: 2p=3, 3p=2, 4p=1)
- **Compact Remaining**: Moves remaining cards forward to fill empty slots
- **Auto-Refill**: In AUTO mode, automatically refills empty slots after NEXT

### New Game Setup
- **Card Collection**: Collects all event cards from table (slots 1-7, deck area, used pile, player hands, anywhere)
- **Slot Collection Fix (v3.6.0)**: Collects cards from slots by WORLD POSITION (independent of `state.track`) BEFORE clearing track
- **Kind Classification**: Separates cards into Youth and Adult by tags, prefixes (`YD_` vs `AD_`), or deck names
- **Parking System**: Moves collected cards to parking positions to prevent merging issues
- **Deck Merging**: Merges all cards of same kind into single deck at parking position
- **Shuffling**: Shuffles merged decks before rehoming
- **Rehoming**: Moves active deck (Youth or Adult) back to deck position on Event Board

### Player Interaction (Card UI)
- **Idle State**: Cards on track have invisible click-catcher button with tooltip
- **Modal State**: Clicking card opens modal with YES/NO buttons, lifts card above track
- **Engine Modal Protection**: Detects if Event Engine has modal buttons (dice/choices) and doesn't overwrite them
- **Card Lifting**: Cards are lifted above track during modal interaction to prevent accidental moves

### Obligatory Card System
- **Slot 1 Lock**: If slot 1 contains an obligatory card, all other slots are locked (cannot be played)
- **Engine Check**: Queries Event Engine's `isObligatoryCard()` to determine if card is obligatory
- **Watchdog**: Periodic refresh checks slot 1 for obligatory status (every 0.45 seconds)
- **Next Turn Block**: NEXT turn is blocked if slot 1 has obligatory card
- **Notification**: Warns player if they try to play non-slot-1 card when slot 1 is obligatory

### Extra AP System
- **Slot-Based Extra AP**: Deeper slots cost extra AP:
  - Slot 1: +0 AP
  - Slots 2-3: +1 AP
  - Slots 4-5: +2 AP
  - Slots 6-7: +3 AP
- **Pre-Check**: Checks if player has enough AP before calling Event Engine
- **Post-Charge**: Charges extra AP AFTER Event Engine successfully processes card (base AP is charged by Engine)

### Integration with Event Engine
- **playCardFromUI()**: Calls Event Engine's `playCardFromUI()` with card GUID, player color, and slot index
- **Status Handling**: Handles engine return status (`DONE`, `WAIT_CHOICE`, `WAIT_DICE`, `BLOCKED`, `ERROR`)
- **isObligatoryCard()**: Queries Event Engine to check if card is obligatory

### Integration with AP Controller
- **AP Controller Lookup**: Finds player's AP Controller by tags (`WLB_AP_CTRL` + `WLB_COLOR_*`)
- **AP Checking**: Uses `canSpendAP()` to check if player can afford extra AP
- **AP Charging**: Uses `spendAP()` to charge extra AP for deeper slots

## ⚙️ Configuration

### GUIDs
- `EVENT_BOARD_GUID`: `"d031d9"` (Event Board for coordinate transformations)
- `EVENT_ENGINE_GUID`: `"7b92b3"` (Event Engine for card processing)

### Local Positions (on Event Board)
- `deck`: `{x=-6.825, y=0.592, z=1.063}` (deck position)
- `used`: `{x=6.841, y=0.592, z=1.522}` (used pile position)
- `slots[1-7]`: Array of local positions for each slot (slot 1 is front, slot 7 is back)

### Parking Positions (World Coordinates)
- `PARK_YOUTH_POS`: `{x=41, y=5.7, z=-28}` (temporary parking for Youth cards during new game)
- `PARK_ADULT_POS`: `{x=36, y=5.7, z=-28}` (temporary parking for Adult cards during new game)

### Tags
- `WLB_EVT_CARD`: Tag for all event cards
- `WLB_DECK_YOUTH` / `WLB_DECK_ADULT`: Tags for Youth/Adult decks
- `WLB_EVT_YOUTH_CARD` / `WLB_EVT_ADULT_CARD`: Tags for Youth/Adult cards
- `WLB_AP_CTRL`: Tag for AP Controllers
- `WLB_COLOR_*`: Color tags (`WLB_COLOR_Yellow`, etc.)

### Constants
- `SLOT_DIST_EPS`: `1.25` (distance threshold for slot position detection)
- `DECK_DIST_EPS`: `2.25` (distance threshold for deck position detection)
- `USED_DIST_EPS`: `2.25` (distance threshold for used pile detection)
- `EXTRA_BY_SLOT`: `{[1]=0, [2]=1, [3]=1, [4]=2, [5]=2, [6]=3, [7]=3}` (extra AP cost per slot)
- `DEAL_Y_OFFSET`: `0.35` (vertical offset when dealing cards to slots)
- `UI_LIFT_Y`: `2.2` (vertical lift when card modal opens)

## 🔗 External API

### Public Functions (for other systems)
- `WLB_EVT_NEWGAME(params)`: Starts new game setup
  - Parameters: `{kind="YOUTH"/"ADULT", refill=true/false}`
  - Returns: `true` if started, `false` if blocked
- `WLB_EVT_REFILL(_)`: Manually refills empty slots
- `WLB_EVT_NEXT(_)`: Advances turn (discards front cards, compacts, refills)
- `EVT_AUTO_NEXT_TURN()`: Same as `WLB_EVT_NEXT` but with obligatory card check for NEXT blocking
- `EVT_AUTO_REFILL_AFTER_RESET(params)`: Delayed refill after reset (for other controllers)
  - Parameters: `{delay=seconds}`
- `setPlayers(params)`: Sets player count (2, 3, or 4)
  - Parameters: `{players=N}` or `{n=N}` or `{count=N}`
- `setMode(params)`: Sets mode (AUTO or MANUAL)
  - Parameters: `{mode="AUTO"/"MANUAL"}`
- `WLB_EVT_SLOT_EXTRA_AP(params)`: Returns extra AP cost for slot
  - Parameters: `{slot_idx=N}`
  - Returns: Extra AP cost (0-3)

### Card UI Callbacks
- `evt_onCardClicked(card, player_color, alt_click)`: Opens modal when card is clicked
- `evt_onYes(card, player_color, alt_click)`: Processes card play (calls Event Engine)
- `evt_onNo(card, player_color, alt_click)`: Closes modal without playing

## 🎮 Controller UI Buttons

### Row 1
- **MODE**: Toggles between AUTO and MANUAL mode
- **SETUP**: Checks for Event Board and sets up system
- **REFILL**: Manually refills empty slots
- **NEXT**: Advances turn (discards, compacts, refills if AUTO)

### Row 2
- **P2/P3/P4**: Sets player count (2, 3, or 4 players)
- **STATUS**: Prints status dump to console

### Row 3 (Info Display)
- **KIND**: Shows active deck kind (YOUTH/ADULT)
- **SETUP**: Shows setup status (true/false)
- **JOB**: Shows current job ID (for new game pipeline)
- **NEWGAME**: Starts new game setup for active deck kind

## ⚠️ Notes

### Version 3.6.0 Changes
1. **Fixed Slot Collection**: NEWGAME now ALWAYS collects cards from slots 1-7 by WORLD POSITION before clearing track (prevents losing card references)
2. **Position-Based Collection**: Slot collection is independent of `state.track` state, uses position detection instead

### State Persistence
- **Persisted**: `state.setup`, `state.players`, `state.mode`, `state.deckKind`, `state.track.slots`, `state.resetInProgress`, `state.jobId`
- **Not Persisted**: `uiState` (modal state, card home positions), `obligatoryLock`, `nextBusy`, `desiredDeckRot`

### Turn System Integration
- Uses `Turns.turn_color` to determine active player color (if available)
- Falls back to `player_color` parameter from card click if `Turns.turn_color` is not available

### Heuristics for Card Classification
- **Tags**: Primary method (checks `WLB_EVT_YOUTH_CARD` / `WLB_EVT_ADULT_CARD`)
- **Prefixes**: Fallback (checks card name/description for `YD_` vs `AD_` prefixes)
- **Deck Names**: Fallback for decks (checks if name is "YDECK" or "ADECK")

### Anti-Merge Protection
- Cards are moved to parking positions during new game to prevent TTS from auto-merging decks
- Decks are merged only when explicitly intended (during new game pipeline phase)

### Position Tracking
- Uses Event Board's `positionToWorld()` / `positionToLocal()` for coordinate transformations
- All slot positions are defined as LOCAL coordinates relative to Event Board
- Distance checks use 2D distance (ignoring Y-axis) for slot detection

### Card UI State Machine
- **Idle**: Invisible click-catcher button with tooltip
- **Modal**: YES/NO buttons, card lifted above track
- **Engine Modal**: Detects Event Engine's modal buttons (dice/choices) and preserves them
- **Transition**: Smooth position transitions when opening/closing modal

### Job ID System
- Each new game operation gets a unique `jobId` to prevent race conditions
- Operations check `jobId` before executing to ensure they're still valid
- Used in multi-phase `Wait.time()` chains to prevent overlapping operations
