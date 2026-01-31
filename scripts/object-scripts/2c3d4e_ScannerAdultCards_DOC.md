# SCANNER Adult Cards - Documentation

**GUID:** `2c3d4e`  
**Tags:** (no tags)  
**Type:** Tile  
**Version:** 1.0

---

## Overview

The SCANNER Adult Cards is a deck management tool for the Adult deck. It scans all Adult cards (both loose and inside decks), retags them, exports card names, and validates sequential numbering. This is a utility tool for game setup and maintenance.

---

## Functionality

### Main Purpose
- **Card Scanning**: Finds all Adult cards (name pattern: `AD_XX_*`) on the table
- **Tagging**: Automatically tags Adult cards and decks with proper tags
- **Name Export**: Exports all card names to console for easy copying
- **Validation**: Checks that cards are numbered sequentially (AD_01 through AD_81)

### Key Features
- Scans both loose cards and cards inside decks
- Pattern matching: `AD_XX_` prefix (where XX is 01-81)
- De-duplicates card names
- Validates sequential numbering
- Exports sorted list of names

---

## Game Integration

### Related Objects
- **Adult Deck Cards** - Cards with names matching `AD_XX_*` pattern
- **Adult Decks** - Decks containing Adult cards

### Card Naming Pattern
- **Format**: `AD_XX_NAME` where:
  - `AD_` = Adult deck prefix
  - `XX` = Two-digit number (01-81)
  - `NAME` = Card name/description
- **Example**: `AD_05_DATE`, `AD_42_WORK`, etc.

---

## UI Elements

The scanner has 4 buttons (arranged vertically):

### 1. SCAN ADULT (Top Button)
- **Function**: Scans all Adult cards on table
- **Output**: 
  - Counts unique Adult card names found
  - Compares to expected count (81)
  - Shows warning if count doesn't match

### 2. RETAG ADULT (Second Button)
- **Function**: Tags all found Adult cards and decks
- **Tags Applied**:
  - Loose cards: `WLB_EVT_ADULT_CARD`
  - Decks: `WLB_DECK_ADULT`
- **Note**: Cards inside decks can't be tagged until taken out

### 3. EXPORT NAMES (Third Button)
- **Function**: Exports all card names to console
- **Output**: 
  - Sorted list of all Adult card names
  - Numbered format: `001) AD_01_NAME`
  - Total count
  - Easy to copy from console

### 4. CHECK SEQ (Bottom Button)
- **Function**: Validates sequential numbering
- **Checks**:
  - All cards match `AD_XX_` pattern
  - Numbers are sequential (01-81)
  - No missing numbers
  - No duplicate numbers
- **Output**: 
  - Lists bad names (don't match pattern)
  - Lists missing numbers
  - Lists duplicate numbers
  - Shows total unique names

---

## How It Works

### Scanning Process
1. **Reset Cache**: Clears previous scan results
2. **Scan Loose Objects**: 
   - Checks all objects on table
   - If Card: Checks if name matches `AD_XX_` pattern
   - If Deck: Inspects contained objects (by nickname) to find Adult cards
3. **Build Name List**: 
   - Collects all Adult card names
   - De-duplicates (removes duplicates)
   - Stores in cache

### Tagging Process
1. **Tag Loose Cards**: 
   - Finds all loose Adult cards (by GUID)
   - Adds tag `WLB_EVT_ADULT_CARD`
2. **Tag Decks**: 
   - Finds all decks containing Adult cards
   - Adds tag `WLB_DECK_ADULT`
3. **Limitation**: Cards inside decks can't be tagged until they're taken out (they don't exist as separate objects)

### Validation Process
1. **Extract Numbers**: Parses `AD_XX_` pattern to get number
2. **Build Number Map**: Counts occurrences of each number
3. **Check Completeness**: 
   - Finds missing numbers (01-81)
   - Finds duplicate numbers
   - Finds bad names (don't match pattern)

---

## Technical Details

### Pattern Matching
- **Pattern**: `^AD_%d%d_` (Lua pattern)
- **Matches**: Names starting with `AD_` followed by 2 digits and underscore
- **Examples**:
  - ✅ `AD_01_DATE` - Matches
  - ✅ `AD_42_WORK` - Matches
  - ❌ `YD_01_DATE` - Doesn't match (Youth deck)
  - ❌ `AD_1_DATE` - Doesn't match (single digit)

### Card Detection
- **Loose Cards**: Checks `obj.tag == "Card"` and `obj.getName()`
- **Deck Cards**: Checks `obj.tag == "Deck"` and `obj.getObjects()` (by nickname)
- **Note**: Cards inside decks don't have GUIDs until taken out

### Expected Count
- **Default**: 81 Adult cards (AD_01 through AD_81)
- **Configurable**: Set via `CFG.EXPECTED_AD_COUNT`

### Cache System
- **cards**: Maps GUID → `{name, src}` (loose cards only)
- **decks**: Maps GUID → deck object
- **names**: Array of all card names (deduplicated)

---

## Usage Examples

### Scan Adult Cards
1. Click "SCAN ADULT"
2. Output: "SCAN ADULT: found 81 unique AD_ card names (decks + loose)."

### Retag All Adult Cards
1. Click "RETAG ADULT"
2. Output: "RETAG ADULT: tagged 5 loose cards with WLB_EVT_ADULT_CARD and 2 decks with WLB_DECK_ADULT."

### Export Names
1. Click "EXPORT NAMES"
2. Console shows:
   ```
   === ADULT CARD NAMES (sorted) ===
   001) AD_01_DATE
   002) AD_02_WORK
   ...
   081) AD_81_RETIREMENT
   TOTAL: 81
   ```

### Check Sequential Numbering
1. Click "CHECK SEQ"
2. Output shows:
   - Missing numbers (if any)
   - Duplicate numbers (if any)
   - Bad names (if any)
   - Total unique names

---

## Integration with Other Systems

### Event Engine
- Uses `WLB_EVT_ADULT_CARD` tag to identify Adult cards
- Uses `WLB_DECK_ADULT` tag to find Adult deck

### Diagnostic Controller
- Can verify Adult deck count matches expected (81)

---

## Notes

- Cards inside decks are detected by nickname, not GUID
- Cards inside decks can't be tagged until taken out
- Name export is sorted alphabetically
- Validation checks for sequential numbering 01-81
- Tool is for setup/maintenance, not gameplay

---

## Status

✅ **Documented** - Script analyzed and documented  
✅ **Utility Tool** - Used for deck setup and validation
