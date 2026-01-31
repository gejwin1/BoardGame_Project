-- =========================================================
-- WLB VOCATION TILE SCANNER v1.0.0
-- Purpose: Measure Character slot position on player boards for vocation tiles
-- Usage:
--  1) Place scanner tile exactly on Character slot on a player board
--  2) Choose target board color (Y/B/R/G) or AUTO (nearest)
--  3) Click "MEASURE" to capture local position
--  4) Click "EXPORT" to get code for VocationsController
--  5) Use TEST buttons to test tile placement/removal
-- =========================================================

local DEBUG = true
local VERSION = "1.0.0"

local TAG_BOARD = "WLB_BOARD"
local TAG_VOCATION_TILE = "WLB_VOCATION_TILE"
local COLOR_TAG_PREFIX = "WLB_COLOR_"

local COLORS = {"Yellow","Blue","Red","Green"}
local DECIMALS = 3

-- Storage position for tiles (when not on board)
local STORAGE_POSITION = {0, 5, 0}  -- Off-screen, adjust as needed

-- State
local targetColor = "AUTO"  -- "AUTO" or one of COLORS
local measuredPositions = {
  Yellow = nil,
  Blue = nil,
  Red = nil,
  Green = nil,
}

-- =========================================================
-- UTILS
-- =========================================================

local function log(msg)
  if DEBUG then print("[VOC_SCANNER] " .. tostring(msg)) end
end

local function fmt(n)
  local f = "%."..tostring(DECIMALS).."f"
  return string.format(f, tonumber(n) or 0)
end

local function fmtVec(v)
  return "{"..fmt(v.x)..", "..fmt(v.y)..", "..fmt(v.z).."}"
end

local function colorTag(c)
  return COLOR_TAG_PREFIX .. tostring(c)
end

local function d2(a, b)
  local dx = a.x - b.x
  local dz = a.z - b.z
  return dx*dx + dz*dz
end

-- =========================================================
-- BOARD FINDING
-- =========================================================

local function findBoardForColor(color)
  local list = getObjectsWithTag(colorTag(color)) or {}
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_BOARD) then
      return o
    end
  end
  return nil
end

local function findNearestBoard()
  local scannerPos = self.getPosition()
  local bestColor, bestBoard, bestD = nil, nil, 1e18
  
  for _, c in ipairs(COLORS) do
    local b = findBoardForColor(c)
    if b and b.getPosition then
      local bp = b.getPosition()
      local dd = d2(scannerPos, bp)
      if dd < bestD then
        bestD = dd
        bestColor = c
        bestBoard = b
      end
    end
  end
  
  return bestColor, bestBoard
end

-- =========================================================
-- MEASUREMENT
-- =========================================================

local function measurePosition(color)
  local board = findBoardForColor(color)
  if not board then
    broadcastToAll("❌ Board not found for " .. color, {1, 0.3, 0.3})
    return false
  end
  
  local scannerWorld = self.getPosition()
  local boardWorld = board.getPosition()
  
  -- Convert to local coordinates
  local localPos = board.positionToLocal(scannerWorld)
  
  -- Validate (convert back to world and check error)
  local checkWorld = board.positionToWorld(localPos)
  local error = math.sqrt(d2(scannerWorld, checkWorld))
  
  -- Store measurement
  measuredPositions[color] = {
    x = localPos.x,
    y = localPos.y,
    z = localPos.z
  }
  
  log("Measured " .. color .. ": " .. fmtVec(measuredPositions[color]) .. " (error: " .. fmt(error) .. ")")
  
  broadcastToAll("✅ Measured " .. color .. " Character slot", {0.3, 1, 0.3})
  return true
end

-- =========================================================
-- TILE TESTING
-- =========================================================

local function findVocationTileForColor(color)
  local colorTag = colorTag(color)
  local allObjects = getAllObjects()
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and
       obj.hasTag(TAG_VOCATION_TILE) and
       obj.hasTag(colorTag) then
      return obj
    end
  end
  
  return nil
end

local function findAnyVocationTile()
  local allObjects = getAllObjects()
  
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and obj.hasTag(TAG_VOCATION_TILE) then
      -- Check if it's not on any board (no color tag)
      local hasColorTag = false
      for _, c in ipairs(COLORS) do
        if obj.hasTag(colorTag(c)) then
          hasColorTag = true
          break
        end
      end
      
      if not hasColorTag then
        return obj
      end
    end
  end
  
  return nil
end

local function testPlaceTile(color)
  if not measuredPositions[color] then
    broadcastToAll("❌ No measurement for " .. color .. " - measure first!", {1, 0.3, 0.3})
    return
  end
  
  local board = findBoardForColor(color)
  if not board then
    broadcastToAll("❌ Board not found for " .. color, {1, 0.3, 0.3})
    return
  end
  
  -- Find a vocation tile (prefer one not on any board)
  local tile = findAnyVocationTile()
  if not tile then
    broadcastToAll("❌ No vocation tile found (tag: " .. TAG_VOCATION_TILE .. ")", {1, 0.3, 0.3})
    return
  end
  
  -- Calculate world position
  local localPos = measuredPositions[color]
  local worldPos = board.positionToWorld(localPos)
  
  -- Place tile
  tile.setPositionSmooth(worldPos, false, true)
  
  -- Add color tag
  tile.addTag(colorTag(color))
  
  broadcastToAll("✅ Test: Placed tile on " .. color .. " board", {0.3, 1, 0.3})
end

local function testRemoveTile(color)
  local tile = findVocationTileForColor(color)
  if not tile then
    broadcastToAll("❌ No tile found on " .. color .. " board", {1, 0.3, 0.3})
    return
  end
  
  -- Remove color tag
  tile.removeTag(colorTag(color))
  
  -- Move to storage
  tile.setPositionSmooth(STORAGE_POSITION, false, true)
  
  broadcastToAll("✅ Test: Removed tile from " .. color .. " board", {0.3, 1, 0.3})
end

-- =========================================================
-- UI
-- =========================================================

local function updateButtons()
  -- Mode button (shows current target)
  local modeLabel = "MODE: " .. targetColor
  pcall(function()
    self.editButton({index=0, label=modeLabel})
  end)
end

function onLoad()
  self.clearButtons()
  
  -- Button 0: Mode (AUTO toggle)
  self.createButton({
    index=0,
    click_function="btnMode",
    function_owner=self,
    label="MODE: "..targetColor.."\n(click=Auto)",
    position={0, 0.25, 0.85},
    rotation={0, 180, 0},
    width=2000,
    height=520,
    font_size=180,
    color={0.2, 0.2, 0.2},
    font_color={1, 1, 1},
    tooltip="Click to toggle AUTO mode"
  })
  
  -- Buttons 1-4: Color selection (Y/B/R/G)
  local colorButtons = {
    {index=1, color="Yellow", pos={-0.75, 0.25, 0.35}, rgb={1, 1, 0.2}},
    {index=2, color="Blue", pos={0.75, 0.25, 0.35}, rgb={0.2, 0.5, 1}},
    {index=3, color="Red", pos={-0.75, 0.25, -0.15}, rgb={1, 0.2, 0.2}},
    {index=4, color="Green", pos={0.75, 0.25, -0.15}, rgb={0.2, 1, 0.2}},
  }
  
  for _, btn in ipairs(colorButtons) do
    self.createButton({
      index=btn.index,
      click_function="btnColor",
      function_owner=self,
      label=btn.color:sub(1,1),
      position=btn.pos,
      rotation={0, 180, 0},
      width=800,
      height=800,
      font_size=300,
      color=btn.rgb,
      font_color={0, 0, 0},
      tooltip="Select " .. btn.color .. " board"
    })
  end
  
  -- Button 5: MEASURE
  self.createButton({
    index=5,
    click_function="btnMeasure",
    function_owner=self,
    label="MEASURE",
    position={0, 0.25, -0.65},
    rotation={0, 180, 0},
    width=2000,
    height=600,
    font_size=250,
    color={0.1, 0.5, 0.1},
    font_color={1, 1, 1},
    tooltip="Measure Character slot position for selected color"
  })
  
  -- Button 6: EXPORT
  self.createButton({
    index=6,
    click_function="btnExport",
    function_owner=self,
    label="EXPORT",
    position={0, 0.25, -1.35},
    rotation={0, 180, 0},
    width=2000,
    height=500,
    font_size=220,
    color={0.1, 0.2, 0.5},
    font_color={1, 1, 1},
    tooltip="Export code for VocationsController"
  })
  
  -- Buttons 7-10: TEST PLACE (Y/B/R/G)
  for i, btn in ipairs(colorButtons) do
    self.createButton({
      index=6 + btn.index,
      click_function="btnTestPlace",
      function_owner=self,
      label="TEST\nPLACE\n"..btn.color:sub(1,1),
      position={btn.pos[1], btn.pos[2], btn.pos[3] - 0.6},
      rotation={0, 180, 0},
      width=700,
      height=400,
      font_size=120,
      color={0.2, 0.7, 0.2},
      font_color={1, 1, 1},
      tooltip="Test: Place tile on " .. btn.color .. " board"
    })
  end
  
  -- Buttons 11-14: TEST REMOVE (Y/B/R/G)
  for i, btn in ipairs(colorButtons) do
    self.createButton({
      index=10 + btn.index,
      click_function="btnTestRemove",
      function_owner=self,
      label="TEST\nREMOVE\n"..btn.color:sub(1,1),
      position={btn.pos[1], btn.pos[2], btn.pos[3] - 1.0},
      rotation={0, 180, 0},
      width=700,
      height=400,
      font_size=120,
      color={0.7, 0.2, 0.2},
      font_color={1, 1, 1},
      tooltip="Test: Remove tile from " .. btn.color .. " board"
    })
  end
end

-- =========================================================
-- BUTTON HANDLERS
-- =========================================================

function btnMode()
  if targetColor == "AUTO" then
    targetColor = COLORS[1]
  else
    local idx = 1
    for i, c in ipairs(COLORS) do
      if c == targetColor then
        idx = i + 1
        if idx > #COLORS then idx = 1 end
        break
      end
    end
    targetColor = COLORS[idx]
  end
  updateButtons()
end

function btnColor(obj, _, alt_click, buttonIndex)
  -- Extract color from button index (1=Yellow, 2=Blue, 3=Red, 4=Green)
  local colorMap = {[1]="Yellow", [2]="Blue", [3]="Red", [4]="Green"}
  local color = colorMap[buttonIndex] or "Yellow"
  
  if alt_click then
    -- Alt-click: Toggle AUTO
    targetColor = "AUTO"
  else
    -- Normal click: Set color
    targetColor = color
  end
  
  updateButtons()
end

function btnMeasure()
  local color = targetColor
  
  if color == "AUTO" then
    color, _ = findNearestBoard()
    if not color then
      broadcastToAll("❌ No board found nearby", {1, 0.3, 0.3})
      return
    end
    broadcastToAll("Auto-detected: " .. color, {0.5, 0.5, 1})
  end
  
  measurePosition(color)
end

function btnExport()
  local lines = {}
  table.insert(lines, "-- === VOCATION CHARACTER SLOT POSITIONS ===")
  table.insert(lines, "-- Generated by Vocation Tile Scanner v" .. VERSION)
  table.insert(lines, "-- Copy this into VocationsController.lua")
  table.insert(lines, "")
  table.insert(lines, "local CHARACTER_SLOT_LOCAL = {")
  
  for _, c in ipairs(COLORS) do
    local pos = measuredPositions[c]
    if pos then
      table.insert(lines, "  " .. c .. " = " .. fmtVec(pos) .. ",")
    else
      table.insert(lines, "  " .. c .. " = nil,  -- NOT MEASURED")
    end
  end
  
  table.insert(lines, "}")
  table.insert(lines, "")
  
  local output = table.concat(lines, "\n")
  print(output)
  broadcastToAll("✅ Exported to console! Check TTS console log.", {0.3, 1, 0.3})
end

function btnTestPlace(obj, _, alt_click, buttonIndex)
  -- Extract color from button index (7=Yellow, 8=Blue, 9=Red, 10=Green)
  local idx = buttonIndex - 6
  local colorMap = {[1]="Yellow", [2]="Blue", [3]="Red", [4]="Green"}
  local color = colorMap[idx] or "Yellow"
  
  testPlaceTile(color)
end

function btnTestRemove(obj, _, alt_click, buttonIndex)
  -- Extract color from button index (11=Yellow, 12=Blue, 13=Red, 14=Green)
  local idx = buttonIndex - 10
  local colorMap = {[1]="Yellow", [2]="Blue", [3]="Red", [4]="Green"}
  local color = colorMap[idx] or "Yellow"
  
  testRemoveTile(color)
end
