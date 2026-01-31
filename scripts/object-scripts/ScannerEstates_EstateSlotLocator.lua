-- =========================================================
-- TOKEN: Estate Slot Locator v3 (NO restrictions)
-- Usage:
--  1) Put token exactly on the Estate slot on a chosen playerboard.
--  2) Choose target board:
--       - AUTO (nearest board among Y/B/R/G), OR
--       - click Y / B / R / G to force target
--  3) Click "PRINT" to output LOCAL offset for MarketEngine.
-- Requires playerboards to have tags:
--   - WLB_BOARD
--   - WLB_COLOR_Yellow / WLB_COLOR_Blue / WLB_COLOR_Red / WLB_COLOR_Green
-- =========================================================

local TAG_BOARD = "WLB_BOARD"
local COLOR_TAG_PREFIX = "WLB_COLOR_"

local COLORS = {"Yellow","Blue","Red","Green"}

local DECIMALS = 3

-- state
local targetMode = "AUTO"      -- "AUTO" or one of COLORS

local function fmt(n)
  local f = "%."..tostring(DECIMALS).."f"
  return string.format(f, tonumber(n) or 0)
end

local function fmtVec(v)
  return "{"..fmt(v.x)..", "..fmt(v.y)..", "..fmt(v.z).."}"
end

local function d2(a,b)
  local dx=a.x-b.x; local dz=a.z-b.z
  return dx*dx + dz*dz
end

local function colorTag(c) return COLOR_TAG_PREFIX .. tostring(c) end

local function boundsArea(o)
  local ok, b = pcall(function() return o.getBoundsNormalized() end)
  if not ok or type(b) ~= "table" or type(b.size) ~= "table" then return 0 end
  local x = tonumber(b.size.x) or 0
  local z = tonumber(b.size.z) or 0
  return x * z
end

local function findBoardForColor(color)
  local list = getObjectsWithTag(colorTag(color)) or {}
  local best, bestArea = nil, -1
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_BOARD) then
      local a = boundsArea(o)
      if a > bestArea then
        bestArea = a
        best = o
      end
    end
  end
  return best
end

local function findNearestBoard()
  local p = self.getPosition()
  local bestColor, bestBoard, bestD = nil, nil, 1e18
  for _,c in ipairs(COLORS) do
    local b = findBoardForColor(c)
    if b and b.getPosition then
      local bp = b.getPosition()
      local dd = d2(p, bp)
      if dd < bestD then
        bestD = dd
        bestColor = c
        bestBoard = b
      end
    end
  end
  return bestColor, bestBoard
end

local function setMode(m)
  targetMode = m
  local label = "MODE: "..tostring(targetMode)
  pcall(function()
    self.editButton({index=0, label=label})
  end)
end

local function ui()
  self.clearButtons()

  -- Button 0: mode display / auto toggle
  self.createButton({
    click_function = "btnAuto",
    function_owner = self,
    label          = "MODE: "..tostring(targetMode).."\n(click=Auto)",
    position       = {0, 0.25, 0.85},
    rotation       = {0, 180, 0},
    width          = 2000,
    height         = 520,
    font_size      = 180,
    color          = {0.15, 0.15, 0.15},
    font_color     = {1, 1, 1},
    tooltip        = "Click to set AUTO mode (nearest board)."
  })

  -- Color selectors
  local x0 = -1.35
  local dx = 0.90
  local i = 0
  for _,c in ipairs(COLORS) do
    i = i + 1
    self.createButton({
      click_function = "btnSet_"..c,
      function_owner = self,
      label          = string.upper(string.sub(c,1,1)),
      position       = {x0 + (i-1)*dx, 0.25, 0.25},
      rotation       = {0, 180, 0},
      width          = 700,
      height         = 420,
      font_size      = 220,
      color          = {0.25,0.25,0.25},
      font_color     = {1,1,1},
      tooltip        = "Force target board = "..c
    })
  end

  -- PRINT button
  self.createButton({
    click_function = "btnPrint",
    function_owner = self,
    label          = "PRINT\nLOCAL",
    position       = {0, 0.25, -0.55},
    rotation       = {0, 180, 0},
    width          = 800,
    height         = 700,
    font_size      = 220,
    color          = {0.10, 0.35, 0.10},
    font_color     = {1, 1, 1},
    tooltip        = "Print LOCAL offset of token relative to chosen board (AUTO or forced)."
  })
end

function onLoad()
  ui()
end

-- === button handlers ===
function btnAuto() setMode("AUTO") end
function btnSet_Yellow() setMode("Yellow") end
function btnSet_Blue()   setMode("Blue") end
function btnSet_Red()    setMode("Red") end
function btnSet_Green()  setMode("Green") end

function btnPrint(_, playerColor, _)
  local tokenWorld = self.getPosition()

  local chosenColor, board
  if targetMode == "AUTO" then
    chosenColor, board = findNearestBoard()
  else
    chosenColor = targetMode
    board = findBoardForColor(chosenColor)
  end

  if not chosenColor or not board or not board.positionToLocal then
    local msg = "Board NOT FOUND. Need tags: "..TAG_BOARD.." + "..COLOR_TAG_PREFIX.."<Color>."
    print(msg)
    broadcastToAll(msg, {1,0.4,0.4})
    return
  end

  local boardWorld = board.getPosition()
  local localPos   = board.positionToLocal(tokenWorld)
  local worldBack  = board.positionToWorld(localPos)

  local dx = worldBack.x - tokenWorld.x
  local dy = worldBack.y - tokenWorld.y
  local dz = worldBack.z - tokenWorld.z
  local err = math.sqrt(dx*dx + dy*dy + dz*dz)

  local lines = {}
  table.insert(lines, "=== ESTATE SLOT LOCATOR v3 ===")
  table.insert(lines, "CLICKED BY: "..tostring(playerColor or "nil").." | MODE: "..tostring(targetMode))
  table.insert(lines, "TARGET: "..tostring(chosenColor))
  table.insert(lines, "BOARD: "..(board.getName() ~= "" and board.getName() or board.getGUID()).." ("..board.getGUID()..")")
  table.insert(lines, "TOKEN WORLD = "..fmtVec(tokenWorld))
  table.insert(lines, "BOARD WORLD = "..fmtVec(boardWorld))
  table.insert(lines, "LOCAL@BOARD = "..fmtVec(localPos))
  table.insert(lines, "WORLD(check) = "..fmtVec(worldBack).." | ERR="..string.format("%.6f", err))
  table.insert(lines, "")
  table.insert(lines, "PASTE INTO MARKETENGINE:")
  table.insert(lines, "  "..chosenColor.." = {x="..fmt(localPos.x)..", y="..fmt(localPos.y)..", z="..fmt(localPos.z).."},")
  local msg = table.concat(lines, "\n")

  print(msg)
  broadcastToAll(msg, {1,1,1})
  Wait.time(function() broadcastToAll(msg, {1,1,1}) end, 1)
end
