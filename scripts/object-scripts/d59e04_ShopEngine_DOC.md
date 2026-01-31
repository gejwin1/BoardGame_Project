# Object #27: SHOP ENGINE (GUID: d59e04)

## 📋 Overview
The `SHOP ENGINE` script (`d59e04_ShopEngine.lua`) is a comprehensive game system responsible for managing the three types of shop cards in the game: **Consumables (C)**, **Hi-Tech (H)**, and **Investments (I)**. It handles shop card placement, purchasing, card effects, deck management, and integrates with money, AP, stats, and status controllers. The engine features a modal UI for card purchases, automated pipelines for shop setup/reset, and supports 28 consumable cards with various game effects. Version 1.3.4.

## 🚀 Core Functionality

### Shop Management
- **Three Shop Rows**: Consumables (C), Hi-Tech (H), Investments (I)
- **Slot System**: Each row has 1 CLOSED slot (deck position) and 3 OPEN slots (card display)
- **Card Classification**: Uses name-based patterns (`CSHOP_XX_*`, `HSHOP_XX_*`, `ISHOP_XX_*`) to identify shop cards
- **Deck Integration**: Manages shop card decks, automatically collects loose cards, shuffles, and deals cards

### Card Purchasing System
- **Modal UI**: Click a card in OPEN slot → shows YES/NO modal for purchase confirmation
- **Entry Cost**: First purchase per turn costs 1 AP (tracked per player color)
- **Card Costs**: Money (WIN) and optional extra AP costs defined per card
- **Buyer Resolution**: Determines buyer by active turn color (`Turns.turn_color`) or clicking player
- **Card Return**: Purchased cards are returned to their deck (not destroyed) for RESET to restore full shop

### Consumable Card Effects (28 cards)
- **CURE** (6 cards): Removes SICK/WOUNDED status, adds Health, roll-based success
- **KARMA** (2 cards): Adds GOOD_KARMA status
- **BOOK** (2 cards): +2 Knowledge
- **MENTORSHIP** (2 cards): +2 Skills
- **SUPPLEMENTS** (3 cards): +2 Health
- **PILLS** (5 cards): Anti-Sleeping Pills (TODO: +3 rest-equivalent)
- **NATURE_TRIP** (2 cards): +2 AP cost, roll D6 for +SAT, +3 rest-equivalent (TODO)
- **FAMILY** (2 cards): Roll D6 for chance to add child (BOY/GIRL)
- **SAT** (4 cards): Balloon (+4), Gravity (+12), Bungee (+6), Parachute (+8) - Satisfaction bonuses

### Shop Pipelines
1. **RESET**: Complete shop reset
   - Closes all cards/decks
   - Collects all loose shop cards into decks (by name)
   - Moves decks to CLOSED positions
   - Shuffles all decks
   - Deals 3 cards to OPEN slots for each row

2. **REFILL**: Fills empty OPEN slots without mixing existing cards

3. **RANDOMIZE** (per row): Randomizes a single row
   - Returns OPEN cards to deck
   - Shuffles deck
   - Deals 3 new cards

## 🔗 External API

### Public Functions (for other controllers)
- `API_reset()`: Triggers full shop reset pipeline
- `API_refill()`: Triggers refill pipeline
- `API_randomize(args)`: Randomizes a specific row (`{row="C"}` or `{row="H"}` or `{row="I"}`)
- `API_refreshUI()`: Refreshes UI on all shop OPEN cards

## 🔗 Integration with Other Systems

### Controllers Used
- **Money Controller** (`WLB_MONEY` + color tag): Spending/adding money via `API_spend`, `addMoney`
- **AP Controller** (`WLB_AP_CTRL` + color tag): Spending AP via `spendAP({to="E", amount=N})`
- **Stats Controller** (`WLB_STATS_CTRL` + color tag): Modifying Health/Knowledge/Skills via `applyDelta`
- **Player Status Controller** (`WLB_PLAYER_STATUS_CTRL`): Managing status tags (SICK, WOUNDED, GOOD_KARMA) and children via `PS_Event`
- **Turn Controller**: Reads `Turns.turn_color` to determine active player

### Turn Tracking
- Monitors `Turns.turn_color` via `onUpdate()` hook
- Tracks `boughtThisTurn[color]` to enforce 1 AP entry cost per turn
- Resets entry cost tracking when turn changes

## ⚙️ Configuration

### Tags
- `TAG_SHOPS_BOARD`: `"WLB_SHOP_BOARD"` (Required on Shops Board)
- `TAG_SHOP_CARD`: `"WLB_SHOP_CARD"` (Applied to all shop cards)
- `TAG_SHOP_DECK`: `"WLB_SHOP_DECK"` (Shop deck tag)
- `TAG_DECK_C/H/I`: Specific deck tags for each shop type
- Controller and status tags for integration

### Slot Positions (Local coordinates on Shops Board)
- Defined in `SLOTS_LOCAL` table for C, H, I rows
- Each row has: `closed` position and `open[1-3]` positions
- Converted to world coordinates using `board.positionToWorld()`

### Expected Card Counts
- Consumables: 28 cards
- Hi-Tech: 14 cards
- Investments: 14 cards

### Timing Constants
- `STEP_DELAY`: 1.50 seconds (between pipeline steps)
- `SHORT_DELAY`: 0.20 seconds (quick operations)
- `DEAL_Y`: 0.35 units (vertical offset when dealing cards)
- `LOCK_TIME`: 0.25 seconds (brief lock duration)

### Dependencies
- **Die GUID**: `"14d4a4"` (for random card effects requiring dice rolls)

## 🎮 UI System

### Shop Card UI States

#### IDLE State (card in OPEN slot)
- Transparent click-catcher overlay button
- Tooltip: "Do you want to buy this card?"
- Description set on card

#### MODAL State (card clicked)
- Card lifted 2.0 units up
- Question label: "Do you want to buy this card?"
- YES button (green) and NO button (red)
- Card locked during modal

#### After Purchase
- Card returned to deck (or CLOSED slot fallback)
- UI cleared

### Controller Tile UI Buttons
- **RESET**: Full shop reset (all rows)
- **REFILL**: Fill empty OPEN slots
- **RAND C/H/I**: Randomize specific row
- **CHECK**: Debug report (loose/deck counts)
- **+1000 WIN**: Debug button to add money to active player

## 📊 Card Definitions (`CONSUMABLE_DEF`)

Each consumable card has:
- `cost`: Money cost in WIN
- `extraAP`: Additional AP cost (beyond entry AP)
- `kind`: Effect type (CURE, KARMA, BOOK, etc.)
- Additional fields for specific effects (e.g., `sat` for satisfaction cards)

## 🔧 Technical Details

### Name-Based Classification
- Uses Lua pattern matching to classify cards by name
- Patterns: `^CSHOP_%d%d_`, `^HSHOP_%d%d_`, `^ISHOP_%d%d_`
- No reliance on tags for card identification (tags applied automatically)

### Board Resolution
- Finds Shops Board by `WLB_SHOP_BOARD` tag
- Stores board reference and desired Y rotation
- Converts local slot coordinates to world positions

### Safe Method Calls
- Extensive use of `pcall()` and `safeCall()` for robustness
- Safe broadcast functions handle missing player seats
- Normalizes boolean results from controller APIs

### Job System
- Uses job IDs to prevent concurrent pipeline execution
- `S.busy` flag prevents overlapping operations
- Jobs can be cancelled if new job starts

### Card Position Detection
- Uses distance-based detection (`EPS_SLOT` tolerance)
- Checks if cards are in OPEN slot positions
- Only cards in OPEN slots get interactive UI

## ⚠️ Notes

### Important Behaviors
- **Cards are NOT destroyed on purchase**: They are returned to their deck or CLOSED slot, allowing RESET to restore full shop
- **Entry AP cost**: First purchase per turn costs 1 AP (tracked per color, resets on turn change)
- **Buyer resolution**: Uses active turn color (`Turns.turn_color`) if available, falls back to clicking player
- **AP spending**: Requires `to="E"` parameter for AP Controller compatibility (Events area)

### Limitations / TODOs
- Only Consumables (C) are fully implemented; Hi-Tech (H) and Investments (I) cards exist but purchase flow is limited
- Some effects marked as TODO (Anti-Sleeping Pills rest-equivalent, Nature Trip rest-equivalent, Child costs)
- SAT API not fully wired (uses fallback broadcast messages)

### Safety Features
- Extensive error handling and safe method calls
- Validates card position before purchase
- Checks for sufficient funds/AP before allowing purchase
- Safe broadcast functions prevent crashes from missing player seats
