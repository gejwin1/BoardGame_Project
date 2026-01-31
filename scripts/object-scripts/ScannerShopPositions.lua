-- =========================================================
-- TOKEN: Shop Slot Locator v1 (LOCAL@SHOPBOARD, no Zones)
-- Buttons:
--  - Row:  C / H / I
--  - Slot: C (Closed) / O1 / O2 / O3
--  - PRINT -> outputs LOCAL@SHOPBOARD + paste line
--
-- Requires ShopsBoard (anchor) to have tag:
--   - WLB_SHOP_BOARD
-- =========================================================

local TAG_SHOP_BOARD = "WLB_SHOP_BOARD"
local DECIMALS = 3

-- selection state
local selRow  = "C"   -- C / H / I
local selSlot = "C"   -- C / O1 / O2 / O3

local function fmt(n)
  local f = "%."..tostring(DECIMALS).."f"
  return string.format(f, tonumber(n) or 0)
end

local function fmtVec(v)
  return "{"..fmt(v.x)..", "..fmt(v.y)..", "..fmt(v.z).."}"
end

local function setRow(r)
  selRow = r
  refreshHeader()
end

local function setSlot(s)
  selSlot = s
  refreshHeader()
end

local function keyName()
  -- Friendly key used in paste line
  if selSlot == "C" then
    return "closed"
  end
  if selSlot == "O1" then return "open1" end
  if selSlot == "O2" then return "open2" end
  if selSlot == "O3" then return "open3" end
  return "unknown"
end

local function rowName()
  if selRow == "C" then return "CONSUMABLES" end
  if selRow == "H" then return "HITECH" end
  if selRow == "I" then return "INVEST" end
  return "UNKNOWN"
end

local function findShopBoard()
  local list = getObjectsWithTag(TAG_SHOP_BOARD) or {}
  if #list == 0 then return nil end

  -- Choose the largest surface-like object (same pattern as your playerboard finder)
  local best, bestArea = nil, -1
  for _,o in ipairs(list) do
    if o and o.getBoundsNormalized then
      local ok, b = pcall(function() return o.getBoundsNormalized() end)
      if ok and type(b)=="table" and type(b.size)=="table" then
        local x = tonumber(b.size.x) or 0
        local z = tonumber(b.size.z) or 0
        local area = x*z
        if area > bestArea then
          bestArea = area
          best = o
        end
      end
    end
  end
  return best
end

-- UI helpers
function refreshHeader()
  -- button index 0 is header
  local label = "ROW: "..selRow.." ("..rowName()..")\nSLOT: "..selSlot.." ("..keyName()..")"
  pcall(function()
    self.editButton({index=0, label=label})
  end)
end

local function btn(label, fn, x, z, w, h, fs, col, fcol, tip)
  self.createButton({
    click_function = fn,
    function_owner = self,
    label          = label,
    position       = {x, 0.25, z},
    rotation       = {0, 180, 0},
    width          = w,
    height         = h,
    font_size      = fs,
    color          = col or {0.25,0.25,0.25},
    font_color     = fcol or {1,1,1},
    tooltip        = tip or ""
  })
end

local function ui()
  self.clearButtons()

  -- Header
  btn("ROW: "..selRow.." ("..rowName()..")\nSLOT: "..selSlot.." ("..keyName()..")",
      "noop", 0, 1.05, 2600, 520, 170, {0.12,0.12,0.12}, {1,1,1},
      "Select row and slot, then PRINT.")

  -- Row selectors: C / H / I
  btn("C", "btnRowC", -1.25, 0.35, 750, 450, 240, {0.20,0.20,0.20}, {1,1,1}, "Row = Consumables")
  btn("H", "btnRowH",  0.00, 0.35, 750, 450, 240, {0.20,0.20,0.20}, {1,1,1}, "Row = Hi-Tech")
  btn("I", "btnRowI",  1.25, 0.35, 750, 450, 240, {0.20,0.20,0.20}, {1,1,1}, "Row = Investments")

  -- Slot selectors: C / O1 / O2 / O3
  btn("C",  "btnSlotC",  -1.35, -0.30, 620, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Slot = CLOSED (dark)")
  btn("O1", "btnSlotO1", -0.45, -0.30, 620, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Slot = OPEN 1")
  btn("O2", "btnSlotO2",  0.45, -0.30, 620, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Slot = OPEN 2")
  btn("O3", "btnSlotO3",  1.35, -0.30, 620, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Slot = OPEN 3")

  -- PRINT
  btn("PRINT\nLOCAL", "btnPrint", 0, -1.00, 1100, 720, 230, {0.10, 0.35, 0.10}, {1,1,1},
      "Print LOCAL@SHOPBOARD for the token position.")
end

function onLoad()
  ui()
  refreshHeader()
end

-- ========= button handlers =========
function noop() end

function btnRowC() setRow("C") end
function btnRowH() setRow("H") end
function btnRowI() setRow("I") end

function btnSlotC()  setSlot("C")  end
function btnSlotO1() setSlot("O1") end
function btnSlotO2() setSlot("O2") end
function btnSlotO3() setSlot("O3") end

function btnPrint(_, playerColor, _)
  local tokenWorld = self.getPosition()
  local board = findShopBoard()

  if not board or not board.positionToLocal or not board.positionToWorld then
    local msg = "SHOP BOARD NOT FOUND. Add tag '"..TAG_SHOP_BOARD.."' to ShopsBoard anchor object."
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

  local row = rowName()
  local key = keyName()

  local lines = {}
  table.insert(lines, "=== SHOP SLOT LOCATOR v1 ===")
  table.insert(lines, "CLICKED BY: "..tostring(playerColor or "nil"))
  table.insert(lines, "ROW="..selRow.." ("..row..") | SLOT="..selSlot.." ("..key..")")
  table.insert(lines, "SHOPBOARD: "..(board.getName() ~= "" and board.getName() or board.getGUID()).." ("..board.getGUID()..")")
  table.insert(lines, "TOKEN WORLD = "..fmtVec(tokenWorld))
  table.insert(lines, "BOARD WORLD = "..fmtVec(boardWorld))
  table.insert(lines, "LOCAL@SHOPBOARD = "..fmtVec(localPos))
  table.insert(lines, "WORLD(check) = "..fmtVec(worldBack).." | ERR="..string.format("%.6f", err))
  table.insert(lines, "")
  table.insert(lines, "PASTE LINE:")
  table.insert(lines, "  "..row.."."..key.." = {x="..fmt(localPos.x)..", y="..fmt(localPos.y)..", z="..fmt(localPos.z).."},")
  local msg = table.concat(lines, "\n")

  print(msg)
  broadcastToAll(msg, {1,1,1})
  Wait.time(function() broadcastToAll(msg, {1,1,1}) end, 1)
end
