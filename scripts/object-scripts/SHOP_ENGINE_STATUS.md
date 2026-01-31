# Shop Engine - Status & TODO Analysis

**Script:** `d59e04_ShopEngine.lua`  
**Version:** 1.3.4  
**Last Updated:** 2026-01-17

---

## ✅ What Works

### Fully Functional
1. **Shop Card Management**
   - ✅ Card classification by name (CSHOP_*, HSHOP_*, ISHOP_*)
   - ✅ Slot system (CLOSED + 3 OPEN slots per row)
   - ✅ RESET pipeline (collect → shuffle → deal)
   - ✅ REFILL pipeline (fill empty slots)
   - ✅ RANDOMIZE pipeline (per row)

2. **Consumables (C) - 28 Cards - FULLY WORKING**
   - ✅ CURE (6 cards) - Removes SICK/WOUNDED, adds Health, roll-based
   - ✅ KARMA (2 cards) - Adds GOOD_KARMA status
   - ✅ BOOK (2 cards) - +2 Knowledge
   - ✅ MENTORSHIP (2 cards) - +2 Skills
   - ✅ SUPPLEMENTS (3 cards) - +2 Health
   - ✅ SAT (4 cards) - Balloon, Gravity, Bungee, Parachute (+4 to +12 SAT)
   - ✅ FAMILY (2 cards) - Roll D6 for child (BOY/GIRL)
   - ✅ NATURE_TRIP (2 cards) - Roll D6 for +SAT

3. **Purchase System**
   - ✅ Modal UI (YES/NO confirmation)
   - ✅ Entry AP cost (1 AP per turn)
   - ✅ Money spending (WIN)
   - ✅ Extra AP costs per card
   - ✅ Buyer resolution (active turn color)
   - ✅ Card return to deck (not destroyed)

4. **Integration**
   - ✅ Money Controller integration
   - ✅ AP Controller integration
   - ✅ Stats Controller integration
   - ✅ Player Status Controller integration
   - ✅ Turn tracking (`Turns.turn_color`)

---

## ❌ What Doesn't Work / Missing

### Blocked Features

1. **Hi-Tech (H) Cards - NOT IMPLEMENTED**
   - ❌ Purchase flow blocked: `"⛔ Na razie programujemy tylko CONSUMABLES (CSHOP)."`
   - ❌ 14 Hi-Tech cards exist but cannot be purchased
   - ❌ No `HI_TECH_DEF` table defined
   - ❌ No effects implemented

2. **Investments (I) Cards - NOT IMPLEMENTED**
   - ❌ Purchase flow blocked: Same as Hi-Tech
   - ❌ 14 Investment cards exist but cannot be purchased
   - ❌ No `INVESTMENT_DEF` table defined
   - ❌ No effects implemented

### Incomplete Effects (TODOs in Code)

1. **PILLS (Anti-Sleeping Pills) - 5 cards**
   - ❌ Current: Just broadcasts message
   - ⚠️ TODO: "+3 rest-equivalent"
   - **Issue:** "Rest-equivalent" mechanic not defined/implemented

2. **NATURE_TRIP - 2 cards**
   - ✅ Roll D6 for +SAT works
   - ❌ TODO: "+3 rest-equivalent" not implemented
   - **Issue:** Same as PILLS - rest-equivalent mechanic missing

3. **FAMILY Cards**
   - ✅ Child creation (BOY/GIRL) works
   - ❌ TODO: "Child costs per round" not implemented
   - **Issue:** Ongoing child costs need to be tracked/charged

4. **SAT Integration**
   - ⚠️ Works via Stats Controller fallback
   - ❌ Message: "SAT +X for color (no SAT API wired in ShopEngine yet)"
   - **Note:** Currently uses `statsApply({sat=X})` which may work, but comment suggests incomplete integration

---

## 🔍 Code Locations to Check

### Purchase Block (Line ~999)
```lua
if row ~= "C" then
  safeBroadcastToColor("⛔ Na razie programujemy tylko CONSUMABLES (CSHOP).", buyerColor, {1,0.6,0.2})
  return false
end
```

### TODO Effects

**PILLS (Line ~907-909):**
```lua
safeBroadcastAll("💊 "..color.." użył Anti-Sleeping Pills: +3 rest-equivalent (TODO)", {1,1,0.6})
```

**NATURE_TRIP (Line ~911-920):**
```lua
safeBroadcastAll("🌿 Nature Trip: "..color.." gets +3 rest-equivalent (TODO)", {0.7,1,0.7})
```

**FAMILY (Line ~939):**
```lua
safeBroadcastAll("ℹ️ Child costs per round (TODO).", {1,1,0.6})
```

---

## 🎯 Suggested Next Steps

### Priority 1: Complete Consumables
1. **Implement rest-equivalent for PILLS**
   - Need to define: What is "rest-equivalent"?
   - Should it add to health? Add to REST area AP count? Something else?

2. **Implement rest-equivalent for NATURE_TRIP**
   - Same question as PILLS

3. **Implement child costs for FAMILY**
   - Need to define: How much per round? When charged? (End of turn? End of round?)

### Priority 2: Implement Hi-Tech Cards
1. Create `HI_TECH_DEF` table (similar to `CONSUMABLE_DEF`)
2. Remove purchase block for H cards
3. Implement Hi-Tech effects (what do H cards do?)
4. Test all 14 Hi-Tech cards

### Priority 3: Implement Investment Cards
1. Create `INVESTMENT_DEF` table
2. Remove purchase block for I cards
3. Implement Investment effects (what do I cards do?)
4. Test all 14 Investment cards

---

## ❓ Questions for You

1. **Rest-equivalent mechanic:**
   - What should PILLS and NATURE_TRIP actually do?
   - Does "rest-equivalent" mean healing? Extra AP from REST area? Something else?

2. **Child costs:**
   - How much should a child cost per round?
   - When should costs be charged? (End of turn? End of round? Start of next turn?)
   - Should this integrate with Costs Calculator?

3. **Hi-Tech cards:**
   - What effects should Hi-Tech cards have?
   - Do you have a list of all 14 HSHOP_* card names?
   - What are their intended effects?

4. **Investment cards:**
   - What effects should Investment cards have?
   - Do you have a list of all 14 ISHOP_* card names?
   - What are their intended effects?

5. **SAT integration:**
   - Is the current SAT integration working correctly?
   - Should we improve the SAT API wiring, or is the fallback sufficient?

---

## 📝 Testing Checklist

When testing, check:
- [ ] Can purchase all 28 Consumable cards
- [ ] All Consumable effects apply correctly
- [ ] Entry AP cost works (1 AP per turn)
- [ ] Cards return to deck after purchase
- [ ] RESET restores full shop
- [ ] REFILL fills empty slots
- [ ] RANDOMIZE works for each row
- [ ] UI modal appears/disappears correctly

---

**Ready to proceed when you tell me what to prioritize!** 🚀
