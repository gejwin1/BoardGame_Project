-- =========================================================
-- TILE: Event Track Locator v1 (LOCAL@EVENT_BOARD, no Zones)
-- Usage:
--  1) Move this tile exactly onto the desired point on the Event Track.
--  2) Choose TARGET: DECK / USED / S1..S7
--  3) Click PRINT -> outputs LOCAL@EVENT_BOARD (paste line)
--
-- Anchor:
--  - Event Board GUID must be set below (default from your GLOBAL: d031d9)
-- =========================================================

local EVENT_BOARD_GUID = "d031d9"  -- <-- your Event Board anchor
local DECIMALS = 3

-- selection state
local target = "DECK" -- "DECK" / "USED" / "S1".."S7"

local function fmt(n)
  local f = "%."..tostring(DECIMALS).."f"
  return string.format(f, tonumber(n) or 0)
end

local function fmtVec(v)
  return "{"..fmt(v.x)..", "..fmt(v.y)..", "..fmt(v.z).."}"
end

local function obj(guid)
  if not guid or guid=="" then return nil end
  return getObjectFromGUID(guid)
end

local function board()
  return obj(EVENT_BOARD_GUID)
end

local function setTarget(t)
  target = t
  refreshHeader()
end

function refreshHeader()
  local label = "TARGET: "..tostring(target).."\nPRINT -> LOCAL@EVENT_BOARD"
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
  btn("TARGET: "..tostring(target).."\nPRINT -> LOCAL@EVENT_BOARD",
      "noop", 0, 1.30, 3200, 520, 170, {0.12,0.12,0.12}, {1,1,1},
      "Move tile to point, select target, then PRINT.")

  -- Row 1: DECK / USED
  btn("DECK", "btnDeck", -0.95, 0.55, 1500, 480, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Deck position")
  btn("USED", "btnUsed",  0.95, 0.55, 1500, 480, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Used pile position")

  -- Row 2: S1..S4
  btn("S1", "btnS1", -1.35, -0.05, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 1")
  btn("S2", "btnS2", -0.45, -0.05, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 2")
  btn("S3", "btnS3",  0.45, -0.05, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 3")
  btn("S4", "btnS4",  1.35, -0.05, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 4")

  -- Row 3: S5..S7
  btn("S5", "btnS5", -0.90, -0.55, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 5")
  btn("S6", "btnS6",  0.00, -0.55, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 6")
  btn("S7", "btnS7",  0.90, -0.55, 700, 420, 220, {0.22,0.22,0.22}, {1,1,1}, "Target = Slot 7")

  -- PRINT
  btn("PRINT\nLOCAL", "btnPrint", 0, -1.20, 1400, 720, 230, {0.10, 0.35, 0.10}, {1,1,1},
      "Print LOCAL@EVENT_BOARD for this tile position.")
end

function onLoad()
  ui()
  refreshHeader()
end

function noop() end

function btnDeck() setTarget("DECK") end
function btnUsed() setTarget("USED") end
function btnS1() setTarget("S1") end
function btnS2() setTarget("S2") end
function btnS3() setTarget("S3") end
function btnS4() setTarget("S4") end
function btnS5() setTarget("S5") end
function btnS6() setTarget("S6") end
function btnS7() setTarget("S7") end

local function targetKey()
  if target == "DECK" then return "deck" end
  if target == "USED" then return "used" end
  if target == "S1" then return "slot1" end
  if target == "S2" then return "slot2" end
  if target == "S3" then return "slot3" end
  if target == "S4" then return "slot4" end
  if target == "S5" then return "slot5" end
  if target == "S6" then return "slot6" end
  if target == "S7" then return "slot7" end
  return "unknown"
end

function btnPrint(_, playerColor, _)
  local b = board()
  if not b or not b.positionToLocal or not b.positionToWorld then
    local msg = "EVENT BOARD NOT FOUND. Check EVENT_BOARD_GUID="..tostring(EVENT_BOARD_GUID)
    print(msg)
    broadcastToAll(msg, {1,0.4,0.4})
    return
  end

  local tokenWorld = self.getPosition()
  local boardWorld = b.getPosition()

  local localPos   = b.positionToLocal(tokenWorld)
  local worldBack  = b.positionToWorld(localPos)

  local dx = worldBack.x - tokenWorld.x
  local dy = worldBack.y - tokenWorld.y
  local dz = worldBack.z - tokenWorld.z
  local err = math.sqrt(dx*dx + dy*dy + dz*dz)

  local key = targetKey()

  local lines = {}
  table.insert(lines, "=== EVENT TRACK LOCATOR v1 ===")
  table.insert(lines, "CLICKED BY: "..tostring(playerColor or "nil"))
  table.insert(lines, "TARGET="..tostring(target).." ("..key..")")
  table.insert(lines, "EVENT_BOARD GUID="..tostring(EVENT_BOARD_GUID))
  table.insert(lines, "TOKEN WORLD = "..fmtVec(tokenWorld))
  table.insert(lines, "BOARD WORLD = "..fmtVec(boardWorld))
  table.insert(lines, "LOCAL@EVENT_BOARD = "..fmtVec(localPos))
  table.insert(lines, "WORLD(check) = "..fmtVec(worldBack).." | ERR="..string.format("%.6f", err))
  table.insert(lines, "")
  table.insert(lines, "PASTE LINE:")
  table.insert(lines, "  "..key.." = {x="..fmt(localPos.x)..", y="..fmt(localPos.y)..", z="..fmt(localPos.z).."},")
  local msg = table.concat(lines, "\n")

  print(msg)
  broadcastToAll(msg, {1,1,1})
  Wait.time(function() broadcastToAll(msg, {1,1,1}) end, 1)
end
