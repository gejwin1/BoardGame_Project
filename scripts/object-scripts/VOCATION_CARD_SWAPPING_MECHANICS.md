# Vocation Tile Swapping Mechanics

**Status:** DESIGN SPECIFICATION  
**Purpose:** Document how vocation tiles are swapped on player board when level changes  
**Related:** `VOCATION_CARDS_UX_ANALYSIS.md`, `VOCATIONS_IMPLEMENTATION_ROADMAP.md`

---

## 🎯 Tile Structure

### **Physical Tiles:**
- **18 tiles total:** 3 levels × 6 vocations
- Each tile represents a **specific vocation + specific level**
- **Type:** Tile (not Card) - prevents merging into decks when stacked
- Example tiles:
  - `ENTREPRENEUR_LEVEL_1` (Shop Assistant)
  - `ENTREPRENEUR_LEVEL_2` (Manager)
  - `ENTREPRENEUR_LEVEL_3` (Hi-Tech Company Owner)
  - `PUBLIC_SERVANT_LEVEL_1` (Junior Clerk)
  - `PUBLIC_SERVANT_LEVEL_2` (Administrative Officer)
  - ... and so on

### **Tile Storage:**
- Tiles stored in a box or area when not in use
- **Advantage:** Tiles don't merge into decks when stacked (unlike cards)
- Only **1 tile per player** on board at any time
- Tile on board = matches player's current level

---

## 🔄 Tile Swapping Logic

### **Initial Placement (Vocation Selection):**
1. Player selects vocation (e.g., "ENTREPRENEUR")
2. Player starts at Level 1
3. System finds `ENTREPRENEUR_LEVEL_1` tile
4. System places tile in player's Character slot on board

### **On Promotion (Level 1 → 2):**
1. Player promotes from Level 1 to Level 2
2. System finds current tile on board: `ENTREPRENEUR_LEVEL_1`
3. System removes `ENTREPRENEUR_LEVEL_1` from board
4. System finds `ENTREPRENEUR_LEVEL_2` tile (from storage area)
5. System places `ENTREPRENEUR_LEVEL_2` in Character slot
6. Old tile (`ENTREPRENEUR_LEVEL_1`) returns to storage area

### **On Promotion (Level 2 → 3):**
1. Player promotes from Level 2 to Level 3
2. System finds current tile on board: `ENTREPRENEUR_LEVEL_2`
3. System removes `ENTREPRENEUR_LEVEL_2` from board
4. System finds `ENTREPRENEUR_LEVEL_3` tile (from storage area)
5. System places `ENTREPRENEUR_LEVEL_3` in Character slot
6. Old tile (`ENTREPRENEUR_LEVEL_2`) returns to storage area

---

## 🏷️ Tile Tagging System

### **Tags for Identification:**

**Base Tag:**
- `WLB_VOCATION_TILE` - All vocation tiles have this tag

**Vocation Tags:**
- `WLB_VOC_PUBLIC_SERVANT`
- `WLB_VOC_CELEBRITY`
- `WLB_VOC_SOCIAL_WORKER`
- `WLB_VOC_GANGSTER`
- `WLB_VOC_ENTREPRENEUR`
- `WLB_VOC_NGO_WORKER`

**Level Tags:**
- `WLB_VOC_LEVEL_1`
- `WLB_VOC_LEVEL_2`
- `WLB_VOC_LEVEL_3`

**Color Tags (when on board):**
- `WLB_COLOR_Yellow`
- `WLB_COLOR_Blue`
- `WLB_COLOR_Red`
- `WLB_COLOR_Green`

### **Example Tile Tags:**
- `ENTREPRENEUR_LEVEL_1` tile has:
  - `WLB_VOCATION_TILE`
  - `WLB_VOC_ENTREPRENEUR`
  - `WLB_VOC_LEVEL_1`
  - (When on Yellow player's board: `WLB_COLOR_Yellow`)

---

## 📋 Implementation Functions

### **Tile Finding:**
```lua
function findTileForVocationAndLevel(vocation, level)
  -- Find tile matching vocation + level
  -- Search in storage area or on board
  -- Returns tile object or nil
end

function findTileOnPlayerBoard(color)
  -- Find tile currently in player's Character slot
  -- Returns tile object or nil
end
```

### **Tile Placement:**
```lua
function placeTileOnBoard(tile, color)
  -- Find player board
  -- Find Character slot
  -- Place tile in slot
  -- Add color tag to tile
end

function removeTileFromBoard(color)
  -- Find tile on player's board
  -- Remove color tag
  -- Move tile to storage area
  -- Return tile object
end
```

### **Tile Swapping:**
```lua
function swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  -- Remove old level tile from board
  local oldTile = removeTileFromBoard(color)
  
  -- Find new level tile
  local newTile = findTileForVocationAndLevel(vocation, newLevel)
  
  -- Place new tile on board
  placeTileOnBoard(newTile, color)
  
  -- Return old tile (for storage)
  return oldTile
end
```

### **Integration with VocationsController:**
```lua
-- In VocationsController.lua, when promotion happens:
function VOC_Promote(params)
  local color = params.color
  local vocation = vocations[color]
  local oldLevel = levels[color]
  local newLevel = oldLevel + 1
  
  -- Update level
  levels[color] = newLevel
  
  -- Swap tile on board
  swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  
  -- Broadcast promotion
  broadcastToAll(color .. " promoted to " .. vocation .. " Level " .. newLevel)
end
```

---

## 🎯 Tile Storage Strategy

### **Option 1: Box Storage (Recommended)**
- All unused tiles stored in a box
- **Advantage:** Tiles don't merge into decks (unlike cards)
- When tile needed: Search box, find matching tile
- When tile removed: Return to box
- **Pros:** Organized, easy to find tiles, no deck merging issues
- **Cons:** Need to search box

### **Option 2: Hidden Zone**
- Unused tiles stored in hidden zone (under table, off-screen)
- When tile needed: Find in hidden zone
- When tile removed: Move to hidden zone
- **Pros:** Fast access, organized, no visual clutter
- **Cons:** Need to maintain hidden zone

### **Option 3: Tag-Based Storage**
- Tiles stored anywhere, identified by tags
- Use `getObjectsWithTag()` to find tiles
- **Pros:** Flexible, no specific storage needed
- **Cons:** May be slower if many objects

### **Option 4: Stacked Storage (Tiles Only!)**
- Tiles can be stacked in a pile (unlike cards, they won't merge)
- When tile needed: Search stack, find matching tile
- **Pros:** Compact, organized, no merging issues
- **Cons:** Need to search through stack

**Recommended:** Option 1 (Box) or Option 4 (Stacked) - Tiles won't merge, so both work well

---

## ✅ Implementation Checklist

### **Tile Setup:**
- [ ] Create/identify 18 vocation tiles (3 levels × 6 vocations)
- [ ] **Type:** Ensure all are Tiles (not Cards) to prevent deck merging
- [ ] Tag all tiles with base tag: `WLB_VOCATION_TILE`
- [ ] Tag tiles with vocation tags (e.g., `WLB_VOC_ENTREPRENEUR`)
- [ ] Tag tiles with level tags (e.g., `WLB_VOC_LEVEL_1`)
- [ ] Store unused tiles in box or stacked area

### **Tile Finding:**
- [ ] Implement `findTileForVocationAndLevel(vocation, level)`
- [ ] Implement `findTileOnPlayerBoard(color)`
- [ ] Test: Can find tiles by vocation + level

### **Tile Placement:**
- [ ] Implement `placeTileOnBoard(tile, color)`
- [ ] Implement `removeTileFromBoard(color)`
- [ ] Test: Can place/remove tiles from Character slot

### **Tile Swapping:**
- [ ] Implement `swapTileOnPromotion(color, vocation, oldLevel, newLevel)`
- [ ] Integrate with VocationsController promotion
- [ ] Test: Tile swaps when player promotes

### **Integration:**
- [ ] Hook into VocationsController `VOC_Promote()` function
- [ ] Test: Promotion triggers tile swap
- [ ] Test: Old tile returns to storage
- [ ] Test: New tile appears on board
- [ ] **Verify:** Tiles don't merge into decks when stacked

---

## 🔧 Technical Details

### **Finding Tiles:**
```lua
function findTileForVocationAndLevel(vocation, level)
  local vocationTag = "WLB_VOC_" .. vocation
  local levelTag = "WLB_VOC_LEVEL_" .. level
  
  -- Search all objects
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj.hasTag and 
       obj.hasTag("WLB_VOCATION_TILE") and
       obj.hasTag(vocationTag) and
       obj.hasTag(levelTag) then
      return obj
    end
  end
  
  return nil
end
```

### **Character Slot Position:**
```lua
function findCharacterSlot(color)
  -- Find player board
  local board = findPlayerBoard(color)
  
  -- Character slot is at specific position on board
  -- (Need to determine exact position from board design)
  local slotPos = {boardPos.x + X_OFFSET, boardPos.y + Y_OFFSET, boardPos.z + Z_OFFSET}
  
  return slotPos
end
```

### **Tile Swapping with Animation:**
```lua
function swapTileOnPromotion(color, vocation, oldLevel, newLevel)
  -- Remove old tile (smooth animation)
  local oldTile = findTileOnPlayerBoard(color)
  if oldTile then
    oldTile.setPositionSmooth(STORAGE_POSITION, false, true)
    Wait.time(function()
      oldTile.removeTag("WLB_COLOR_" .. color)
    end, 0.5)
  end
  
  -- Find and place new tile
  Wait.time(function()
    local newTile = findTileForVocationAndLevel(vocation, newLevel)
    if newTile then
      local slotPos = findCharacterSlot(color)
      newTile.setPositionSmooth(slotPos, false, true)
      newTile.addTag("WLB_COLOR_" .. color)
    end
  end, 0.6)
end
```

---

## ❓ Questions to Resolve

1. **Character Slot Position:**
   - Where exactly is the Character slot on player board?
   - What are the X/Y/Z offsets from board center?

2. **Tile Storage:**
   - Should tiles be in a box or stacked?
   - Where should storage area be located?

3. **Tile Animation:**
   - Should tile swapping be animated (smooth movement)?
   - Or instant (teleport)?

4. **Tile Identification:**
   - How are tiles identified in TTS? By GUID? By name? By tags?
   - Do tiles need custom names (e.g., "ENTREPRENEUR_LEVEL_1")?

5. **Tile Type Verification:**
   - How to ensure tiles are created as "Tile" type (not "Card")?
   - Can we verify tile type programmatically?

---

**Status:** ✅ **TILES CONFIRMED** - Using tiles instead of cards to prevent deck merging  
**Next Action:** Determine Character slot position and tile storage method
