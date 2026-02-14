-- =========================================================
-- HEAT / POLICE PAWN – Crime, Heat & Investigation System
-- Attach this script to the Police Car token on the shop board.
-- Tag the object: WLB_POLICE. Exactly one token; Persistent OFF.
--
-- Heat is GLOBAL (0–6). Increases by +1 only after a SUCCESSFUL crime.
-- Move this token to positions 0..6 to show current heat.
--
-- COORDINATE MODE (toggle test for dev):
--   USE_BOARD_LOCAL = true  → HEAT_POS are LOCAL to Shops Board; we use board.positionToWorld()
--   USE_BOARD_LOCAL = false → HEAT_POS are WORLD; we use them directly (board must not move)
-- Run once: try true, then false; whichever keeps the pawn on the printed track is correct.
-- =========================================================

HEAT_MIN = 0
HEAT_MAX = 6
heat = 0

-- Shops Board: where the heat track is printed. Used when USE_BOARD_LOCAL is true.
SHOP_BOARD_GUID = "2df5f1"
TAG_SHOP_BOARD = "WLB_SHOP_BOARD"

-- true = positions are local to Shops Board (convert with positionToWorld). false = world positions.
USE_BOARD_LOCAL = true

-- Heat track positions. If USE_BOARD_LOCAL: local coords relative to Shops Board. Else: world coords.
-- (0 = left, 6 = right). Y raised slightly so pawn doesn't clip.
HEAT_POS = {
  [0] = Vector(-3.053, 1.15, 5.7),
  [1] = Vector(-3.613, 1.15, 5.7),
  [2] = Vector(-4.187, 1.15, 5.7),
  [3] = Vector(-4.670, 1.15, 5.7),
  [4] = Vector(-5.245, 1.15, 5.7),
  [5] = Vector(-5.809, 1.15, 5.7),
  [6] = Vector(-6.375, 1.15, 5.7),
}

function getShopBoard()
  local board = getObjectFromGUID(SHOP_BOARD_GUID)
  if board then return board end
  for _, o in ipairs(getAllObjects()) do
    if o.hasTag and o.hasTag(TAG_SHOP_BOARD) then return o end
  end
  return nil
end

-- Movement helper (used by AddHeat/SetHeat; must be defined before them)
function moveToHeat(h, instant)
  h = math.max(HEAT_MIN, math.min(HEAT_MAX, tonumber(h) or 0))
  local localPos = HEAT_POS[h]
  if not localPos then return end
  local target = localPos
  if USE_BOARD_LOCAL then
    local board = getShopBoard()
    if board and board.positionToWorld then
      target = board.positionToWorld(localPos)
    end
    -- else no board: keep world fallback (may be wrong if coords were local)
  end
  if instant then
    self.setPosition(target)
  else
    self.setPositionSmooth(target, false, true)
  end
end

-- Public API: global (no local) so object.call("SetHeat", 0) etc. work in TTS
-- TTS .call may pass (self, arg) or (arg); accept both
function AddHeat(amount_or_obj, amount_opt)
  local amount = (amount_opt ~= nil) and amount_opt or amount_or_obj
  amount = tonumber(amount) or 1
  heat = math.max(HEAT_MIN, math.min(HEAT_MAX, heat + amount))
  moveToHeat(heat, false)
  return heat
end

-- TTS .call("SetHeat", 0) may pass (self, 0) or (0); accept both
function SetHeat(value_or_obj, value_opt)
  local value = value_opt
  if value == nil then value = value_or_obj end
  heat = math.max(HEAT_MIN, math.min(HEAT_MAX, tonumber(value) or 0))
  moveToHeat(heat, false)
  return heat
end

function GetHeat()
  return heat
end

function GetInvestigationModifier()
  if heat <= 0 then return 0 end
  if heat <= 2 then return 1 end
  if heat <= 4 then return 2 end
  return 3
end

function onSave()
  return JSON.encode({ heat = heat })
end

function onLoad(saved_data)
  -- 1) Restore heat from save (or keep default 0 for new game)
  if saved_data and saved_data ~= "" then
    local ok, data = pcall(JSON.decode, saved_data)
    if ok and data and data.heat ~= nil then
      heat = math.max(HEAT_MIN, math.min(HEAT_MAX, tonumber(data.heat) or 0))
    end
  end
  -- 2) Place pawn at current heat position immediately (so it never depends on Global/TurnController)
  moveToHeat(heat, true)
  -- 3) UI (if this throws, pawn is already placed)
  createHeatButtons()
end

-- Testing: only two buttons — minus (decrease heat) and plus (increase heat)
function createHeatButtons()
  self.clearButtons()
  -- Minus: decrease heat by 1 (clamped to 0–6)
  self.createButton({
    click_function = "BtnHeatMinus",
    function_owner = self,
    label = "−",
    position = {0.4, 0.3, 0},
    width = 350,
    height = 350,
    font_size = 180,
    color = {0.5, 0.5, 0.5, 0.9},
    font_color = {1, 1, 1, 1},
    tooltip = "Decrease heat",
  })
  -- Plus: increase heat by 1 (clamped to 0–6)
  self.createButton({
    click_function = "BtnHeatPlus",
    function_owner = self,
    label = "+",
    position = {-0.4, 0.3, 0},
    width = 350,
    height = 350,
    font_size = 180,
    color = {0.4, 0.5, 0.7, 0.9},
    font_color = {1, 1, 1, 1},
    tooltip = "Increase heat",
  })
end

function BtnHeatMinus(obj, color, alt_click)
  AddHeat(-1)
  broadcastToAll("Heat: " .. tostring(heat), {0.85, 0.85, 0.9})
end

function BtnHeatPlus(obj, color, alt_click)
  AddHeat(1)
  broadcastToAll("Heat: " .. tostring(heat), {0.85, 0.85, 0.9})
end
