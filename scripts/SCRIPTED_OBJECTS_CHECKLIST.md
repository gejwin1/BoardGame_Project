# Scripted Objects Documentation Checklist

**Total Scripted Objects: 42** (Updated from 44)

This checklist tracks documentation progress for each scripted object in the game.

---

## Object #1 ✅
**Name:** (unnamed) - Year Token  
**GUID:** `465776`  
**Type:** Tile  
**Tags:** WLB_LAYOUT, WLB_YEAR  
**Status:** ✅ Documented  
**Script:** ✅ Saved to `scripts/object-scripts/465776_YearToken.lua`  
**Documentation:** `scripts/object-scripts/465776_YearToken_DOC.md`  
**Summary:** Round tracker token that moves across Calendar Board. Tracks rounds 1-13, supports Youth/Adult age resets, color tinting, and provides external API for other scripts.

---

## Object #2 ✅
**Name:** COSTS CALCULATOR  
**GUID:** `bccb71`  
**Type:** Tile  
**Tags:** WLB_COSTS_CALC  
**Status:** ✅ Documented  
**Script:** ✅ Saved to `scripts/object-scripts/bccb71_CostsCalculator.lua`  
**Documentation:** `scripts/object-scripts/bccb71_CostsCalculator_DOC.md`  
**Summary:** Tracks monthly/recurring costs per player. Shows remaining costs for active player with color-coded UI. PAY button deducts costs from money tiles. External API for other scripts to add/set/get costs.

---

## Object #3 ✅
**Name:** DIAGNOSTICS  
**GUID:** `86804e`  
**Type:** Tile  
**Tags:** WLB_DIAGNOSTIC_CTRL  
**Status:** ✅ Documented  
**Script:** ✅ Saved to `scripts/object-scripts/86804e_DiagnosticController.lua`  
**Documentation:** `scripts/object-scripts/86804e_DiagnosticController_DOC.md`  
**Summary:** Comprehensive diagnostic and inventory tool. Scans game table, validates setup, tracks all objects. 4 buttons: RUN CHECK, PLAYER REG, FULL INVENTORY, SCRIPTED ONLY. Provides external API for other controllers.

---

## Object #4 ✅
**Name:** Estate Engine  
**GUID:** `fd8ce0`  
**Type:** Tile  
**Tags:** WLB_MARKET_CTRL  
**Status:** ✅ Documented  
**Script:** ✅ Received (very long script)  
**Documentation:** `scripts/object-scripts/fd8ce0_EstateEngine_DOC.md`  
**Summary:** Manages apartment/estate system with 4 levels (L1-L4). Players can rent/buy estates, place them on boards, return/sell them. Uses AP system (1 AP per action). Has deck UI, card buttons, parking system.

---

## Object #5 ✅
**Name:** MONEY B (Money Blue)  
**GUID:** `b39f0e`  
**Type:** Tile  
**Tags:** WLB_RESETTABLE, WLB_MONEY, WLB_COLOR_Blue, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script - All 4 Money tokens identical  
**Documentation:** `scripts/object-scripts/MoneyController_Shared_DOC.md`  
**Summary:** Money tracking and display for Blue player. Shows "MONEY = X". API: getMoney, setMoney, addMoney, resetNewGame, API_spend. Starts at 200. Persists across saves.

---

## Object #6 ✅
**Name:** MONEY G (Money Green)  
**GUID:** `a373e9`  
**Type:** Tile  
**Tags:** WLB_RESETTABLE, WLB_MONEY, WLB_COLOR_Green, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/MoneyController_Shared_DOC.md`  
**Summary:** Money tracking and display for Green player. Same as MONEY B.

---

## Object #7 ✅
**Name:** MONEY R (Money Red)  
**GUID:** `95ea35` ⚠️ **UPDATED GUID** (was e2d3e1)  
**Type:** Tile  
**Tags:** WLB_RESETTABLE, WLB_MONEY, WLB_COLOR_Red, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/MoneyController_Shared_DOC.md`  
**Summary:** Money tracking and display for Red player. Same as MONEY B.

---

## Object #8 ✅
**Name:** MONEY Y (Money Yellow)  
**GUID:** `99d96c`  
**Type:** Tile  
**Tags:** WLB_RESETTABLE, WLB_MONEY, WLB_COLOR_Yellow, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/MoneyController_Shared_DOC.md`  
**Summary:** Money tracking and display for Yellow player. Same as MONEY B.

---

## Object #9 ✅
**Name:** PB AP CTRL B (Player Board Action Points Controller Blue)  
**GUID:** `c8def5`  
**Type:** Tile  
**Tags:** WLB_AP_CTRL, WLB_COLOR_Blue, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script - All 4 AP Controllers identical  
**Documentation:** `scripts/object-scripts/APController_Shared_DOC.md`  
**Summary:** Manages 12 AP tokens for Blue player. Tracks AP placement in 5 areas (Work, Rest, Events, School, Inactive). API: canSpendAP, spendAP, moveAP, getCount, WLB_AP_START_TURN.

---

## Object #10 ✅
**Name:** PB AP CTRL G (Player Board Action Points Controller Green)  
**GUID:** `1063c2`  
**Type:** Tile  
**Tags:** WLB_AP_CTRL, WLB_COLOR_Green, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/APController_Shared_DOC.md`  
**Summary:** Manages 12 AP tokens for Green player. Same as PB AP CTRL B.

---

## Object #11 ✅
**Name:** PB AP CTRL R (Player Board Action Points Controller Red)  
**GUID:** `b2cbfa`  
**Type:** Tile  
**Tags:** WLB_AP_CTRL, WLB_COLOR_Red, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/APController_Shared_DOC.md`  
**Summary:** Manages 12 AP tokens for Red player. Same as PB AP CTRL B.

---

## Object #12 ✅
**Name:** PB AP CTRL Y (Player Board Action Points Controller Yellow)  
**GUID:** `83e61a`  
**Type:** Tile  
**Tags:** WLB_COLOR_Yellow, WLB_AP_CTRL, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Shared script  
**Documentation:** `scripts/object-scripts/APController_Shared_DOC.md`  
**Summary:** Manages 12 AP tokens for Yellow player. Same as PB AP CTRL B.

---

## Object #13 ✅
**Name:** PB STATS CTRL B (Player Board Stats Controller Blue)  
**GUID:** `810632`  
**Type:** Tile  
**Tags:** WLB_STATS_CTRL, WLB_COLOR_Blue, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Received and verified - Color-agnostic script (all 4 identical)  
**Documentation:** `scripts/object-scripts/StatsController_Shared_DOC.md`  
**Summary:** Manages 3 stats for Blue player: Health (0-9, starts 9), Knowledge (0-15), Skills (0-15). Moves stat tokens to calibrated positions. API: getHealth, getState, applyDelta, adultStart_apply, resetNewGame. Tag-driven, calibration-based positioning. Version 2.1.

---

## Object #14 ✅
**Name:** PB STATS CTRL G (Player Board Stats Controller Green)  
**GUID:** `e16455`  
**Type:** Tile  
**Tags:** WLB_STATS_CTRL, WLB_COLOR_Green, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as PB STATS CTRL B (all 4 are identical)  
**Documentation:** `scripts/object-scripts/StatsController_Shared_DOC.md`  
**Summary:** Manages 3 stats for Green player. Same as PB STATS CTRL B.

---

## Object #15 ✅
**Name:** PB STATS CTRL R (Player Board Stats Controller Red)  
**GUID:** `3cefbd` ⚠️ **UPDATED GUID** (was 8c3b9e)  
**Type:** Tile  
**Tags:** WLB_STATS_CTRL, WLB_COLOR_Red, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as PB STATS CTRL B/G (all 4 are identical)  
**Documentation:** `scripts/object-scripts/StatsController_Shared_DOC.md`  
**Summary:** Manages 3 stats for Red player. Same as PB STATS CTRL B.

---

## Object #16 ✅
**Name:** PB STATS CTRL Y (Player Board Stats Controller Yellow)  
**GUID:** `9c7a4a`  
**Type:** Tile  
**Tags:** WLB_STATS_CTRL, WLB_COLOR_Yellow, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as PB STATS CTRL B/G/R (all 4 are identical)  
**Documentation:** `scripts/object-scripts/StatsController_Shared_DOC.md`  
**Summary:** Manages 3 stats for Yellow player. Same as PB STATS CTRL B.  

---

## Object #17 ✅
**Name:** REST Button B (Rest Button Blue)  
**GUID:** `79d9c9`  
**Type:** Tile  
**Tags:** WLB_COLOR_Blue  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Received and verified - Color-agnostic script (all 4 identical)  
**Documentation:** `scripts/object-scripts/RestButton_Shared_DOC.md`  
**Summary:** Simple REST controller for Blue player. Two buttons: REST + (move AP to REST) and REST - (remove AP from REST). Shows health forecast after each action. Integrates with AP Controller and Stats Controller. Version 1.1.0.

---

## Object #18 ✅
**Name:** REST Button G (Rest Button Green)  
**GUID:** `48686a`  
**Type:** Tile  
**Tags:** WLB_COLOR_Green  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as REST Button B (all 4 are identical)  
**Documentation:** `scripts/object-scripts/RestButton_Shared_DOC.md`  
**Summary:** Simple REST controller for Green player. Same as REST Button B.

---

## Object #19 ✅
**Name:** REST Button R (Rest Button Red)  
**GUID:** `3a4e5f`  
**Type:** Tile  
**Tags:** WLB_COLOR_Red  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as REST Button B/G (all 4 are identical)  
**Documentation:** `scripts/object-scripts/RestButton_Shared_DOC.md`  
**Summary:** Simple REST controller for Red player. Same as REST Button B.

---

## Object #20 ✅
**Name:** REST Button Y (Rest Button Yellow)  
**GUID:** `7f8a9b`  
**Type:** Tile  
**Tags:** WLB_COLOR_Yellow  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as REST Button B/G/R (all 4 are identical)  
**Documentation:** `scripts/object-scripts/RestButton_Shared_DOC.md`  
**Summary:** Simple REST controller for Yellow player. Same as REST Button B.  

---

## Object #21 ✅
**Name:** SCANNER Adult Cards  
**GUID:** `2c3d4e`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/2c3d4e_ScannerAdultCards.lua`  
**Documentation:** `scripts/object-scripts/2c3d4e_ScannerAdultCards_DOC.md`  
**Summary:** Deck management tool for Adult cards. 4 buttons: SCAN ADULT (finds all AD_XX_ cards), RETAG ADULT (tags cards/decks), EXPORT NAMES (exports to console), CHECK SEQ (validates sequential numbering AD_01..AD_81). Scans both loose cards and cards inside decks. Utility tool for setup/maintenance.  

---

## Object #22 ✅
**Name:** SCANNER Estates (Estate Slot Locator)  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/ScannerEstates_EstateSlotLocator.lua`  
**Documentation:** `scripts/object-scripts/ScannerEstates_EstateSlotLocator_DOC.md`  
**Summary:** Calibration tool for finding estate slot positions on player boards. Measures local coordinates relative to boards. AUTO mode finds nearest board, or force specific color. PRINT outputs ready-to-paste code for Estate Engine's ESTATE_SLOT_LOCAL table. Version 3.0. Development/calibration utility.  

---

## Object #23 ✅
**Name:** SCANNER Event Track (Event Track Locator)  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/ScannerEventTrack.lua`  
**Documentation:** `scripts/object-scripts/ScannerEventTrack_DOC.md`  
**Summary:** Calibration tool for finding event track positions on Event Board. Measures local coordinates for deck, used pile, and 7 event card slots (S1-S7). Select target position, place tile on location, then PRINT outputs ready-to-paste code for Event Engine's position tables. Version 1.0. Development/calibration utility.  

---

## Object #24 ✅
**Name:** SCANNER PersoBoard + Apart (Family Slot Locator)  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/ScannerPersoBoardApart.lua`  
**Documentation:** `scripts/object-scripts/ScannerPersoBoardApart_DOC.md`  
**Summary:** Advanced calibration tool for measuring family member slot positions. Two modes: BOARD (L0 slots on player boards, per color) and CARD (L1-L4 slots on estate cards, per level). Uses probe token with raycasting to detect positions. Supports multiple slots per level (1-30). Exports complete Lua table structures (FAMILY_SLOTS_BOARD and FAMILY_SLOTS_CARD) ready for game engine integration. Version 1.1.0. Development/calibration utility.  

---

## Object #25 ✅
**Name:** SCANNER Shop Cards  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/ScannerShopCards.lua`  
**Documentation:** `scripts/object-scripts/ScannerShopCards_DOC.md`  
**Summary:** Utility tool for managing shop cards (Consumables C=28, Hi-Tech H=14, Investments I=14). Scans loose cards and decks, retags with WLB_SHOP_CARD_* tags, exports comprehensive reports, and validates sequential numbering (CSHOP_01-28, HSHOP_01-14, ISHOP_01-14). Detects cards in decks via nicknames. Version 1.0.1. Development/setup utility.  

---

## Object #26 ✅
**Name:** SCANNER Shop Positions (Shop Slot Locator)  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/ScannerShopPositions.lua`  
**Documentation:** `scripts/object-scripts/ScannerShopPositions_DOC.md`  
**Summary:** Calibration tool for finding shop slot positions on Shops Board. Measures local coordinates for 3 rows (Consumables C, Hi-Tech H, Investments I) and 4 slots per row (Closed C, Open1, Open2, Open3). Select row/slot, place token on position, then PRINT outputs ready-to-paste code for Shop Engine's position tables. Version 1.0. Development/calibration utility.  

---

## Object #27 ✅
**Name:** SHOP ENGINE  
**GUID:** `d59e04`  
**Type:** Tile  
**Tags:** WLB_SHOP_ENGINE  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/d59e04_ShopEngine.lua`  
**Documentation:** `scripts/object-scripts/d59e04_ShopEngine_DOC.md`  
**Summary:** Comprehensive shop management system for three shop types (Consumables C=28, Hi-Tech H=14, Investments I=14). Handles card placement, purchasing with modal YES/NO UI, card effects (cure, karma, books, etc.), deck management, and shop pipelines (RESET, REFILL, RANDOMIZE). Integrates with Money, AP, Stats, and Player Status controllers. Cards returned to deck on purchase (not destroyed). Entry AP cost (1 AP per turn). Version 1.3.4.  

---

## Object #28 ✅
**Name:** STATUS CONTROLLER (Player Status Controller)  
**GUID:** `[Need to verify - check your list]`  
**Type:** Tile  
**Tags:** WLB_PLAYER_STATUS_CTRL  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/PlayerStatusController.lua`  
**Documentation:** `scripts/object-scripts/PlayerStatusController_DOC.md`  
**Summary:** Middleware/bridge controller that forwards status commands from Event Engine to Token Engine. Provides unified PS_Event() API for managing player status tokens (SICK, WOUNDED, ADDICTION, etc.), marriage tokens, and child tokens. Maps symbolic keys to status tags, forwards via safeCall() to Token Engine's *_ARGS wrappers. Supports ADD_STATUS, REMOVE_STATUS, CLEAR_STATUSES, REFRESH_STATUSES, ADD_MARRIAGE, ADD_CHILD operations. Version 0.3.0.  

---

## Object #29 ✅
**Name:** TOKEN ENGINE  
**GUID:** `61766c`  
**Type:** Tile  
**Tags:** WLB_TOKEN_SYSTEM, WLB_TOKEN_ENGINE  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/61766c_TokenEngine.lua`  
**Documentation:** `scripts/object-scripts/61766c_TokenEngine_DOC.md`  
**Summary:** Comprehensive token management system for status tokens (6 types), family tokens (marriage, children), and housing placement (L0-L4). Manages token pool (PRIME/COLLECT), places tokens on player boards and estate cards, provides auto-target color resolution (explicit -> clicking player -> active turn -> fallback). Exposes *_ARGS wrappers for Player Status Controller integration. Supports safe park system, recycle lane, and sequential token placement. Version 2.4.0. Core dependency for many game systems.  

---

## Object #30 ✅
**Name:** Token Pers K B (Token Personal Knowledge Blue)  
**GUID:** `d8fab6`  
**Type:** Tile  
**Tags:** WLB_KNOWLEDGE_TOKEN, WLB_COLOR_Blue, WLB_LAYOUT  
**Status:** ✅ No script needed (moved by Stats Controller)  
**Script:** ✅ Verified - No script attached (tokens are moved by Stats Controller script)  

---

## Object #31 ✅
**Name:** Token Pers K G (Token Personal Knowledge Green)  
**GUID:** `bfde8a`  
**Type:** Tile  
**Tags:** WLB_KNOWLEDGE_TOKEN, WLB_COLOR_Green, WLB_LAYOUT  
**Status:** ✅ No script needed (moved by Stats Controller)  
**Script:** ✅ Verified - No script attached (tokens are moved by Stats Controller script)  

---

## Object #32 ✅
**Name:** Token Pers K R (Token Personal Knowledge Red)  
**GUID:** `b179ce`  
**Type:** Tile  
**Tags:** WLB_KNOWLEDGE_TOKEN, WLB_COLOR_Red, WLB_LAYOUT  
**Status:** ✅ No script needed (moved by Stats Controller)  
**Script:** ✅ Verified - No script attached (tokens are moved by Stats Controller script)  

---

## Object #33 ✅
**Name:** Token Pers K Y (Token Personal Knowledge Yellow)  
**GUID:** `c62746`  
**Type:** Tile  
**Tags:** WLB_KNOWLEDGE_TOKEN, WLB_COLOR_Yellow, WLB_LAYOUT  
**Status:** ✅ No script needed (moved by Stats Controller)  
**Script:** ✅ Verified - No script attached (tokens are moved by Stats Controller script)  

---

## Object #34 ✅
**Name:** Token Sat Blue (Token Satisfaction Blue)  
**GUID:** `b2b5e3`  
**Type:** Tile  
**Tags:** SAT_TOKEN, WLB_COLOR_Blue, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as all SAT tokens (all 4 are identical)  
**Documentation:** `scripts/object-scripts/SatisfactionToken_Shared_DOC.md`  
**Summary:** Satisfaction token for Blue player. Tracks satisfaction (0-100), moves on Satisfaction Board using anchor-based positioning. Staggered movement prevents collisions. Provides addSat, getSatValue, setSatValue, resetToStart APIs. Version 2.4.  

---

## Object #35 ✅
**Name:** Token Sat Green (Token Satisfaction Green)  
**GUID:** `e8834c`  
**Type:** Tile  
**Tags:** SAT_TOKEN, WLB_COLOR_Green, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as all SAT tokens (all 4 are identical)  
**Documentation:** `scripts/object-scripts/SatisfactionToken_Shared_DOC.md`  
**Summary:** Satisfaction token for Green player. Same as SAT token B/G/R.  

---

## Object #36 ✅
**Name:** Token Sat Red (Token Satisfaction Red)  
**GUID:** `6fe69b`  
**Type:** Tile  
**Tags:** SAT_TOKEN, WLB_COLOR_Red, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as all SAT tokens (all 4 are identical)  
**Documentation:** `scripts/object-scripts/SatisfactionToken_Shared_DOC.md`  
**Summary:** Satisfaction token for Red player. Same as SAT token B/G/Y.  

---

## Object #37 ✅
**Name:** Token Sat Yellow (Token Satisfaction Yellow)  
**GUID:** `d33a15`  
**Type:** Tile  
**Tags:** SAT_TOKEN, WLB_COLOR_Yellow, WLB_LAYOUT  
**Status:** ✅ Documented (Shared Script)  
**Script:** ✅ Verified - Same script as all SAT tokens (all 4 are identical)  
**Documentation:** `scripts/object-scripts/SatisfactionToken_Shared_DOC.md`  
**Summary:** Satisfaction token for Yellow player. Same as SAT token B/G/R.  

---

## Object #38 ✅ (DEPRECATED)
**Name:** WLB Control  
**GUID:** `1b53e4`  
**Type:** Tile  
**Tags:** (no tags)  
**Status:** ✅ Documented (DEPRECATED - No longer used, will be deleted)  
**Script:** ✅ Received and saved to `scripts/object-scripts/1b53e4_WLBControl.lua`  
**Documentation:** `scripts/object-scripts/1b53e4_WLBControl_DOC.md`  
**Summary:** Legacy control panel for game setup/reset. Provided layout capture/restore, satisfaction token collection, new game setup (Youth/Adult), and lost element finding. Most functionality moved to other controllers (e.g., Turn Controller). No longer actively used. Version 1.3.2. **Note: Contains bug in newGameAdult() - calls resetByTag with wrong tag.**  

---

## Object #39 ✅
**Name:** WLB EVENT ENGINE  
**GUID:** `7b92b3`  
**Type:** Tile  
**Tags:** WLB_EVENT_ENGINE, WLB_LAYOUT  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/7b92b3_EventEngine.lua`  
**Documentation:** `scripts/object-scripts/7b92b3_EventEngine_DOC.md`  
**Summary:** Core system for processing event cards (Youth and Adult). Handles card type recognition, effect application (money, satisfaction, stats, AP), dice rolling, player choices, special mechanics (marriage, children, karma), and card finalization. Integrates with Money, Satisfaction, Stats, AP, and Status systems. Version 1.7.2 includes fixes for Adult KARMA and new child AP unlock system.  

---

## Object #40 ✅
**Name:** WLB EVENTS CTRL  
**GUID:** `1339d3`  
**Type:** Tile  
**Tags:** WLB_LAYOUT, WLB_EVT_CONTROLLER  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/1339d3_EventsController.lua`  
**Documentation:** `scripts/object-scripts/1339d3_EventsController_DOC.md`  
**Summary:** UI and track management system for event cards. Manages 7-slot event track, deals cards from Youth/Adult decks, handles player interactions, enforces obligatory card rules, charges extra AP for deeper slots, coordinates with Event Engine. Version 3.6.0 includes fix for slot collection during new game (position-based, independent of state.track).  

---

## Object #41 ✅
**Name:** WLB TURN CTRL  
**GUID:** `c9ee1a`  
**Type:** Tile  
**Tags:** WLB_TURN_CTRL  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/c9ee1a_TurnController.lua`  
**Documentation:** `scripts/object-scripts/c9ee1a_TurnController_DOC.md`  
**Summary:** Central turn management and game start wizard system. Orchestrates game initialization (mode selection, player count, turn order via dice), manages turn progression with AP confirmation, handles end-of-turn processing (health from REST, blocked AP), and automates per-turn actions (shop refills, status expiration). Adult mode uses turn order rolls for start bonuses (no second roll). Version 2.9.0.  

---

## Object #42 ✅
**Name:** Youth Board  
**GUID:** `89eb00`  
**Type:** Tile  
**Tags:** WLB_LAYOUT, WLB_YOUTH_BOARD  
**Status:** ✅ Documented  
**Script:** ✅ Received and saved to `scripts/object-scripts/89eb00_YouthBoard.lua`  
**Documentation:** `scripts/object-scripts/89eb00_YouthBoard_DOC.md`  
**Summary:** Action board for Youth phase activities. Provides 5 action buttons (Vocational School, Technical Academy, Job, High School, University) that allow active player to spend AP for skills, knowledge, or money. All actions use Turns.turn_color for active player detection. Tech Academy and University require yearly payment (300) before use. Version 1.3.  

---

## Changes from Previous List

### Updated GUIDs:
- **MONEY R**: `95ea35` (was `e2d3e1`)
- **PB STATS CTRL R**: `3cefbd` (was `8c3b9e`)

### Removed Objects:
- Object #7: AP G (Action Points Green) - Deleted (no script needed)
- Previous Objects #2-6: Unknown unnamed objects - Now removed from list

### New Objects Found:
- REST Button objects (B, G, R, Y) - 4 objects
- SCANNER objects (6 different scanners)
- STATUS CONTROLLER

---

## Documentation Progress

✅ **Fully Documented:** 38 objects (scripts saved and documented)  
✅ **Verified No Script:** 4 objects (Knowledge tokens #30-33 - confirmed no script needed)  
✅ **Total Tracked:** 42 objects

**Completion:** **100% tracked and documented** (All 42 objects have been processed and documented)

**Breakdown:**
- ✅ **Individual scripts documented:** 18 objects (Year Token, Costs Calculator, Diagnostics, Estate Engine, Shop Engine, Status Controller, Token Engine, Event Engine, Events Controller, Turn Controller, Youth Board, WLB Control, 6 Scanner tools)
- ✅ **Shared scripts documented:** 20 objects across 5 shared scripts (4 Money, 4 AP Controllers, 4 Stats Controllers, 4 REST Buttons, 4 Satisfaction tokens)
- ✅ **Verified no script needed:** 4 objects (Knowledge tokens #30-33 - moved by Stats Controller)
- ⚠️ **GUID verification pending:** 7 objects (Scanner objects #22-26, STATUS CONTROLLER #28 - scripts documented, GUIDs from game may need verification)

---

## Notes

- **Shared Scripts (Documented):**
  - MONEY tokens (B, G, R, Y) - 4 objects → `MoneyController_Shared.lua`
  - PB AP CTRL (B, G, R, Y) - 4 objects → `APController_Shared.lua`
  - PB STATS CTRL (B, G, R, Y) - 4 objects → `StatsController_Shared.lua`
  - REST Button (B, G, R, Y) - 4 objects → `RestButton_Shared.lua`
  - Token Sat (B, G, R, Y) - 4 objects → `SatisfactionToken_Shared.lua`

- **No Script Needed:**
  - Token Pers K (B, G, R, Y) - 4 objects (Knowledge tokens) - Moved by Stats Controller, no script attached

- **GUID Verification Needed:**
  - SCANNER objects (#22-26) - Scripts documented, GUIDs may need verification from game
  - STATUS CONTROLLER (#28) - Script documented, GUID may need verification from game

- **Deprecated:**
  - WLB Control (#38) - Documented but marked as deprecated (no longer used, will be deleted)
