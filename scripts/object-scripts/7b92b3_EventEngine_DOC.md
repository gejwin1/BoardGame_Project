# Object #39: WLB EVENT ENGINE

## 📋 Overview
The `WLB EVENT ENGINE` script (`7b92b3_EventEngine.lua`) is the **core system responsible for processing event cards** in the board game. It handles all Youth and Adult event cards, including card type recognition, effect application (money, satisfaction, stats, AP), dice rolling, player choices, special mechanics (marriage, children, karma), and card finalization (keep vs. discard). Version 1.7.2.

## 🚀 Core Functionality

### Card Processing Pipeline
1. **Card Recognition**: Extracts card ID from card name/description (prefixes: `YD_`, `AD_`, `CS_`, `HS_`, `IS_`, `JOB_`)
2. **Type Mapping**: Maps card IDs to card types via `CARD_TYPE` table (Youth 1-39, Adult 1-81)
3. **Effect Resolution**: Applies effects based on card type definition:
   - Instant cards: Applied immediately, then discarded
   - Keep cards: Applied and moved to keep zone
   - Obligatory cards: Must be played, cannot be avoided
4. **Finalization**: Moves cards to appropriate zones (keep zone or discard/used zone)

### Game System Integration
- **Money System**: Integrates with Money Controllers (tags: `WLB_MONEY`, `WLB_COLOR_*`)
- **Satisfaction System**: Integrates with Satisfaction Tokens (GUIDs hardcoded)
- **Stats System**: Integrates with Stats Controllers (tags: `WLB_STATS_CTRL`, `WLB_COLOR_*`)
- **AP System**: Integrates with AP Controllers (tags: `WLB_AP_CTRL`, `WLB_COLOR_*`)
- **Status System**: Integrates with PlayerStatusController hub (tag: `WLB_PLAYER_STATUS_CTRL`) → TokenEngine

### Player Interaction
- **Dice Rolling**: Uses physical die (GUID: `14d4a4`) for card effects requiring dice
- **Player Choices**: Presents A/B choices on cards (e.g., loan payment options)
- **Card UI**: Dynamically creates buttons on cards for rolling dice or making choices
- **Locking/Debouncing**: Prevents duplicate card plays within short time windows

## 🎮 Card Types Supported

### Youth Cards (YD_1 to YD_39)
- **DATE**: Dating event (+2 SAT, -30 money, 2 AP cost, adds DATING status)
- **PARTY**: Party event (+3 SAT, -50 money, 1 AP cost, dice for hangover)
- **VOLUNTARY**: Volunteer work (2 AP cost, +2 Skills)
- **MENTORSHIP**: Mentoring (2 AP cost, +2 Knowledge)
- **BEAUTY**: Beauty contest (2 AP cost, dice for money reward)
- **BIRTHDAY**: Birthday celebration (affects all other players)
- **WORK**: Various work cards (1-5 AP cost, money rewards: 150-500)
- **VOUCH**: Vouchers (keep cards for shop discounts)
- **SICK_O**: Obligatory sickness (-2 Health)
- **LOAN_O**: Obligatory loan (choice: pay 200 or -2 SAT)
- **KARMA**: Good karma (1 AP cost, adds GOOD_KARMA status, instant discard)

### Adult Cards (AD_1 to AD_81)
- **AD_SICK_O**: Obligatory sickness (-3 Health, adds SICK status)
- **AD_VOUCH**: Voucher cards (keep cards for shop discounts)
- **AD_LUXTAX_O / AD_PROPTAX_O**: Tax obligations (TODO: not fully implemented)
- **AD_DATE**: Date event (2 AP cost, bonus if married)
- **AD_CHILD**: Child birth cards (dice determines gender, cost 100/150/200, AP block mechanics)
- **AD_HI_FAIL_O**: Hi-tech failure (TODO: not implemented)
- **AD_WORKBONUS**: Work bonus (TODO: profession system not implemented)
- **AD_MARRIAGE**: Marriage event (affects all players, adds marriage status)
- **AD_KARMA**: Good karma (1 AP cost, adds GOOD_KARMA status, instant discard - **FIXED in v1.7.2**)
- **AD_AUCTION_O**: Auction event (TODO: not implemented)
- **AD_SPORT**: Sports event (1 AP cost, -100 money, dice for SAT reward)
- **AD_BABYSITTER**: Babysitter service (unlocks 1-2 AP from child block, costs 50-70 per unlock)
- **AD_AUNTY_O**: Aunty event (dice may unlock child AP block)
- **AD_VE_***: Volunteer Experience cards (TODO: choice-based, not fully implemented)

## ⚙️ Key Mechanics

### Child System (v1.7.2 Improvements)
- **Child Birth**: Dice roll (3-6) determines if child is born (1-2 = no child)
- **Child Gender**: Dice roll determines BOY (3-4) or GIRL (5-6)
- **Child Cost**: One-time cost when child is born (100, 150, or 200)
- **Per-Round Effects**: 
  - +2 SAT per round
  - -cost money per round (if affordable)
  - Blocks 2 AP per round (moved to INACTIVE)
- **AP Unlock System (NEW in v1.7.2)**:
  - `childUnlock[color]` tracks how much of the 2 AP block is unlocked this round (0-2)
  - Babysitter cards can unlock 1 or 2 AP from the block (costs 50-70 per unlock)
  - Aunty dice special (roll 3-4) can unlock 1-2 AP from the block
  - At end of round: Blocks `(apBlock - childUnlock[color])` AP, then resets `childUnlock` to 0

### Marriage System
- **Marriage Event**: Triggers `AD_MARRIAGE` card effect
- **Married State**: Tracks which players are married (`married[color] = true`)
- **Date Bonus**: Married players get +4 SAT from date cards (vs. +2 for unmarried)
- **Multi-Player Effect**: When a player marries, all other players get +2 SAT, 2 AP moved to INACTIVE (1 turn), and must pay 200 (if they can afford it) to the marrying player

### Status Token System
- **Integration**: Uses PlayerStatusController as bridge to TokenEngine
- **Status Tags**: `WLB_STATUS_GOOD_KARMA`, `WLB_STATUS_DATING`, `WLB_STATUS_SICK`, etc.
- **Auto-Application**: Cards with `statusAddTag` automatically add status tokens via `PS_AddStatus()`

### Dice System
- **Physical Die**: Uses real die object (GUID: `14d4a4`)
- **Roll Process**: 
  1. Moves die near card
  2. Randomizes die
  3. Polls die value until stable (4 consecutive reads)
  4. Returns die to home position
- **Timeout**: 2.2 seconds max, fallback to random if timeout
- **Dice Tables**: Different tables for different card types (HANGOVER, BEAUTY_D6, AD_SPORT_D6, AD_AUNTY_D6, AD_CHILD_D6)

### Choice System
- **A/B Choices**: Cards can present two options (e.g., PAY vs. SAT for loans)
- **Babysitter Choice**: Unlock 1 AP (cost per unlock) vs. Unlock 2 AP (cost × 2)
- **VE Cards**: Choice between two volunteer experience paths (TODO: not fully implemented)

## 🔗 External API

### Public Functions (for Event Controller)
- `playCardFromUI(args)`: Main entry point for playing a card
  - Parameters: `{card_guid, player_color, slot_idx}`
  - Returns: `"DONE"`, `"WAIT_CHOICE"`, `"WAIT_DICE"`, `"BLOCKED"`, `"IGNORED"`, or `"ERROR"`
- `isObligatoryCard(args)`: Checks if a card is obligatory
  - Parameters: `{card_guid}` or `{cardGuid}`
  - Returns: `true` if card is obligatory, `false` otherwise

### Internal Functions
- `applyEndOfRoundForColor(args)`: Applies end-of-round effects for child system
  - Parameters: `{player_color}` or `{color}`
  - Returns: `true` if successful, `false` otherwise
- `evt_roll(cardObj, player_color, alt_click)`: Handles dice roll button click
- `evt_choiceA(cardObj, player_color, alt_click)`: Handles choice A button click
- `evt_choiceB(cardObj, player_color, alt_click)`: Handles choice B button click
- `evt_cancelPending(cardObj, player_color, alt_click)`: Cancels pending dice/choice

### Fallback Functions (for manual player color setting)
- `setActiveYellow()`, `setActiveBlue()`, `setActiveRed()`, `setActiveGreen()`

## ⚙️ Configuration

### GUIDs
- `REAL_DICE_GUID`: `"14d4a4"` (Physical die for dice rolls)
- `SAT_TOKEN_GUIDS`: 
  - Yellow: `"d33a15"`
  - Red: `"6fe69b"`
  - Blue: `"b2b5e3"`
  - Green: `"e8834c"`

### Tags
- `WLB_STATS_CTRL`: Stats Controller tag
- `WLB_AP_CTRL`: AP Controller tag
- `WLB_MONEY`: Money Controller tag
- `WLB_COLOR_*`: Color tags (`WLB_COLOR_Yellow`, `WLB_COLOR_Red`, etc.)
- `WLB_PLAYER_STATUS_CTRL`: PlayerStatusController hub tag
- `WLB_KEEP_ZONE`: Keep zone tag (where keep cards go)
- `WLB_EVENT_DISCARD_ZONE`: Legacy discard zone tag
- `WLB_EVT_USED_ZONE`: New used zone tag

### Constants
- `DICE_ROLL_TIMEOUT`: `2.2` seconds
- `DICE_STABLE_READS`: `4` (consecutive reads required for stability)
- `DICE_POLL`: `0.12` seconds (polling interval)
- `DEBOUNCE_SEC`: `2.0` seconds (debounce time between card plays)
- `LOCK_SEC`: `8.0` seconds (lock duration after card action)

## ⚠️ Notes

### Version 1.7.2 Changes
1. **Adult KARMA Fix**: Now works exactly like Youth KARMA - instant discard (NOT keep), adds GOOD_KARMA status token
2. **Child AP Unlock**: New per-round unlock system allows partial unlocking of child AP block via Babysitter/Aunty
3. **Babysitter/Aunty**: Now interact with child unlock system to reduce AP blocking

### State Management
- **No Persistence**: State is NOT saved (married, child, childUnlock reset on game reload)
- **Active Color**: Uses `Turns.turn_color` if available, otherwise falls back to `activeColor` variable
- **Card Locking**: Uses `lockUntil[guid]` table to prevent duplicate plays
- **Debouncing**: Uses `recentlyPlayed[guid]` table to prevent rapid re-plays

### TODO / Not Implemented
- **Luxury Tax / Property Tax**: Cards exist but effects not fully implemented
- **Hi-Tech Failure**: Card exists but repair system not implemented
- **Work Bonus**: Card exists but profession system not implemented
- **Auction System**: Card exists but auction mechanics not implemented
- **Property Vouchers**: Card exists but property purchase system not implemented
- **Volunteer Experience Cards**: Choice system exists but effects not fully implemented

### Integration Notes
- **Event Controller**: This engine is called by Event Controller's UI buttons
- **Turn System**: Relies on `Turns.turn_color` for active player detection
- **Token Engine**: Status tokens added via PlayerStatusController → TokenEngine pipeline
- **AP Controller**: Requires `canSpendAP()` and `spendAP()` methods, also uses `moveAP()` for effects

### Card UI
- Buttons are created dynamically on cards for dice rolls and choices
- Buttons are cleared after action completes
- Cards are locked during processing to prevent interference
