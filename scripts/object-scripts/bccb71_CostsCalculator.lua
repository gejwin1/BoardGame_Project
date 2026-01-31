-- =========================
-- WLB COSTS CALCULATOR v1.1
-- - One tile UI, per-player cost buckets.
-- - Label background color follows ACTIVE player color (from Round token GUID, fallback Turns.turn_color)
-- - PAY button unchanged (optional: you can tint it too later)
-- - Auto-refresh UI when active player changes
-- =========================

local SAVE_VERSION = 1

-- Tags to find money tiles
local TAG_MONEY = "WLB_MONEY"
local COLOR_TAG_PREFIX = "WLB_COLOR_"

-- Active-color source (Round token)
local ROUND_TOKEN_GUID = "465776"

-- Button/UI tuning
local BTN_POS_Y  = 0.5
local BTN_ROT_Y  = 0

local W_LABEL = 2700
local H_LABEL = 420
local FS_LABEL = 200

local W_PAY = 1600
local H_PAY = 420
local FS_PAY = 320

-- Base colors
local BG_LABEL_DEFAULT = {0.95, 0.95, 0.95, 1}
local FG_LABEL = {0.05, 0.05, 0.05, 1}
local BG_PAY   = {0.20, 0.85, 0.25, 1}
local FG_PAY   = {0.00, 0.00, 0.00, 1}

-- state
local costs = { Yellow=0, Blue=0, Red=0, Green=0 }
local lastActiveColor = nil

-- ---------- helpers ----------
local function clampInt(x)
  x = tonumber(x) or 0
  if x >= 0 then return math.floor(x + 0.00001) end
  return math.ceil(x - 0.00001)
end

local function isPlayableColor(c)
  return c=="Yellow" or c=="Blue" or c=="Red" or c=="Green"
end

local function getRoundToken()
  if not ROUND_TOKEN_GUID or ROUND_TOKEN_GUID == "" then return nil end
  return getObjectFromGUID(ROUND_TOKEN_GUID)
end

local function getActiveColor()
  -- 1) Prefer Round token's persisted color (your source of truth)
  local rt = getRoundToken()
  if rt and rt.call then
    local ok, c = pcall(function() return rt.call("getColor") end)
    if ok and isPlayableColor(c) then return c end
  end
  -- 2) Fallback to Turns
  local tc = Turns and Turns.turn_color or nil
  if isPlayableColor(tc) then return tc end
  return nil
end

local function resolveColor(params, fallbackToActive)
  if type(params) == "table" then
    local c = params.color or params.playerColor or params.pc
    if isPlayableColor(c) then return c end
  end
  if fallbackToActive then
    return getActiveColor()
  end
  return nil
end

local function getBucket(c)
  if not isPlayableColor(c) then return 0 end
  costs[c] = clampInt(costs[c] or 0)
  return costs[c]
end

local function setBucket(c, v)
  if not isPlayableColor(c) then return end
  costs[c] = clampInt(v)
end

local function addBucket(c, delta)
  if not isPlayableColor(c) then return end
  costs[c] = clampInt((costs[c] or 0) + clampInt(delta))
end

local function labelText()
  local c = getActiveColor() or "—"
  local v = (isPlayableColor(c) and getBucket(c)) or 0
  return "REMAINING COSTS: " .. tostring(v)
end

local function moneyColorTag(c) return COLOR_TAG_PREFIX .. tostring(c) end

local function findMoneyTileForColor(c)
  if not isPlayableColor(c) then return nil end
  local list = getObjectsWithTag(TAG_MONEY) or {}
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(moneyColorTag(c)) then
      return o
    end
  end
  return nil
end

local function tintBgForColor(c)
  -- light-ish versions (readable with black text)
  if c == "Yellow" then return {1.00, 0.95, 0.45, 1} end
  if c == "Blue"   then return {0.55, 0.75, 1.00, 1} end
  if c == "Red"    then return {1.00, 0.60, 0.60, 1} end
  if c == "Green"  then return {0.60, 1.00, 0.70, 1} end
  return BG_LABEL_DEFAULT
end

-- ---------- UI ----------
local function ensureButtons()
  self.clearButtons()

  -- Label (index 0)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = labelText(),
    position       = {0, BTN_POS_Y, 0.35},
    rotation       = {0, BTN_ROT_Y, 0},
    width          = W_LABEL,
    height         = H_LABEL,
    font_size      = FS_LABEL,
    color          = tintBgForColor(getActiveColor()),
    font_color     = FG_LABEL,
    alignment      = 3,
    tooltip        = "Shows remaining fixed costs for active player"
  })

  -- PAY (index 1)
  self.createButton({
    click_function = "uiPay",
    function_owner = self,
    label          = "PAY",
    position       = {0, BTN_POS_Y, -0.35},
    rotation       = {0, BTN_ROT_Y, 0},
    width          = W_PAY,
    height         = H_PAY,
    font_size      = FS_PAY,
    color          = BG_PAY,
    font_color     = FG_PAY,
    tooltip        = "Pay remaining costs for active player"
  })
end

local function updateLabelAndBg()
  local btns = self.getButtons()
  if not btns or #btns == 0 then
    ensureButtons()
    return
  end

  local c = getActiveColor()
  self.editButton({ index = 0, label = labelText(), color = tintBgForColor(c) })
end

function noop() end

-- ---------- turn color watcher ----------
local function tick()
  local c = getActiveColor()
  if c ~= lastActiveColor then
    lastActiveColor = c
    updateLabelAndBg()
  else
    -- costs might change without color change
    updateLabelAndBg()
  end
  Wait.time(tick, 0.5)
end

-- ---------- persistence ----------
function onSave()
  return JSON.encode({
    v = SAVE_VERSION,
    costs = costs
  })
end

function onLoad(saved_data)
  local loaded = false
  if saved_data ~= nil and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" and type(data.costs) == "table" then
      costs = data.costs
      loaded = true
    end
  end
  if not loaded then
    costs = { Yellow=0, Blue=0, Red=0, Green=0 }
  end

  Wait.time(function()
    ensureButtons()
    lastActiveColor = getActiveColor()
    updateLabelAndBg()
    tick()
  end, 0.15)
end

-- ---------- public API ----------
function rebuildUI()
  Wait.time(function()
    ensureButtons()
    updateLabelAndBg()
  end, 0.05)
end

function getCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  return getBucket(c)
end

function setCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  local amount = 0
  if type(params) == "table" then amount = params.amount or params.value or 0 else amount = params end
  setBucket(c, amount)
  updateLabelAndBg()
  return getBucket(c)
end

function clearCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  setBucket(c, 0)
  updateLabelAndBg()
  return 0
end

function resetNewGame()
  -- Reset all player costs to 0 for new game
  costs = { Yellow=0, Blue=0, Red=0, Green=0 }
  updateLabelAndBg()
  log("Costs Calculator: All costs reset for new game")
end

function addCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  local delta = 0
  if type(params) == "table" then delta = params.amount or params.delta or 0 else delta = params end
  addBucket(c, delta)
  updateLabelAndBg()
  return getBucket(c)
end

local function getSatToken(color)
  -- SAT token GUIDs (from EventEngine pattern)
  local SAT_TOKEN_GUIDS = {
    Yellow = "d33a15",
    Red    = "6fe69b",
    Blue   = "b2b5e3",
    Green  = "e8834c",
  }
  local guid = SAT_TOKEN_GUIDS[tostring(color or "")]
  if not guid then return nil end
  return getObjectFromGUID(guid)
end

local function getCurrentMoney(moneyTile)
  if not moneyTile or not moneyTile.call then return 0 end
  local ok, v = pcall(function() return moneyTile.call("getMoney") end)
  if ok and type(v) == "number" then return v end
  ok, v = pcall(function() return moneyTile.call("getValue") end)
  if ok and type(v) == "number" then return v end
  ok, v = pcall(function() return moneyTile.call("getState") end)
  if ok and type(v) == "table" and type(v.money) == "number" then return v.money end
  return 0
end

local function deductSatisfaction(color, amount)
  -- Deduct satisfaction: negative delta
  local satObj = getSatToken(color)
  if not satObj then return false end
  
  local ok = false
  if satObj.call then
    ok = pcall(function() satObj.call("addSat", { delta = -amount }) end)
  end
  
  if not ok and satObj.call then
    -- Fallback: use m1 function multiple times
    for _=1,amount do
      local ok2 = pcall(function() satObj.call("m1") end)
      if not ok2 then return false end
    end
    ok = true
  end
  
  return ok
end

local function doPay(color)
  if not isPlayableColor(color) then return false, "bad_color" end
  local due = getBucket(color)
  if due <= 0 then
    setBucket(color, 0)
    updateLabelAndBg()
    return true, "nothing_due"
  end

  local moneyTile = findMoneyTileForColor(color)
  if not moneyTile then
    return false, "no_money_tile (need tags: WLB_MONEY + "..moneyColorTag(color)..")"
  end

  -- Get current money
  local currentMoney = getCurrentMoney(moneyTile)
  local canPay = math.min(due, currentMoney)
  local unpaid = due - canPay

  -- Initialize penaltyChunks (will be calculated if unpaid > 0)
  local penaltyChunks = 0

  -- Pay what they can afford
  if canPay > 0 then
    local ok = pcall(function()
      moneyTile.call("addMoney", { delta = -canPay })
    end)
    if not ok then
      return false, "money_add_failed"
    end
  end

  -- Calculate satisfaction penalty: for every missing 200 WIN (or part), lose 2 SAT
  if unpaid > 0 then
    -- Calculate how many "200 WIN chunks" are missing (round up)
    penaltyChunks = math.ceil(unpaid / 200)
    local satPenalty = penaltyChunks * 2
    
    local satOk = deductSatisfaction(color, satPenalty)
    if satOk then
      broadcastToAll("⚠️ "..color..": Couldn't pay "..tostring(unpaid).." WIN → -"..tostring(satPenalty).." SAT", {1,0.6,0.2})
    else
      warn("Failed to deduct "..tostring(satPenalty).." SAT from "..tostring(color))
    end
  end

  -- Clear the cost bucket (even if not fully paid)
  setBucket(color, 0)
  updateLabelAndBg()
  
  if unpaid > 0 then
    return true, "partially_paid", {paid=canPay, unpaid=unpaid, satPenalty=penaltyChunks*2}
  end
  return true, "paid"
end

function pay(params)
  local c = resolveColor(params, true)
  if not c then return false end
  local ok = doPay(c)
  return ok
end

function uiPay(_, playerColor)
  local c = getActiveColor() or playerColor
  if not isPlayableColor(c) then
    broadcastToAll("⛔ No active player color (Round token / Turns.turn_color).", {1,0.6,0.2})
    return
  end

  local ok, why = doPay(c)
  if not ok then
    broadcastToAll("⛔ PAY failed: "..tostring(why), {1,0.4,0.4})
  end
end

-- Called by Global / turn controller when a player's turn ends
function onTurnEnd(params)
  local c = resolveColor(params, false)
  if not c then return {ok=false, reason="no_color"} end

  local due = getBucket(c)
  if due > 0 then
    local ok, why = doPay(c)
    if not ok then
      return {ok=false, reason=why, due=due}
    end
    return {ok=true, paid=true, due=due}
  end

  return {ok=true, paid=false, due=0}
end
