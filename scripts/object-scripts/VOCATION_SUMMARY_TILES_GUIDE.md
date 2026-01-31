# Vocation Summary Tiles - Tagging and Placement Guide

**Status:** DESIGN SPECIFICATION  
**Purpose:** Document how to tag and handle the 6 vocation summary tiles  
**Related:** `VOCATIONS_SYSTEM_ANALYSIS.md`, `VOCATION_CARD_SWAPPING_MECHANICS.md`

---

## 🎯 Overview

You have **6 Summary Tiles** - one for each vocation:
1. **PUBLIC SERVANT** - Summary tile
2. **CELEBRITY** - Summary tile
3. **SOCIAL WORKER** - Summary tile
4. **GANGSTER** - Summary tile
5. **ENTREPRENEUR** - Summary tile
6. **NGO WORKER** - Summary tile

**Purpose:** These tiles serve as **reference/informational displays** showing all information about each vocation (all 3 levels + special events) in one place.

**Difference from Playable Tiles:**
- **Summary Tiles (6):** Reference material, shows all vocation info
- **Playable Tiles (18):** Individual level tiles (3 per vocation) that go on player boards

---

## 🏷️ Recommended Tagging System

### **Base Tag (All Summary Tiles):**
- `WLB_VOCATION_SUMMARY` - Identifies all vocation summary tiles

### **Vocation-Specific Tags:**
- `WLB_VOC_SUMMARY_PUBLIC_SERVANT`
- `WLB_VOC_SUMMARY_CELEBRITY`
- `WLB_VOC_SUMMARY_SOCIAL_WORKER`
- `WLB_VOC_SUMMARY_GANGSTER`
- `WLB_VOC_SUMMARY_ENTREPRENEUR`
- `WLB_VOC_SUMMARY_NGO_WORKER`

### **Example Tags for Each Tile:**

**Public Servant Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_PUBLIC_SERVANT`

**Celebrity Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_CELEBRITY`

**Social Worker Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_SOCIAL_WORKER`

**Gangster Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_GANGSTER`

**Entrepreneur Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_ENTREPRENEUR`

**NGO Worker Summary Tile:**
- `WLB_VOCATION_SUMMARY`
- `WLB_VOC_SUMMARY_NGO_WORKER`

---

## 📍 Placement Strategy

### **Option 1: Reference Area (Recommended)**
- Place all 6 tiles in a **dedicated reference area** on the game board
- Accessible to all players
- Organized layout (e.g., 2 rows × 3 columns, or 1 row × 6 tiles)
- **No color tags needed** (shared reference, not player-specific)

### **Option 2: Stack/Box Storage**
- Store tiles in a box or stack when not in use
- Players can pick up and read when needed
- **No color tags needed**

### **Option 3: Edge of Table**
- Place tiles along the edge of the game table
- Easy to see and reference
- **No color tags needed**

---

## ⚙️ Scripting Requirements

### **Minimal Scripting Needed:**
These tiles are **primarily informational/reference** and likely don't need complex scripting. However, you might want:

1. **Optional: Click to Zoom/View**
   - Button on tile: "View Details" or "Zoom"
   - Opens larger view or spawns detailed panel
   - **Not required** - players can just pick up and read

2. **Optional: Vocation Selection Helper**
   - If used during vocation selection, could highlight available vocations
   - **Not required** - can be handled by other systems

3. **No Dynamic State:**
   - These tiles don't change during gameplay
   - They're static reference material
   - No need for state tracking

---

## 🔍 Finding Summary Tiles

### **Find All Summary Tiles:**
```lua
function findAllSummaryTiles()
  local tiles = {}
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and obj.hasTag("WLB_VOCATION_SUMMARY") then
      table.insert(tiles, obj)
    end
  end
  return tiles
end
```

### **Find Specific Vocation Summary:**
```lua
function findSummaryTileForVocation(vocation)
  local tag = "WLB_VOC_SUMMARY_" .. vocation
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and 
       obj.hasTag("WLB_VOCATION_SUMMARY") and
       obj.hasTag(tag) then
      return obj
    end
  end
  return nil
end
```

---

## 📋 Tagging Checklist

For each of the 6 summary tiles:

- [ ] **Public Servant Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_PUBLIC_SERVANT`

- [ ] **Celebrity Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_CELEBRITY`

- [ ] **Social Worker Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_SOCIAL_WORKER`

- [ ] **Gangster Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_GANGSTER`

- [ ] **Entrepreneur Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_ENTREPRENEUR`

- [ ] **NGO Worker Summary Tile:**
  - [ ] Add tag: `WLB_VOCATION_SUMMARY`
  - [ ] Add tag: `WLB_VOC_SUMMARY_NGO_WORKER`

---

## 🎯 Usage Scenarios

### **During Vocation Selection:**
- Players can reference summary tiles to see all vocation details
- Helps players make informed choices
- No scripting needed - players just read them

### **During Gameplay:**
- Players can check summary tiles to understand:
  - What other players' vocations can do
  - Promotion requirements
  - Special actions available
  - Level perks and abilities

### **For Implementation:**
- Summary tiles serve as **visual reference** for implementing vocation mechanics
- All information needed is on these tiles
- Can be used to verify implementation matches card design

---

## 🔄 Comparison: Summary vs Playable Tiles

| Feature | Summary Tiles (6) | Playable Tiles (18) |
|---------|-------------------|---------------------|
| **Purpose** | Reference/information | Active game pieces |
| **Placement** | Reference area (shared) | Player boards (per player) |
| **Tags** | `WLB_VOCATION_SUMMARY` + vocation tag | `WLB_VOCATION_TILE` + level tag + color tag |
| **Color Tags** | ❌ No (shared reference) | ✅ Yes (when on board) |
| **State** | Static (doesn't change) | Dynamic (swaps on promotion) |
| **Scripting** | Minimal (optional) | Required (placement, swapping) |
| **Quantity** | 6 (one per vocation) | 18 (3 levels × 6 vocations) |

---

## ✅ Recommended Approach

### **Tagging:**
1. **Base tag:** `WLB_VOCATION_SUMMARY` (all 6 tiles)
2. **Vocation tag:** `WLB_VOC_SUMMARY_[VOCATION_NAME]` (specific to each)
3. **No color tags** (shared reference, not player-specific)

### **Placement:**
- Place in **reference area** on game board
- Accessible to all players
- Organized layout (your choice: rows, columns, or stack)

### **Scripting:**
- **Optional:** Simple script for organization/positioning
- **Not required:** Players can pick up and read manually
- **No dynamic state needed:** Tiles are static reference

---

## 📝 Summary

**What to do with Summary Tiles:**

1. ✅ **Tag them:**
   - Base: `WLB_VOCATION_SUMMARY`
   - Specific: `WLB_VOC_SUMMARY_[VOCATION_NAME]`

2. ✅ **Place them:**
   - In a reference area (accessible to all players)
   - No color tags needed (shared reference)

3. ✅ **Use them:**
   - As player reference during vocation selection
   - As reference during gameplay
   - As implementation guide for mechanics

4. ✅ **No complex scripting needed:**
   - They're static reference material
   - Players can pick up and read
   - Optional: Simple positioning script if desired

---

**Status:** Ready for tagging and placement  
**Next Action:** Tag all 6 summary tiles and place them in reference area
