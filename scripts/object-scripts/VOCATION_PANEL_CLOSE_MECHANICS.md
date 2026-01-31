# Vocation Panel - Close Mechanics Implementation Guide

**Status:** DESIGN SPECIFICATION  
**Purpose:** Document how to implement "click outside to close" for Vocation Panel  
**Related:** `VOCATION_CARDS_UX_ANALYSIS.md`, `VOCATIONS_IMPLEMENTATION_ROADMAP.md`

---

## 🎯 User Requirement

**Desired Behavior:**
- Player clicks vocation card → Panel opens
- Player clicks "Close" button OR clicks outside panel → Panel closes
- Card remains on board, ready to click again

---

## 💡 Implementation Options

### **Option 1: Close Button Only (Simplest, Recommended)**

**Implementation:**
- Large, prominent "Close" button on panel
- Always visible, easy to find
- Most reliable method

**Pros:**
- ✅ Simple to implement
- ✅ Clear user intent
- ✅ Works 100% of the time
- ✅ No edge cases

**Cons:**
- ⚠️ Requires explicit click (not "click anywhere")

**Code Example:**
```lua
-- In VocationPanel.lua
function onCloseButton()
  closePanel()
end

-- Button creation
panel.createButton({
  label = "CLOSE",
  click_function = "onCloseButton",
  function_owner = self,
  position = {0, 0.1, -1.5},  -- Bottom of panel
  width = 1200,
  height = 300,
  font_size = 120,
  color = {0.8, 0.2, 0.2, 0.95},
  font_color = {1, 1, 1, 1}
})
```

---

### **Option 2: Click Outside Detection (More Complex)**

**Implementation:**
- Monitor for clicks on table/other objects
- If click is NOT on panel → Close panel
- Requires global click tracking

**Pros:**
- ✅ More intuitive (click anywhere to close)
- ✅ Matches common UI patterns

**Cons:**
- ❌ More complex to implement
- ❌ May close accidentally when clicking action buttons
- ❌ Requires careful click detection logic
- ❌ Edge cases (clicking on cards, other objects)

**Code Example:**
```lua
-- In VocationPanel.lua
local panelOpen = { Yellow=false, Blue=false, Red=false, Green=false }

function onObjectClick(obj, player_color)
  -- If panel is open for this player
  if panelOpen[player_color] then
    -- Check if click was on panel itself
    if obj.getGUID() == panelGUID then
      return  -- Click was on panel, don't close
    end
    
    -- Click was outside panel → close it
    if obj.hasTag("WLB_VOCATION_PANEL") == false then
      closePanel(player_color)
    end
  end
end
```

**Note:** This requires global click detection, which may not be available in TTS. Alternative: Use a large invisible "backdrop" button behind the panel.

---

### **Option 3: Hybrid Approach (Best UX)**

**Implementation:**
- Close button always available (primary method)
- Large invisible backdrop behind panel (secondary method)
- Click backdrop → Close panel

**Pros:**
- ✅ Close button for explicit close
- ✅ Click backdrop for intuitive close
- ✅ Best of both worlds

**Cons:**
- ⚠️ Requires backdrop button (invisible, covers area)

**Code Example:**
```lua
-- In VocationPanel.lua
function createCloseBackdrop()
  -- Large invisible button behind panel
  panel.createButton({
    label = "",
    click_function = "onBackdropClick",
    function_owner = self,
    position = {0, -0.5, 0},  -- Behind panel
    width = 5000,  -- Large area
    height = 5000,
    font_size = 1,
    color = {0, 0, 0, 0},  -- Invisible
    font_color = {0, 0, 0, 0}
  })
end

function onBackdropClick()
  closePanel()
end
```

---

## 🎯 Recommended Implementation

### **Start with Option 1 (Close Button Only)**

**Why:**
1. **Simplest:** Easiest to implement and test
2. **Reliable:** Works 100% of the time
3. **Clear:** User knows exactly how to close
4. **Fast:** Can implement quickly and move on

**Later Enhancement:**
- If users request "click outside" behavior, add Option 3 (backdrop)
- Keep close button as primary method
- Add backdrop as convenience feature

---

## 📋 Implementation Checklist

### **VocationCard.lua:**
- [ ] Display current vocation name + level on card
- [ ] Click handler: Opens panel (if not already open)
- [ ] Query VocationsController for current state
- [ ] Update display when vocation/level changes

### **VocationPanel.lua:**
- [ ] Spawn/position panel above player board
- [ ] Query VocationsController on open
- [ ] Display all vocation information
- [ ] **"Close" button** (prominent, always visible)
- [ ] Close handler: Hides/destroys panel
- [ ] State tracking: `panelOpen[color]` to prevent duplicates
- [ ] (Optional) Backdrop button for click-outside

### **State Management:**
- [ ] Track which panels are open: `panelOpen[color] = true/false`
- [ ] Prevent opening multiple panels for same player
- [ ] On close: Reset state, card becomes clickable again

---

## 🔧 Technical Details

### **Panel Spawning:**
```lua
function openPanel(color, vocationData)
  -- Check if already open
  if panelOpen[color] then
    return  -- Already open, don't spawn again
  end
  
  -- Find player board
  local board = findPlayerBoard(color)
  local boardPos = board.getPosition()
  
  -- Position above board
  local panelPos = {boardPos.x, boardPos.y + 3, boardPos.z}
  
  -- Spawn or show panel
  panel.setPositionSmooth(panelPos, false, true)
  panelOpen[color] = true
  
  -- Update display
  updateDisplay(vocationData)
end
```

### **Panel Closing:**
```lua
function closePanel(color)
  if not panelOpen[color] then
    return  -- Not open, nothing to close
  end
  
  -- Hide or destroy panel
  panel.setPositionSmooth({0, -10, 0}, false, true)  -- Move off-screen
  -- OR: panel.destroy()  -- If using spawn/destroy pattern
  
  -- Reset state
  panelOpen[color] = false
end
```

### **Card Click Handler:**
```lua
function onCardClick()
  local color = getPlayerColor()  -- Or from card's color tag
  
  if panelOpen[color] then
    -- Panel already open → close it
    closePanel(color)
  else
    -- Panel not open → open it
    local vocationData = queryVocationsController(color)
    openPanel(color, vocationData)
  end
end
```

---

## ✅ Testing Checklist

- [ ] Click card → Panel opens
- [ ] Panel displays correct vocation info
- [ ] Click "Close" button → Panel closes
- [ ] Card remains on board after close
- [ ] Click card again → Panel opens again
- [ ] Only one panel per player (no duplicates)
- [ ] Panel updates if vocation changes while open
- [ ] (If backdrop) Click backdrop → Panel closes

---

**Status:** Ready for implementation  
**Recommended:** Start with Close Button only, add backdrop later if needed
