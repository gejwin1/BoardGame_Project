# Vocations System - Next Steps

**Status:** READY TO START IMPLEMENTATION  
**Last Updated:** 2026-01-XX  
**Current State:** All tiles created, scanner ready, documentation complete

---

## ✅ What You've Completed

1. ✅ **18 Playable Vocation Tiles** - Tagged and ready
   - 3 levels × 6 vocations
   - Tags: `WLB_VOCATION_TILE` + vocation tag + level tag

2. ✅ **6 Summary Tiles** - Need tagging
   - One per vocation (reference material)
   - Need tags: `WLB_VOCATION_SUMMARY` + vocation-specific tag

3. ✅ **Scanner Tool** - Created and ready
   - `ScannerVocationTile.lua` - For measuring Character slot position

4. ✅ **Documentation** - Complete
   - All mechanics documented
   - Implementation roadmap ready

---

## 🎯 Recommended Next Steps (In Order)

### **STEP 1: Tag Summary Tiles** (5 minutes)
**Quick task before starting implementation**

Tag all 6 summary tiles:
- Base tag: `WLB_VOCATION_SUMMARY`
- Specific tags: `WLB_VOC_SUMMARY_PUBLIC_SERVANT`, `WLB_VOC_SUMMARY_CELEBRITY`, etc.

**Why now:** Get all assets properly tagged before building systems that might reference them.

---

### **STEP 2: Measure Character Slot Position** (10 minutes)
**Use the scanner tool you created**

1. Place scanner tile on Character slot
2. Click "MEASURE" (use AUTO or select color)
3. Click "EXPORT" to get code
4. Copy the exported `CHARACTER_SLOT_LOCAL` table

**Why now:** You'll need this position data for VocationsController to place tiles on boards.

---

### **STEP 3: Create VocationsController.lua** (2-3 hours)
**Foundation - Everything else depends on this**

This is **PHASE 1** from the roadmap. Create the core tracking system:

**What to build:**
1. Basic structure with tag `WLB_VOCATIONS_CTRL`
2. State tracking:
   - `vocations[color] = vocationName` (or nil)
   - `levels[color] = 1` (starts at Level 1)
   - `workAP[color] = 0` (cumulative AP spent on work)
3. Vocation data structure:
   - All 6 vocations with salaries per level
   - Promotion requirements
   - Job titles
4. Basic APIs:
   - `VOC_GetVocation({color=...})`
   - `VOC_SetVocation({color=..., vocation=...})`
   - `VOC_GetLevel({color=...})`
   - `VOC_GetSalary({color=...})`
   - `VOC_AddWorkAP({color=..., amount=...})`

**Why this first:** Everything else (tile placement, selection, work income, promotions) depends on this foundation.

---

### **STEP 4: Test Basic Functionality** (30 minutes)
**Verify VocationsController works**

1. Test: Can set vocation for a player
2. Test: Can query vocation state
3. Test: Can get salary for vocation + level
4. Test: Can track work AP

**Why now:** Verify foundation works before building on top of it.

---

### **STEP 5: Implement Tile Placement Functions** (1-2 hours)
**Connect VocationsController to physical tiles**

Add functions to VocationsController:
1. `findTileForVocationAndLevel(vocation, level)` - Find tile by tags
2. `findTileOnPlayerBoard(color)` - Find tile on board
3. `placeTileOnBoard(tile, color)` - Place tile in Character slot
4. `removeTileFromBoard(color)` - Remove tile from board
5. `swapTileOnPromotion(color, oldLevel, newLevel)` - Swap tiles

**Why now:** Enables physical tile management when vocations are selected/promoted.

---

### **STEP 6: Vocation Selection at Adult Start** (2-3 hours)
**PHASE 2 from roadmap**

Integrate with Turn Controller to:
1. Detect Adult period start
2. Calculate selection order (Science Points)
3. Show selection UI/flow
4. Set vocation via `VOC_SetVocation()`
5. Place Level 1 tile on player's board

**Why now:** Players need to be able to select vocations to start the system.

---

## 📋 Immediate Action Plan

### **Today (Quick Setup):**

1. **Tag Summary Tiles** (5 min)
   - Add `WLB_VOCATION_SUMMARY` to all 6
   - Add vocation-specific tags

2. **Measure Character Slot** (10 min)
   - Use scanner tool
   - Export and save position data

3. **Start VocationsController** (Begin implementation)
   - Create script file
   - Add basic structure
   - Define vocation data

### **Next Session (Core Implementation):**

4. **Complete VocationsController** (2-3 hours)
   - Finish all APIs
   - Add tile placement functions
   - Test basic functionality

5. **Vocation Selection** (2-3 hours)
   - Integrate with Turn Controller
   - Implement selection flow
   - Test selection works

---

## 🎯 Priority Order

**Must Do First:**
1. ✅ Tag summary tiles (quick)
2. ✅ Measure Character slot (quick)
3. ✅ Create VocationsController (foundation)

**Then:**
4. Tile placement functions
5. Vocation selection
6. Work income system
7. Promotion system

---

## 💡 Why This Order?

1. **Foundation First:** VocationsController is the core - everything depends on it
2. **Quick Wins:** Tagging and measuring are fast and enable later work
3. **Incremental:** Each step builds on the previous one
4. **Testable:** Can test each piece as you build it

---

## ✅ Ready to Start?

**Recommended First Action:**
1. Tag the 6 summary tiles (5 minutes)
2. Measure Character slot position (10 minutes)
3. Begin creating VocationsController.lua (2-3 hours)

**After VocationsController is working:**
- You can test vocation selection
- You can test tile placement
- You can build work income system
- You can build promotion system

---

**Status:** Ready to begin Phase 1 implementation  
**Next Action:** Tag summary tiles → Measure position → Create VocationsController
