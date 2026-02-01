-- =========================
-- WLB COSTS CALCULATOR v1.1
-- - One tile UI, per-player cost buckets.
-- - Label background color follows ACTIVE player color (from Round token GUID, fallback Turns.turn_color)
-- - PAY button unchanged (optional: you can tint it too later)
-- - Auto-refresh UI when active player changes
-- =========================

local SAVE_VERSION = 2

-- Tags to find money tiles (legacy). If no money tiles exist, we fall back to Player Boards.
local TAG_MONEY = "WLB_MONEY"
local TAG_BOARD = "WLB_BOARD"
local COLOR_TAG_PREFIX = "WLB_COLOR_"

-- Active-color source (Round token)
local ROUND_TOKEN_GUID = "465776"

-- Button/UI tuning
local BTN_POS_Y  = 0.62
local BTN_ROT_Y  = 0

-- Smaller so we can fit 3 buttons stacked
local W_LABEL = 1800
local H_LABEL = 320
local FS_LABEL = 140

local W_PAY = 1800
local H_PAY = 320
local FS_PAY = 200

-- Base colors
local BG_LABEL_DEFAULT = {0.95, 0.95, 0.95, 1}
local FG_LABEL = {0.05, 0.05, 0.05, 1}
local BG_PAY   = {0.20, 0.85, 0.25, 1}
local FG_PAY   = {0.00, 0.00, 0.00, 1}

-- state
-- Separate buckets (no netting in UI):
--  - costsDue[color]   >= 0
--  - earningsDue[color]>= 0
local costsDue    = { Yellow=0, Blue=0, Red=0, Green=0 }
local earningsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
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

local function clampNonNeg(x)
  x = clampInt(x)
  if x < 0 then return 0 end
  return x
end

local function getCosts(c)
  if not isPlayableColor(c) then return 0 end
  costsDue[c] = clampNonNeg(costsDue[c] or 0)
  return costsDue[c]
end

local function getEarningsBucket(c)
  if not isPlayableColor(c) then return 0 end
  earningsDue[c] = clampNonNeg(earningsDue[c] or 0)
  return earningsDue[c]
end

local function setCosts(c, v)
  if not isPlayableColor(c) then return end
  costsDue[c] = clampNonNeg(v)
end

local function setEarnings(c, v)
  if not isPlayableColor(c) then return end
  earningsDue[c] = clampNonNeg(v)
end

-- Compatibility: one API `addCost` supports negative deltas (treated as earnings)
local function addCostsOrEarnings(c, delta)
  if not isPlayableColor(c) then return end
  delta = clampInt(delta)
  if delta >= 0 then
    costsDue[c] = clampNonNeg((costsDue[c] or 0) + delta)
  else
    earningsDue[c] = clampNonNeg((earningsDue[c] or 0) + math.abs(delta))
  end
end

local function labelTextCosts()
  local c = getActiveColor() or "—"
  local v = (isPlayableColor(c) and getCosts(c)) or 0
  return "REMAINING COSTS: " .. tostring(v)
end

local function labelTextEarnings()
  local c = getActiveColor() or "—"
  local v = (isPlayableColor(c) and getEarningsBucket(c)) or 0
  return "EARNINGS TO COLLECT: " .. tostring(v)
end

local function moneyColorTag(c) return COLOR_TAG_PREFIX .. tostring(c) end

local function findMoneyControllerForColor(c)
  if not isPlayableColor(c) then return nil end
  local ctag = moneyColorTag(c)

  -- IMPORTANT:
  -- If both exist (legacy money tile + new money-on-board), we must prefer the board
  -- to avoid charging/crediting the old tile by accident.

  -- 1) New: player board holds money (PlayerBoardController_Shared)
  local boards = getObjectsWithTag(TAG_BOARD) or {}
  for _,b in ipairs(boards) do
    if b and b.hasTag and b.hasTag(ctag) and b.call then
      -- Ensure it responds to getMoney (best-effort)
      local ok = pcall(function() return b.call("getMoney") end)
      if ok then return b end
    end
  end

  -- 2) Legacy: separate money tile
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

  -- Costs label (index 0)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = labelTextCosts(),
    position       = {0, BTN_POS_Y, 0.58},
    rotation       = {0, BTN_ROT_Y, 0},
    width          = W_LABEL,
    height         = H_LABEL,
    font_size      = FS_LABEL,
    color          = tintBgForColor(getActiveColor()),
    font_color     = FG_LABEL,
    alignment      = 3,
    tooltip        = "Remaining costs for active player"
  })

  -- Earnings label (index 1)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = labelTextEarnings(),
    position       = {0, BTN_POS_Y, 0.10},
    rotation       = {0, BTN_ROT_Y, 0},
    width          = W_LABEL,
    height         = H_LABEL,
    font_size      = FS_LABEL,
    color          = tintBgForColor(getActiveColor()),
    font_color     = FG_LABEL,
    alignment      = 3,
    tooltip        = "Earnings available to collect for active player"
  })

  -- PAY (index 2)
  self.createButton({
    click_function = "uiPay",
    function_owner = self,
    label          = "Settle Finances",
    position       = {0, BTN_POS_Y, -0.7},
    rotation       = {0, BTN_ROT_Y, 0},
    width          = W_PAY,
    height         = H_PAY,
    font_size      = FS_PAY,
    color          = BG_PAY,
    font_color     = FG_PAY,
    tooltip        = "Pays costs (if any) or collects earnings (if any) for active player"
  })
end

local function updateLabelAndBg()
  local btns = self.getButtons()
  if not btns or #btns == 0 then
    ensureButtons()
    return
  end

  local c = getActiveColor()
  self.editButton({ index = 0, label = labelTextCosts(), color = tintBgForColor(c) })
  self.editButton({ index = 1, label = labelTextEarnings(), color = tintBgForColor(c) })
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
    costsDue = costsDue,
    earningsDue = earningsDue
  })
end

function onLoad(saved_data)
  local loaded = false
  if saved_data ~= nil and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" then
      -- v2+ (separate)
      if type(data.costsDue) == "table" and type(data.earningsDue) == "table" then
        costsDue = data.costsDue
        earningsDue = data.earningsDue
        loaded = true
      -- v1 (combined): negative meant earnings
      elseif type(data.costs) == "table" then
        costsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
        earningsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
        for _, c in ipairs({"Yellow","Blue","Red","Green"}) do
          local v = tonumber(data.costs[c] or 0) or 0
          if v >= 0 then
            costsDue[c] = clampNonNeg(v)
          else
            earningsDue[c] = clampNonNeg(math.abs(v))
          end
        end
        loaded = true
      end
    end
  end
  if not loaded then
    costsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
    earningsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
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
  return getCosts(c)
end

function setCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  local amount = 0
  if type(params) == "table" then amount = params.amount or params.value or 0 else amount = params end
  amount = clampInt(amount)
  if amount >= 0 then
    setCosts(c, amount)
  else
    -- compatibility: negative "cost" means set earnings
    setEarnings(c, math.abs(amount))
  end
  updateLabelAndBg()
  return getCosts(c)
end

function clearCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  -- Keep semantics: clear both buckets for this color
  setCosts(c, 0)
  setEarnings(c, 0)
  updateLabelAndBg()
  return 0
end

function resetNewGame()
  -- Reset all player buckets to 0 for new game
  costsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
  earningsDue = { Yellow=0, Blue=0, Red=0, Green=0 }
  updateLabelAndBg()
  log("Costs Calculator: All costs reset for new game")
end

function addCost(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  local delta = 0
  if type(params) == "table" then delta = params.amount or params.delta or 0 else delta = params end
  addCostsOrEarnings(c, delta)
  updateLabelAndBg()
  return getCosts(c)
end

-- Optional API: explicit earnings getters (for future use)
function getEarnings(params)
  local c = resolveColor(params, true)
  if not c then return 0 end
  return getEarningsBucket(c)
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
  local dueCosts = getCosts(color)
  local dueEarnings = getEarningsBucket(color)
  if dueCosts == 0 and dueEarnings == 0 then
    updateLabelAndBg()
    return true, "nothing_due"
  end

  local moneyObj = findMoneyControllerForColor(color)
  if not moneyObj then
    return false, "no_money_controller (need either money tile tags: WLB_MONEY + "..moneyColorTag(color).." OR player board with "..TAG_BOARD.." + "..moneyColorTag(color)..")"
  end
  
  -- 1) Collect earnings (if any) to money first
  if dueEarnings > 0 then
    local ok = pcall(function()
      moneyObj.call("addMoney", { delta = dueEarnings })
    end)
    if not ok then
      return false, "money_add_failed"
    end
    setEarnings(color, 0)
  end

  -- 2) Pay costs (if any) from current money (after earnings)
  local due = dueCosts
  if due <= 0 then
    setCosts(color, 0)
    updateLabelAndBg()
    -- Notify Work listeners (lock work for this turn)
    for _, o in ipairs(getObjectsWithTag("WLB_WORK_CTRL") or {}) do
      if o and o.call then
        pcall(function() o.call("WORK_OnPaid", {color=color}) end)
      end
    end
    for _, o in ipairs(getObjectsWithTag("WLB_BOARD") or {}) do
      if o and o.call then
        pcall(function() o.call("WORK_OnPaid", {color=color}) end)
      end
    end
    return true, (dueEarnings > 0) and "earned" or "nothing_due", {earned=dueEarnings}
  end

  -- Get current money
  local currentMoney = getCurrentMoney(moneyObj)
  local canPay = math.min(due, currentMoney)
  local unpaid = due - canPay

  -- Initialize penaltyChunks (will be calculated if unpaid > 0)
  local penaltyChunks = 0

  -- Pay what they can afford
  if canPay > 0 then
    local ok = pcall(function()
      moneyObj.call("addMoney", { delta = -canPay })
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

  -- Clear the costs bucket (even if not fully paid)
  setCosts(color, 0)
  updateLabelAndBg()
  
  -- Notify Work listeners (WorkControllers OR PlayerBoards with PB controller script)
  for _, o in ipairs(getObjectsWithTag("WLB_WORK_CTRL") or {}) do
    if o and o.call then
      pcall(function() o.call("WORK_OnPaid", {color=color}) end)
    end
  end
  for _, o in ipairs(getObjectsWithTag("WLB_BOARD") or {}) do
    if o and o.call then
      pcall(function() o.call("WORK_OnPaid", {color=color}) end)
    end
  end
  
  if unpaid > 0 then
    return true, "partially_paid", {paid=canPay, unpaid=unpaid, satPenalty=penaltyChunks*2, earned=dueEarnings}
  end
  return true, "paid", {earned=dueEarnings}
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

  local dueCosts = getCosts(c)
  local dueEarnings = getEarnings(c)
  if dueCosts > 0 or dueEarnings > 0 then
    local ok, why = doPay(c)
    if not ok then
      return {ok=false, reason=why, costs=dueCosts, earnings=dueEarnings}
    end
    return {ok=true, paid=true, costs=dueCosts, earnings=dueEarnings}
  end

  return {ok=true, paid=false, costs=0, earnings=0}
end
