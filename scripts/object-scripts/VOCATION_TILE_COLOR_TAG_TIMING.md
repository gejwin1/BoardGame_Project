# Vocation Tile - Color Tag Timing

**Status:** IMPLEMENTATION GUIDE  
**Purpose:** Document exactly when color tags are added/removed from vocation tiles  
**Related:** `VOCATION_CARD_SWAPPING_MECHANICS.md`

---

## 🎯 Color Tag Purpose

**Color tags** (`WLB_COLOR_Yellow`, `WLB_COLOR_Blue`, `WLB_COLOR_Red`, `WLB_COLOR_Green`) are used to:
- Track which player's board a tile is currently on
- Find tiles on a specific player's board
- Prevent tiles from being placed on multiple boards simultaneously

---

## ✅ When Color Tag is ADDED

### **1. Vocation Selection (Initial Placement)**
- **When:** Player selects their vocation at Adult period start
- **Action:** 
  1. System finds appropriate Level 1 tile for chosen vocation
  2. System places tile on player's board (Character slot)
  3. **System adds color tag** (e.g., `WLB_COLOR_Yellow`)
- **Result:** Tile is now "owned" by that player and visible on their board

**Example:**
```lua
-- Player Yellow selects ENTREPRENEUR
-- System finds ENTREPRENEUR_LEVEL_1 tile
-- Places tile on Yellow's board
-- Adds tag: WLB_COLOR_Yellow
```

---

### **2. Tile Swapping (On Promotion)**
- **When:** Player promotes to next level (Level 1 → 2, or Level 2 → 3)
- **Action:**
  1. System removes old level tile from board (removes color tag)
  2. System finds new level tile for same vocation
  3. System places new tile on player's board
  4. **System adds color tag** to new tile
- **Result:** New tile is now "owned" by that player

**Example:**
```lua
-- Yellow promotes from Level 1 to Level 2
-- Remove ENTREPRENEUR_LEVEL_1 (remove WLB_COLOR_Yellow)
-- Find ENTREPRENEUR_LEVEL_2 tile
-- Place on Yellow's board
-- Add tag: WLB_COLOR_Yellow
```

---

## ❌ When Color Tag is REMOVED

### **1. Tile Removal (Before Swapping)**
- **When:** Player promotes and old tile needs to be removed
- **Action:**
  1. System finds current tile on player's board
  2. **System removes color tag**
  3. System moves tile to storage area
- **Result:** Tile is no longer "owned" by any player

**Example:**
```lua
-- Yellow promotes from Level 1 to Level 2
-- Find ENTREPRENEUR_LEVEL_1 on board
-- Remove tag: WLB_COLOR_Yellow
-- Move tile to storage
```

---

### **2. Game Reset / Vocation Reset (If Needed)**
- **When:** Game resets or player's vocation is cleared
- **Action:**
  1. System finds tile on player's board
  2. **System removes color tag**
  3. System moves tile to storage area
- **Result:** Tile returns to neutral state

---

## 📋 Implementation Flow

### **Vocation Selection Flow:**
```lua
function placeTileOnBoard(tile, color)
  -- 1. Find player board
  local board = findPlayerBoard(color)
  
  -- 2. Find Character slot position
  local slotPos = findCharacterSlot(color)
  
  -- 3. Place tile
  tile.setPositionSmooth(slotPos, false, true)
  
  -- 4. ADD COLOR TAG
  tile.addTag("WLB_COLOR_" .. color)
end
```

### **Tile Swapping Flow:**
```lua
function swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  -- 1. Remove old tile
  local oldTile = findTileOnPlayerBoard(color)
  if oldTile then
    -- REMOVE COLOR TAG
    oldTile.removeTag("WLB_COLOR_" .. color)
    oldTile.setPositionSmooth(STORAGE_POSITION, false, true)
  end
  
  -- 2. Find new tile
  local newTile = findTileForVocationAndLevel(vocation, newLevel)
  
  -- 3. Place new tile
  local slotPos = findCharacterSlot(color)
  newTile.setPositionSmooth(slotPos, false, true)
  
  -- 4. ADD COLOR TAG
  newTile.addTag("WLB_COLOR_" .. color)
end
```

---

## 🔍 Finding Tiles by Color Tag

### **Find Tile on Specific Player's Board:**
```lua
function findTileOnPlayerBoard(color)
  local colorTag = "WLB_COLOR_" .. color
  
  -- Search all objects
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj.hasTag and 
       obj.hasTag("WLB_VOCATION_TILE") and
       obj.hasTag(colorTag) then
      return obj
    end
  end
  
  return nil
end
```

---

## ✅ Summary

**Color Tag Added:**
- ✅ When tile is placed on player's board (vocation selection)
- ✅ When new tile is placed during promotion

**Color Tag Removed:**
- ✅ When tile is removed from board (before swapping)
- ✅ When game/vocation resets

**Color Tag Purpose:**
- Track which player "owns" the tile
- Find tiles on specific player's board
- Prevent duplicate placements

---

**Status:** Ready for implementation  
**Next Action:** Implement color tag add/remove in tile placement and swapping functions
