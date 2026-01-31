# Object #25: SCANNER Shop Cards

## 📋 Overview
The `SCANNER Shop Cards` script (`ScannerShopCards.lua`) is a utility tool designed to manage the three types of shop cards in the game: **Consumables (C)**, **Hi-Tech (H)**, and **Investments (I)**. Its primary functions include scanning for all shop cards (both loose and within decks), retagging them for consistent identification, exporting their names and details, and validating their sequential numbering. This tool is crucial for ensuring the integrity and proper setup of the shop card decks.

## 🚀 Functionality
The scanner provides a UI with four buttons, each triggering a specific function:

### 1. **SCAN SHOP**
- Scans all objects on the table, including loose cards and cards inside decks
- Identifies cards whose names match the shop card prefixes:
  - `CSHOP_XX_` for Consumables (e.g., `CSHOP_01_ItemName`)
  - `HSHOP_XX_` for Hi-Tech (e.g., `HSHOP_01_ItemName`)
  - `ISHOP_XX_` for Investments (e.g., `ISHOP_01_ItemName`)
- Populates an internal cache with:
  - Unique shop card names per category
  - Loose cards with their GUIDs and tags
  - Decks containing shop cards (identified by card nicknames)
- Reports counts:
  - Unique names per category
  - Loose card counts per category
  - Deck-contained card names per category
- Warns if counts do not match expected values:
  - Consumables: 28 cards
  - Hi-Tech: 14 cards
  - Investments: 14 cards

### 2. **RETAG SHOP**
- First performs a `SCAN SHOP` to refresh the card cache
- Adds tags to all identified loose shop cards:
  - `WLB_SHOP_CARD` (all shop cards)
  - `WLB_SHOP_CARD_C` (Consumables only)
  - `WLB_SHOP_CARD_H` (Hi-Tech only)
  - `WLB_SHOP_CARD_I` (Investments only)
- Adds tags to all identified decks containing shop cards:
  - `WLB_SHOP_DECK` (all shop decks)
  - `WLB_SHOP_DECK_C` (Consumables decks only)
  - `WLB_SHOP_DECK_H` (Hi-Tech decks only)
  - `WLB_SHOP_DECK_I` (Investments decks only)
- Broadcasts the number of retagged loose cards and decks per category
- **Note**: Cards inside decks cannot be directly tagged until they are taken out (TTS limitation)

### 3. **EXPORT (PASTE)**
- First performs a `SCAN SHOP`
- Generates a comprehensive export report including:
  - Summary of unique names per category
  - **LOOSE cards**: For each category, lists all loose cards with:
    - GUID
    - Card name
    - Current tags
    - Sorted alphabetically by name
  - **DECKS**: For each category, lists all decks containing shop cards with:
    - Deck GUID
    - Deck name
    - Count of shop cards in deck
    - Sample card names (up to 8)
  - **UNIQUE NAMES**: Complete sorted list of all unique card names per category, numbered sequentially
- Prints the export to the Console log for easy copying
- Format is designed for copy-paste into documentation or configuration files

### 4. **CHECK SEQ**
- First performs a `SCAN SHOP`
- Validates the sequential numbering of shop cards for each category:
  - Consumables: `CSHOP_01` to `CSHOP_28`
  - Hi-Tech: `HSHOP_01` to `HSHOP_14`
  - Investments: `ISHOP_01` to `ISHOP_14`
- Identifies and reports:
  - **BAD NAMES**: Cards that do not match the expected naming pattern (e.g., `CSHOP_XX_*`)
  - **MISSING NUMBERS**: Gaps in the sequential numbering (e.g., missing `CSHOP_05`)
  - **DUPLICATE NUMBERS**: Numbers that appear more than once (e.g., two cards with `CSHOP_03`)
- Prints detailed lists of issues to the Console and broadcasts summaries
- Broadcasts OK status for categories with no issues

## 🔗 External API
- None explicitly exposed for other scripts to call, primarily a utility tool

## ⚙️ Configuration
- **Card Name Patterns**:
  - `CFG.C_PREFIX`: `"^CSHOP_%d%d_"` (Lua pattern for Consumables)
  - `CFG.H_PREFIX`: `"^HSHOP_%d%d_"` (Lua pattern for Hi-Tech)
  - `CFG.I_PREFIX`: `"^ISHOP_%d%d_"` (Lua pattern for Investments)
- **Expected Counts**:
  - `CFG.EXPECT_C`: `28` (Consumables)
  - `CFG.EXPECT_H`: `14` (Hi-Tech)
  - `CFG.EXPECT_I`: `14` (Investments)
- **Tags**:
  - `CFG.TAG_CARD_ALL`: `"WLB_SHOP_CARD"` (Tag for all shop cards)
  - `CFG.TAG_CARD_C/H/I`: Category-specific card tags
  - `CFG.TAG_DECK_ALL`: `"WLB_SHOP_DECK"` (Tag for all shop decks)
  - `CFG.TAG_DECK_C/H/I`: Category-specific deck tags
- `CFG.BROADCAST_COLOR`: `{1, 1, 1}` (White color for broadcast messages)

## 🎮 UI Elements
The tool provides four buttons arranged vertically:
1. **SCAN SHOP**: Scans and reports shop card inventory
2. **RETAG SHOP**: Retags loose cards and decks
3. **EXPORT (PASTE)**: Generates comprehensive export report
4. **CHECK SEQ**: Validates sequential numbering

## 📊 Export Format Example

```
=== WLB SHOP SCAN EXPORT (PASTE TO CHAT) ===
UNIQUE NAMES: C=28 H=14 I=14

## CONSUMABLES (C)
-- LOOSE: GUID | NAME | TAGS
abc123 | CSHOP_01_Bread | WLB_SHOP_CARD,WLB_SHOP_CARD_C
def456 | CSHOP_02_Milk | WLB_SHOP_CARD,WLB_SHOP_CARD_C
...

-- DECKS: DECK_GUID | DECK_NAME | COUNT | SAMPLE_NAMES
xyz789 | Consumables Deck | 28 | CSHOP_01_Bread ; CSHOP_02_Milk ; ...

-- UNIQUE NAMES (sorted)
001) CSHOP_01_Bread
002) CSHOP_02_Milk
...
```

## 🔄 Usage Workflow

### Initial Setup / Validation
1. Click **SCAN SHOP** to get an inventory
2. Review counts and warnings
3. Click **CHECK SEQ** to validate numbering
4. Fix any missing or duplicate cards
5. Click **RETAG SHOP** to ensure all cards are properly tagged

### Exporting Card List
1. Click **SCAN SHOP** (refresh cache)
2. Click **EXPORT (PASTE)**
3. Check Console for the full export
4. Copy and paste into documentation or configuration

## 🔗 Integration with Other Systems

### Shop Engine
- Uses tagged shop cards (`WLB_SHOP_CARD_C/H/I`) to identify and manage shop inventory
- Uses tagged decks (`WLB_SHOP_DECK_C/H/I`) to locate shop decks

## ⚠️ Notes
- The script uses an internal `cache` to store scanned card and deck information
- `broadcast` helper function handles messages to specific players or all players
- The `scanAll` function intelligently identifies decks containing shop cards by inspecting their contents (via `deck.getObjects()` and card nicknames)
- The `CHECK SEQ` function is vital for game setup validation, ensuring all cards are present and uniquely numbered
- Cards inside decks are identified by their `nickname` property (not `name`), which is why the scan uses `entry.nickname` when examining deck contents
- Tagging of cards inside decks is not possible until they are removed from the deck (Tabletop Simulator limitation)
- The export format is designed for easy copy-pasting into documentation or configuration files
