# Vocation Selection UI - Design Proposal

**Status:** DESIGN SPECIFICATION  
**Purpose:** Interactive UI for players to choose their vocation at Adult period start  
**Related:** `VocationsController.lua`, `VOCATION_SUMMARY_TILES_GUIDE.md`

---

## 🎯 User Flow

### **Step 1: Show Selection Cards**
- At Adult period start, show **6 Level 1 vocation tiles** to the current player
- Display them in a visible selection area (e.g., center of table, or near player)
- Each tile represents one vocation

### **Step 2: Click Card → Show Summary**
- Player clicks a Level 1 tile
- System finds and displays the corresponding **Summary Tile** for that vocation
- Summary tile shows all information (all 3 levels + special events)

### **Step 3: Choose or Go Back**
- Summary tile has **"I Choose It"** button at the bottom
- Summary tile has **"Go Back"** button to return to selection
- Player can click another Level 1 tile to view different vocation

### **Step 4: Confirm Selection**
- When player clicks "I Choose It", vocation is set via `VOC_SetVocation()`
- Selection UI is cleaned up (cards returned to storage)
- Next player in selection order gets their turn

---

## 🎨 UI Design Options

### **Option A: Physical Tiles with Buttons (Recommended)**

**Selection Area:**
- 6 Level 1 vocation tiles arranged in a row or grid
- Each tile has a **clickable overlay** or **button** that triggers summary view

**Summary Display:**
- Summary tile is **positioned/zoomed** in front of player
- Buttons added to summary tile:
  - **"I Choose It"** (green, bottom-left)
  - **"Go Back"** (gray, bottom-right)

**Pros:**
- Uses existing physical tiles
- Clear visual feedback
- Players can see all options at once

**Cons:**
- Requires positioning logic
- Buttons on tiles might be small

---

### **Option B: Central Selection Tile with Buttons**

**Selection Tile:**
- One central tile showing "Choose Your Vocation"
- 6 buttons (one per vocation) arranged around it
- Clicking a button shows the summary tile

**Summary Display:**
- Summary tile shown with buttons (same as Option A)

**Pros:**
- Cleaner UI
- Easier button management
- Less positioning needed

**Cons:**
- Requires creating a selection tile
- Less visual (no cards visible)

---

### **Option C: Hybrid (Cards + Central UI)**

**Selection:**
- 6 Level 1 tiles shown (visual)
- Central selection tile with buttons (functional)

**Summary:**
- Summary tile shown with buttons

**Pros:**
- Best of both worlds
- Visual + functional

**Cons:**
- More complex

---

## ✅ Recommended: Option A (Physical Tiles with Buttons)

**Why:**
- Uses existing tiles (no new assets needed)
- Clear visual: players see all 6 options
- Familiar pattern (similar to shop card selection)

---

## 🔧 Implementation Plan

### **Phase 1: Selection Setup**

1. **Function: `VOC_StartSelection(color)`**
   - Finds all 6 Level 1 vocation tiles
   - Positions them in selection area
   - Adds click handlers to each tile
   - Shows selection UI to player

2. **Selection Area Position:**
   - Center of table, or near player's board
   - Arranged in a row or 2×3 grid
   - Elevated slightly (Y + 0.5) for visibility

### **Phase 2: Summary Display**

3. **Function: `VOC_ShowSummary(vocation, color)`**
   - Finds summary tile for vocation
   - Positions it in front of player (or center)
   - Zooms/raises it for visibility
   - Adds buttons: "I Choose It" and "Go Back"

4. **Button Actions:**
   - **"I Choose It"**: Calls `VOC_SetVocation()` → Cleans up UI
   - **"Go Back"**: Hides summary → Returns to selection cards

### **Phase 3: Cleanup**

5. **Function: `VOC_CleanupSelection(color)`**
   - Removes buttons from tiles
   - Returns Level 1 tiles to storage
   - Returns summary tile to reference area
   - Clears any UI elements

---

## 📋 Function Specifications

### **`VOC_StartSelection({color=...})`**

**Purpose:** Start vocation selection for a player

**Parameters:**
- `color` (string): Player color (Yellow, Blue, Red, Green)

**Actions:**
1. Find all 6 Level 1 vocation tiles
2. Position them in selection area
3. Add click handlers (or buttons) to each tile
4. Broadcast message: "Choose your vocation"

**Returns:**
- `true` if successful, `false` if error

---

### **`VOC_ShowSummary({vocation=..., color=...})`**

**Purpose:** Show summary tile for a vocation

**Parameters:**
- `vocation` (string): Vocation name (e.g., "ENTREPRENEUR")
- `color` (string): Player color

**Actions:**
1. Find summary tile for vocation
2. Position it in front of player (or center)
3. Raise it (Y + 1.0) for visibility
4. Add buttons:
   - "I Choose It" → Calls `VOC_ConfirmSelection()`
   - "Go Back" → Calls `VOC_HideSummary()`

**Returns:**
- `true` if successful, `false` if error

---

### **`VOC_ConfirmSelection({vocation=..., color=...})`**

**Purpose:** Confirm vocation selection

**Parameters:**
- `vocation` (string): Vocation name
- `color` (string): Player color

**Actions:**
1. Call `VOC_SetVocation({color=color, vocation=vocation})`
2. Clean up selection UI
3. Broadcast confirmation message

**Returns:**
- Result from `VOC_SetVocation()`

---

### **`VOC_HideSummary({color=...})`**

**Purpose:** Hide summary tile and return to selection

**Parameters:**
- `color` (string): Player color

**Actions:**
1. Remove buttons from summary tile
2. Return summary tile to reference area
3. Show selection cards again (if needed)

**Returns:**
- `true` if successful

---

### **`VOC_CleanupSelection({color=...})`**

**Purpose:** Clean up all selection UI elements

**Parameters:**
- `color` (string): Player color

**Actions:**
1. Remove all buttons from tiles
2. Return Level 1 tiles to storage
3. Return summary tile to reference area
4. Clear any state

**Returns:**
- `true` if successful

---

## 🎯 Button Specifications

### **Selection Tile Buttons (on Level 1 tiles)**

**Button 1: "View Details"**
- **Position:** Center of tile
- **Size:** Medium (width: 800, height: 300)
- **Color:** Blue background, white text
- **Action:** Calls `VOC_ShowSummary({vocation=..., color=...})`

---

### **Summary Tile Buttons**

**Button 1: "I Choose It"**
- **Position:** Bottom-left of tile
- **Size:** Large (width: 1000, height: 400)
- **Color:** Green background (`{0.2, 0.85, 0.25, 1.0}`), black text
- **Action:** Calls `VOC_ConfirmSelection({vocation=..., color=...})`

**Button 2: "Go Back"**
- **Position:** Bottom-right of tile
- **Size:** Large (width: 1000, height: 400)
- **Color:** Gray background (`{0.6, 0.6, 0.6, 1.0}`), white text
- **Action:** Calls `VOC_HideSummary({color=...})`

---

## 📍 Position Constants

### **Selection Area (Center of Table)**
```lua
local SELECTION_AREA = {
  center = {x=0, y=1.0, z=0},  -- Center of table, elevated
  spacing = 2.5,  -- Space between tiles
  layout = "row",  -- or "grid"
}
```

### **Summary Display Position**
```lua
local SUMMARY_POSITION = {
  center = {x=0, y=1.5, z=0},  -- Center, elevated for visibility
  -- OR near player board (calculated per player)
}
```

### **Storage Positions**
```lua
local STORAGE_SELECTION = {x=0, y=5, z=5}  -- Off-screen storage for selection tiles
local STORAGE_SUMMARY = {x=0, y=5, z=6}    -- Off-screen storage for summary tiles
```

---

## 🔄 Selection Flow Diagram

```
1. Adult Period Starts
   ↓
2. Calculate Selection Order (Science Points)
   ↓
3. For Each Player (in order):
   ↓
4. VOC_StartSelection(color)
   → Show 6 Level 1 tiles
   → Add click handlers
   ↓
5. Player Clicks Tile
   ↓
6. VOC_ShowSummary(vocation, color)
   → Show summary tile
   → Add "I Choose It" + "Go Back" buttons
   ↓
7. Player Decision:
   ├─ "I Choose It" → VOC_ConfirmSelection()
   │                    → VOC_SetVocation()
   │                    → Cleanup
   │                    → Next Player
   │
   └─ "Go Back" → VOC_HideSummary()
                  → Return to Step 5
```

---

## 🎮 Integration with Turn Controller

**When to Trigger:**
- At start of Adult period
- After all players have Science Points calculated
- In selection order (highest Science Points first)

**Integration Point:**
- Turn Controller calls `VOC_StartSelection()` for each player
- Waits for selection to complete
- Moves to next player

---

## ✅ Implementation Checklist

### **Core Functions:**
- [ ] `VOC_StartSelection({color=...})`
- [ ] `VOC_ShowSummary({vocation=..., color=...})`
- [ ] `VOC_ConfirmSelection({vocation=..., color=...})`
- [ ] `VOC_HideSummary({color=...})`
- [ ] `VOC_CleanupSelection({color=...})`

### **Helper Functions:**
- [ ] `findAllLevel1Tiles()` - Find all 6 Level 1 vocation tiles
- [ ] `positionSelectionTiles(tiles, area)` - Position tiles in selection area
- [ ] `findSummaryTileForVocation(vocation)` - Find summary tile
- [ ] `addSelectionButtons(tile, vocation, color)` - Add buttons to tile
- [ ] `removeAllButtons(tile)` - Clean up buttons

### **State Tracking:**
- [ ] Track which player is currently selecting
- [ ] Track which summary tile is currently shown
- [ ] Track selection tiles positions (for cleanup)

### **Testing:**
- [ ] Test selection UI appears correctly
- [ ] Test clicking Level 1 tile shows summary
- [ ] Test "I Choose It" confirms selection
- [ ] Test "Go Back" returns to selection
- [ ] Test cleanup removes all UI elements

---

## 💡 Alternative: Simpler Approach

If the full UI is too complex, a simpler approach:

1. **Show 6 Level 1 tiles** in selection area
2. **Player clicks tile** → Vocation is immediately set (no summary view)
3. **Summary tiles remain in reference area** (players can read them manually)

**Pros:**
- Much simpler implementation
- Faster selection
- Less UI complexity

**Cons:**
- Less guided experience
- Players must manually find summary tiles

---

## 🎯 Recommendation

**Start with Simple Approach:**
1. Show 6 Level 1 tiles
2. Add "Choose" button to each tile
3. Clicking button immediately sets vocation
4. Summary tiles remain in reference area for manual reading

**Later Enhancement:**
- Add summary view on click (before choosing)
- Add "Go Back" functionality

This allows you to:
- Get selection working quickly
- Test the flow
- Add polish later

---

**Status:** Ready for implementation  
**Next Action:** Implement `VOC_StartSelection()` and basic selection flow
