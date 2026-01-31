# Estate Engine (Market Controller) - Documentation

**GUID:** `fd8ce0`  
**Tags:** `WLB_MARKET_CTRL`  
**Type:** Tile  
**Version:** 1.8.1

---

## Overview

The Estate Engine manages the apartment/estate system in the game. Players can rent or buy estates from 4 different levels (L1-L4), place them on their player boards, and later return or sell them. The system uses Action Points (AP) and integrates with player boards, AP controllers, and the Shops Board.

---

## Functionality

### Main Purpose
- **Estate Management**: Manages 4 levels of estates (L1, L2, L3, L4) in separate decks
- **Rent/Buy System**: Players can rent (temporary) or buy (permanent) estates
- **Placement System**: Automatically places estate cards on player boards at designated slots
- **Return/Sell System**: Players can return rented estates or sell bought estates
- **Deck Organization**: "PARK" system to organize loose cards and position decks
- **Dummy Card Handling**: Skips "SOLD OUT" dummy cards when drawing

### Key Features
- Two-stage deck UI (Prompt → Actions)
- Card buttons on placed estates (RETURN/SELL)
- AP integration (spends 1 AP to "Events" category)
- Color normalization (handles "Player Yellow" → "Yellow")
- Safe visible button positioning
- Parking system for deck organization

---

## Game Integration

### Related Objects
- **Shops Board** (GUID: `2df5f1`) - Board where estate decks are parked
- **Player Boards** - Where estates are placed (one per player)
- **AP Controllers** - Per-player AP management (tag: `WLB_AP_CTRL` + color tag)
- **Estate Decks** - 4 decks tagged `WLB_DECK_L1`, `WLB_DECK_L2`, `WLB_DECK_L3`, `WLB_DECK_L4`

### Estate Levels
- **L1**: Level 1 estates (lowest tier)
- **L2**: Level 2 estates
- **L3**: Level 3 estates
- **L4**: Level 4 estates (highest tier)

---

## UI Elements

### Tile Buttons (on Estate Engine tile)
1. **SCAN ESTATES** - Refreshes deck references and rebuilds deck UI
2. **RESET UI** - Forces all deck UIs back to PROMPT stage
3. **DEBUG** - Prints diagnostic info (boards, shopboard, parking, loose cards)
4. **PARK DEX** - Recollects loose real cards to top of decks, then parks decks
5. **FORCE UNLOCK** - Emergency unlock if PARK gets stuck

### Deck UI (on each estate deck)

**Stage 1: PROMPT**
- Single button with "⋯" symbol
- Tooltip: "What would you like to do with this property?"
- Clicking opens action menu

**Stage 2: ACTIONS**
- **RENT** (blue button) - Spend 1 AP and rent estate
- **NOTHING** (gray button) - Close menu
- **BUY** (green button) - Spend 1 AP and buy estate

### Card Buttons (on placed estate cards)
- **RETURN** - For rented estates (returns to deck)
- **SELL** - For bought estates (sells for 50% refund, returns to deck)
- Position: Center-top of card (safe visible position)
- Requires 1 AP to use

---

## Estate Actions

### Rent Estate
1. Player clicks deck → PROMPT button
2. Clicks RENT button
3. System checks:
   - Active player color
   - Player doesn't already have an estate
   - Player has 1 AP available
4. Takes top real card from deck (skips dummy cards)
5. Places card on player's board at estate slot
6. Tags card: `WLB_ESTATE_OWNED`, `WLB_ESTATE_MODE_RENT`, color tag
7. Adds RETURN button to card
8. Spends 1 AP to "Events" category

### Buy Estate
1. Same flow as Rent, but:
   - Tags card: `WLB_ESTATE_MODE_BUY` (instead of RENT)
   - Adds SELL button to card
   - (Future: Would deduct money, currently placeholder)

### Return Estate (Rented)
1. Player clicks RETURN button on their estate card
2. System checks:
   - Player owns the card (color tag match)
   - Player has 1 AP available
3. Removes ownership tags
4. Returns card to top of appropriate deck (drop-from-above animation)
5. Spends 1 AP

### Sell Estate (Bought)
1. Player clicks SELL button on their estate card
2. Same checks as Return
3. Calculates refund (50% of purchase price - currently placeholder)
4. Returns card to deck
5. Spends 1 AP

---

## Parking System

The PARK system organizes loose estate cards and positions decks:

1. **Collects Loose Cards**: Finds all real estate cards not in decks
   - Checks table, player hands
   - Groups by level (L1, L2, L3, L4)

2. **Stacks on Top**: Places loose cards on top of their respective decks
   - Dummy cards stay at bottom
   - Real cards stack on top
   - Uses height-based stacking with delays

3. **Parks Decks**: Moves all 4 decks to parking positions on Shops Board
   - Each level has designated parking spot
   - Smooth movement animation

**Safety Features:**
- Lock system prevents multiple PARK operations
- Timeout protection (14 seconds)
- Force unlock button for emergencies

---

## AP Integration

- **Category**: "E" (Events)
- **Cost**: 1 AP per action
- **Actions requiring AP**:
  - Rent estate
  - Buy estate
  - Return estate
  - Sell estate

The system calls `canSpendAP()` and `spendAP()` on the player's AP Controller.

---

## Tag System

### Card Tags
- `WLB_ESTATE_CARD` - Identifies estate cards
- `WLB_ESTATE_DUMMY` - Marks dummy/SOLD OUT cards
- `WLB_ESTATE_OWNED` - Card is owned by a player
- `WLB_ESTATE_MODE_RENT` - Card is rented
- `WLB_ESTATE_MODE_BUY` - Card is bought
- `WLB_COLOR_[Color]` - Player color tag

### Deck Tags
- `WLB_ESTATE_DECK` - Identifies estate decks
- `WLB_DECK_L1` - Level 1 deck
- `WLB_DECK_L2` - Level 2 deck
- `WLB_DECK_L3` - Level 3 deck
- `WLB_DECK_L4` - Level 4 deck

---

## Estate Placement

Each player board has a designated estate slot position (local coordinates):
- **Yellow**: `{x=1.259, y=0.592, z=-0.238}`
- **Blue**: `{x=1.265, y=0.592, z=-0.198}`
- **Red**: `{x=1.134, y=0.592, z=-0.202}`
- **Green**: `{x=1.222, y=0.592, z=-0.301}`

Cards are placed at these positions with slight Y offset to prevent sinking.

---

## External API Functions

### `miRequestPark(params)`
- **Parameters**: Table with optional `delay` (number)
- **Returns**: `true`
- **Usage**: Called by Turn Controller to park decks
- **Example**: `miRequestPark({delay = 2.0})`

### `miRequestParkAndScan(params)`
- **Parameters**: Table with optional `delay` (number)
- **Returns**: `true`
- **Usage**: Parks decks and then scans (same as PARK + SCAN)
- **Example**: `miRequestParkAndScan({delay = 0})`

---

## Technical Details

### Color Normalization
Handles various color formats:
- "Player Yellow" → "Yellow"
- "yellow" → "Yellow"
- Trims whitespace
- Maps common variations

### Dummy Card Detection
Cards are considered dummy if:
- Has tag `WLB_ESTATE_DUMMY`
- Name contains "SOLD OUT"
- Name contains " SOLD"

### Card Return Animation
- Drops card from height above deck
- Uses `RETURN_DROP_HEIGHT` (3.2 units)
- Merges into deck after delay
- Prevents card from getting stuck

### Safe Method Calls
All object interactions use `safeCall()` wrapper to prevent crashes.

---

## Error Handling

- Validates player boards exist before placement
- Checks AP availability before actions
- Prevents multiple estates per player
- Validates deck references before operations
- Shows color-coded broadcast messages:
  - ⛔ Red = Error
  - 🟦 Blue = Info
  - 🟩 Green = Success
  - 💰 Yellow = Money/Refund

---

## Known Limitations / Placeholders

- **Estate Prices**: Currently set to 0 (placeholder)
- **Sell Refund**: Calculated but not actually paid (placeholder)
- **Money Integration**: Not yet wired to Money engine

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Fully Functional** - Complete estate management system
