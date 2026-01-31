# Next Steps Proposal - Board Game Digitalization

**Generated:** 2026-01-XX  
**Based on:** Shop Cards Status Report + Event Cards Status Report

---

## 📊 Current Status Summary

### Overall Completion
- **Shop Cards:** 44/56 fully working (79%) - 8 partially working, 2 skipped
- **Event Cards:** 108/120 fully working (90%) - 2 partially working, 10 not implemented
- **Total Cards:** 152/176 fully working (86%)

### Key Achievements
- ✅ All 39 Youth Event Cards working (100%)
- ✅ All 28 Consumable Shop Cards working (100%)
- ✅ 10/14 Investment Cards working (71%)
- ✅ 8/14 Hi-Tech Cards working (57%)
- ✅ 69/81 Adult Event Cards working (85%)

---

## 🎯 Proposed Next Steps (Prioritized)

### 🔴 **PHASE 1: Complete High-Impact Missing Features** (High Priority)

These features will immediately improve gameplay completeness and player experience.

#### 1.1 **Complete Hi-Tech Card Features** (6 cards - 2-3 hours)
**Impact:** High - These are purchasable items players expect to work

**Tasks:**
1. **SMARTPHONE** (HSHOP_12) - End-of-turn check
   - Add check in `TurnController.lua` at end of turn
   - If player spent ≥2 AP on Work/Learning → +1 SAT
   - **Difficulty:** Medium (requires AP tracking integration)

2. **SMARTWATCH** (HSHOP_13-14) - Start-of-turn AP unblocking
   - Add check in `TurnController.lua` at start of turn
   - Unblock 1 AP from INACTIVE (except child-blocked) using `PS_GetNonChildBlockedAP()`
   - **Difficulty:** Easy (API already exists)

3. **ALARM** (HSHOP_11) - Theft protection
   - Add check in `EventEngine.lua` before applying theft effects
   - Check for ALARM ownership via `ShopEngine.API_ownsHiTech()`
   - **Difficulty:** Medium (requires identifying theft events)

4. **CAR** (HSHOP_09-10) - Estate Agency entry free
   - Add check in `EstateEngine.lua` before charging entry AP
   - Similar to shop entry free check (already implemented)
   - **Difficulty:** Easy (pattern already exists)

**Expected Outcome:** All Hi-Tech cards fully functional (14/14 = 100%)

---

#### 1.2 **Fix FAMILY Card Child Costs** (Already Working - Status Update Only)
**Status:** ✅ **ALREADY WORKING** - Just needs status report update

The FAMILY consumable card already adds 150 WIN per turn to Costs Calculator when child is created. The status report incorrectly marked it as "partially working" - this is actually complete!

**Action Required:** Update documentation only

---

### 🟡 **PHASE 2: Complete Partially Working Features** (Medium Priority)

These features are partially implemented but need completion to be fully usable.

#### 2.1 **Complete Event Card Implementations** (10 cards - 4-6 hours)
**Impact:** Medium - Cards are playable but show TODO messages

**Tasks:**
1. **AD_WORKBONUS** (3 cards: AD_32-34)
   - **Requires:** Profession/job system
   - **Recommendation:** Defer until profession system exists
   - **Alternative:** Implement basic work bonus (flat amount) as placeholder

2. **AD_AUCTION_O** (1 card: AD_47)
   - **Requires:** Auction/property system
   - **Recommendation:** Defer until property/auction system exists
   - **Note:** Property Tax already works, so property system may be partially implemented

3. **AD_VE (Volunteer Experience)** (24 cards: AD_58-81)
   - **Current State:** Choice UI works, but choices have no effect
   - **Task:** Implement experience path tracking and bonuses
   - **Difficulty:** High (requires defining experience system mechanics)
   - **Recommendation:** Implement basic version first (track choices, apply simple bonuses)

**Expected Outcome:** 3 more cards fully working (111/120 = 92%)

---

#### 2.2 **Enable AD_VOUCH_PROP Discount** (2 cards - 1-2 hours)
**Impact:** Low - Card works, but discount cannot be used until property system exists

**Status:** Card is fully implemented, just waiting on property purchase system
**Action:** Defer until property system is implemented (likely in EstateEngine)

---

### 🟢 **PHASE 3: Quality Improvements** (Lower Priority)

These improvements enhance gameplay experience but don't block functionality.

#### 3.1 **Error Handling & Robustness** (2-3 hours)
**Impact:** High - Prevents crashes and improves stability

**Tasks:**
- Add more `pcall` wrappers in critical paths
- Improve error messages for failed API calls
- Add fallback mechanisms for missing game objects
- Better handling of edge cases (e.g., broken hi-tech items, missing children)

**Recent Example:** Fixed Baby Monitor error (`findOneByTags` → `firstWithTag`)

---

#### 3.2 **Documentation & Testing** (Ongoing)
**Impact:** Medium - Helps with future maintenance

**Tasks:**
- Update status reports after each fix
- Document API contracts between engines
- Create testing checklist for new features
- Document card mechanics clearly

---

## 💡 Recommended Immediate Next Steps (Tonight)

### **Option A: Quick Wins (2-3 hours)**
Complete Hi-Tech cards that are easy to fix:

1. **SMARTWATCH** - Start-of-turn AP unblocking (30 min)
   - Easy: Uses existing `PS_GetNonChildBlockedAP()` API
   - High impact: Players can use this immediately

2. **CAR** - Estate Agency entry free (30 min)
   - Easy: Copy pattern from shop entry free check
   - Medium impact: Complements existing shop free entry

3. **SMARTPHONE** - End-of-turn check (1-2 hours)
   - Medium: Requires AP tracking for Work/Learning areas
   - High impact: Popular card players expect to work

**Total Time:** 2-3 hours  
**Result:** 3 more Hi-Tech cards fully working (11/14 = 79%)

---

### **Option B: Critical Feature Completion (3-4 hours)**
Complete Hi-Tech cards + start ALARM:

1. **All of Option A** (2-3 hours)

2. **ALARM** - Theft protection (1-2 hours)
   - Medium: Requires identifying theft events in EventEngine
   - High impact: Protects player assets

**Total Time:** 3-4 hours  
**Result:** 4 more Hi-Tech cards fully working (12/14 = 86%)

---

### **Option C: Event Card Completion (4-6 hours)**
Complete partially working Event cards:

1. **AD_VE Cards** - Implement basic experience tracking (4-6 hours)
   - High: 24 cards waiting for implementation
   - Medium impact: Cards are playable but choices do nothing
   - **Recommendation:** Implement simple version first:
     - Track chosen path (A or B) per player
     - Apply basic bonuses (e.g., +1 SAT, +2 Skills, etc.)
     - Refine later with full experience system

**Total Time:** 4-6 hours  
**Result:** 24 more Event cards fully working (132/120 = 110%... wait, that's 132/144 total cards)

---

## 🎯 **My Recommendation: Option B**

**Why Option B?**
1. **High Impact:** Completes most Hi-Tech cards (only 2 remaining)
2. **Manageable Scope:** 3-4 hours is reasonable for one session
3. **Clear Progress:** Gets you to 86% Hi-Tech completion (12/14)
4. **User Visible:** Players will immediately notice these fixes
5. **Foundation:** Completes core mechanics before complex features

**After Option B, Next Session:**
- Complete remaining 2 Hi-Tech cards (if any dependencies)
- Start AD_VE implementation (can be done incrementally)
- Or tackle any bugs/issues that come up during testing

---

## 📋 Detailed Task Breakdown: Option B

### Task 1: SMARTWATCH (HSHOP_13-14)
**File:** `c9ee1a_TurnController.lua`  
**Location:** `onTurnStart_ProcessInvestments` or similar start-of-turn function

**Implementation:**
```lua
-- Check for SMARTWATCH ownership
local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
if shopEngine and shopEngine.call then
  local ok, hasWatch = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=color, kind="SMARTWATCH"})
  end)
  
  if ok and hasWatch == true then
    -- Unblock 1 AP from INACTIVE (except child-blocked)
    local psc = findOneByTags({TAG_PLAYER_STATUS_CTRL})
    if psc and psc.call then
      local ok2, nonChildBlocked = pcall(function()
        return psc.call("PS_GetNonChildBlockedAP", {color=color})
      end)
      
      if ok2 and type(nonChildBlocked) == "number" and nonChildBlocked > 0 then
        local ap = resolveAP(color)
        if ap and ap.call then
          pcall(function()
            ap.call("moveAP", {to="INACTIVE", amount=-1})
          end)
          safeBroadcastToColor("⌚ Smartwatch: -1 INACTIVE AP (except child-blocked)", color, {0.8,0.9,1})
        end
      end
    end
  end
end
```

**Estimated Time:** 30 minutes

---

### Task 2: CAR - Estate Agency Entry Free
**File:** `fd8ce0_EstateEngine.lua`  
**Location:** Entry AP check function (similar to shop entry check)

**Implementation:**
```lua
-- Check if player owns CAR (similar to shop entry free check)
local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
if shopEngine and shopEngine.call then
  local ok, hasCar = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=color, kind="CAR"})
  end)
  
  if ok and hasCar == true then
    log("CAR: Estate entry free for "..tostring(color))
    return true  -- Entry is free
  end
end
```

**Estimated Time:** 30 minutes

---

### Task 3: SMARTPHONE (HSHOP_12)
**File:** `c9ee1a_TurnController.lua`  
**Location:** End-of-turn processing function

**Implementation:**
```lua
-- Check for SMARTPHONE ownership
local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
if shopEngine and shopEngine.call then
  local ok, hasPhone = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=color, kind="SMARTPHONE"})
  end)
  
  if ok and hasPhone == true then
    -- Count AP spent on Work/Learning this turn
    local ap = resolveAP(color)
    if ap and ap.call then
      -- Query AP Controller for AP spent in WORK and SCHOOL/LEARNING areas
      -- This requires knowing how AP Controller tracks area spending
      -- Implementation depends on AP Controller API
      local workAP = getAPSpentInArea(color, "WORK") or 0
      local schoolAP = getAPSpentInArea(color, "SCHOOL") or getAPSpentInArea(color, "LEARNING") or 0
      
      if (workAP + schoolAP) >= 2 then
        -- Grant +1 SAT
        local satObj = getSatToken(color)
        if satObj then satAdd(satObj, 1, "Smartphone") end
        safeBroadcastToColor("📱 Smartphone: +1 SAT (spent ≥2 AP on Work/Learning)", color, {0.8,0.9,1})
      end
    end
  end
end
```

**Challenge:** Requires AP Controller to track area-specific spending (may not exist yet)  
**Alternative:** Track manually in Turn Controller during turn  
**Estimated Time:** 1-2 hours (depends on AP Controller capabilities)

---

### Task 4: ALARM (HSHOP_11)
**File:** `7b92b3_EventEngine.lua`  
**Location:** Before applying theft effects

**Implementation:**
```lua
-- Before applying theft effects, check for ALARM
local function hasAlarmProtection(color)
  local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
  if not shopEngine or not shopEngine.call then return false end
  
  local ok, hasAlarm = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=color, kind="ALARM"})
  end)
  
  return (ok and hasAlarm == true)
end

-- When applying theft effects:
if hasAlarmProtection(color) then
  safeBroadcastToColor("🔔 Alarm: Theft prevented!", color, {0.9,0.9,0.7})
  return STATUS.DONE  -- Theft blocked
end
```

**Challenge:** Need to identify which event cards are "theft" events  
**Estimated Time:** 1-2 hours (depends on how theft events are structured)

---

## 🔄 After Option B: Future Priorities

### Next Session Options:

1. **Complete AD_VE Cards** (if volunteer experience system is defined)
   - 24 cards waiting
   - High value if system is clear

2. **Implement AD_WORKBONUS** (if profession system exists)
   - 3 cards waiting
   - Requires job/profession system

3. **Bug Fixes & Polish**
   - Address any issues found during testing
   - Improve error messages
   - Add missing edge case handling

4. **Testing & Verification**
   - Test all recently implemented features
   - Verify all card effects work as expected
   - Check for regressions

---

## 📊 Expected Progress After Option B

### Before Option B:
- **Hi-Tech Cards:** 8/14 working (57%)
- **Shop Cards:** 44/56 working (79%)
- **Event Cards:** 108/120 working (90%)

### After Option B:
- **Hi-Tech Cards:** 12/14 working (86%) ⬆️ +29%
- **Shop Cards:** 48/56 working (86%) ⬆️ +7%
- **Event Cards:** 108/120 working (90%) (unchanged)

### Overall:
- **Total Cards:** 156/176 working (89%) ⬆️ +3%

---

## ⚠️ Considerations

### Dependencies to Check:
1. **AP Controller:** Does it track area-specific spending? (for SMARTPHONE)
2. **Estate Engine:** Where is entry AP charged? (for CAR)
3. **Event Engine:** How are theft events identified? (for ALARM)
4. **Profession System:** Does it exist? (for AD_WORKBONUS)

### Risks:
- **SMARTPHONE:** May require AP Controller enhancements if area tracking doesn't exist
- **ALARM:** May require refactoring theft events to check ALARM before applying
- **Time Estimates:** May be longer if dependencies need to be created first

---

## ✅ Summary Recommendation

**For Tonight's Session:**

🎯 **Proceed with Option B** - Complete Hi-Tech cards (SMARTWATCH, CAR, SMARTPHONE, ALARM)

**Why:**
- ✅ High impact (completes most Hi-Tech cards)
- ✅ Manageable scope (3-4 hours)
- ✅ Clear progress visible to users
- ✅ Builds on existing patterns
- ✅ Leaves system in good state for next session

**Expected Outcome:**
- 4 more Hi-Tech cards fully working
- Hi-Tech completion: 57% → 86%
- Overall card completion: 86% → 89%

**If Time Allows:**
- Start AD_VE basic implementation
- Or test and fix any bugs found

---

**Ready to proceed?** Let me know if you'd like me to start implementing Option B, or if you prefer a different approach!
