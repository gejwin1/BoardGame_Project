# Vocation Selection UI - Alternative Solutions

**Problem:** Physical tiles disappearing/moving off-screen  
**Solution:** Button-based UI on controller (no physical tile movement)

---

## 🎯 Recommended Solution: Button-Based Selection UI

Instead of moving physical tiles, create **buttons on the VocationsController tile itself** that show all 6 vocations. This is:
- ✅ **More reliable** - No risk of tiles disappearing
- ✅ **Works for all players** - Same UI for everyone
- ✅ **Cleaner** - No physical objects to manage
- ✅ **Faster** - Instant display, no positioning delays

---

## 📋 Implementation Options

### **Option A: Simple Button Grid (Recommended)**

**Layout on VocationsController tile:**
```
┌─────────────────────────────────────────┐
│     Choose Your Vocation                │
│                                         │
│  [Public Servant]  [Celebrity]         │
│  [Social Worker]   [Gangster]          │
│  [Entrepreneur]    [NGO Worker]         │
└─────────────────────────────────────────┘
```

**How it works:**
1. When selection starts, VocationsController shows 6 buttons (one per vocation)
2. Each button shows vocation name
3. Player clicks button → Summary tile appears (or shows details)
4. Player confirms → Vocation set

**Pros:**
- Simple and reliable
- No physical objects to manage
- Works for all 4 players
- Easy to implement

**Cons:**
- Less visual (no physical cards)
- Requires controller tile to be visible

---

### **Option B: Button Grid + Summary Display**

Same as Option A, but when player clicks a vocation button:
1. Summary tile appears in center (elevated)
2. Shows "I Choose It" and "Go Back" buttons
3. Player confirms or goes back

**Pros:**
- Visual summary tile for reference
- Clear confirmation step
- Can still see summary details

**Cons:**
- Still uses summary tile (but only one, not six)

---

### **Option C: Two-Step Selection**

1. **Step 1:** Controller shows 6 buttons (vocation names)
2. **Step 2:** Player clicks → Controller shows detailed info + "Choose" button
3. **Step 3:** Player confirms

**Pros:**
- All info on controller (no summary tile needed)
- Very clean
- Fast selection

**Cons:**
- Less visual reference
- Requires more button management

---

## 🛠️ Implementation Plan (Option A - Recommended)

### **Step 1: Create Selection UI Function**

```lua
function VOC_ShowSelectionUI(color)
  -- Clear existing buttons
  self.clearButtons()
  
  -- Title
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = "Choose Your Vocation",
    position = {0, 0.3, 1.2},
    width = 2000,
    height = 400,
    font_size = 200,
    color = {0.1, 0.1, 0.1, 1},
    font_color = {1, 1, 1, 1}
  })
  
  -- 6 Vocation buttons in 2x3 grid
  local vocations = {
    {name="Public Servant", id="PUBLIC_SERVANT", pos={-1.2, 0.3, 0.3}},
    {name="Celebrity", id="CELEBRITY", pos={1.2, 0.3, 0.3}},
    {name="Social Worker", id="SOCIAL_WORKER", pos={-1.2, 0.3, -0.3}},
    {name="Gangster", id="GANGSTER", pos={1.2, 0.3, -0.3}},
    {name="Entrepreneur", id="ENTREPRENEUR", pos={-1.2, 0.3, -0.9}},
    {name="NGO Worker", id="NGO_WORKER", pos={1.2, 0.3, -0.9}},
  }
  
  for _, voc in ipairs(vocations) do
    -- Check if already taken
    local isTaken = false
    for _, c in ipairs(COLORS) do
      if state.vocations[c] == voc.id then
        isTaken = true
        break
      end
    end
    
    if not isTaken then
      self.createButton({
        click_function = "VOC_ButtonSelectVocation",
        function_owner = self,
        label = voc.name,
        position = voc.pos,
        width = 1000,
        height = 400,
        font_size = 150,
        color = {0.2, 0.5, 1.0, 1},
        font_color = {1, 1, 1, 1},
        tooltip = "Click to view details and choose"
      })
    end
  end
end
```

### **Step 2: Handle Button Clicks**

```lua
function VOC_ButtonSelectVocation(obj, color, alt_click)
  -- Get vocation from button label or stored state
  -- Show summary tile
  -- Add "I Choose It" button
end
```

---

## 🔄 Recovery Function (For Lost Tiles)

Add this function to recover tiles that disappeared:

```lua
function VOC_RecoverTiles()
  -- Find all Level 1 tiles
  local tiles = findAllLevel1Tiles()
  
  -- Move them to visible center position
  local center = {x=0, y=2.0, z=0}
  local spacing = 3.0
  local startX = center.x - (spacing * (#tiles - 1) / 2)
  
  for i, tile in ipairs(tiles) do
    if tile then
      tile.setLock(false)
      local pos = {
        x = startX + (i - 1) * spacing,
        y = center.y,
        z = center.z
      }
      tile.setPositionSmooth(pos, false, true)
      log("Recovered tile " .. i .. " to " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
    end
  end
  
  broadcastToAll("Recovered " .. #tiles .. " vocation tiles to center", {0.7, 1, 0.7})
end
```

---

## ✅ Recommended Approach

**Use Option A (Button Grid on Controller):**

1. **No physical tile movement** - Tiles stay where they are
2. **Buttons on controller** - 6 buttons, one per vocation
3. **Click button** → Show summary tile (if needed) or directly confirm
4. **Works for all players** - Same UI, no positioning issues

This is the most reliable solution and works perfectly for 4 players.

---

**Status:** Ready to implement  
**Next Step:** Replace tile movement with button-based UI
