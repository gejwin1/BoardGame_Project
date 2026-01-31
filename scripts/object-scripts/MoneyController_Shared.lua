-- =========================
-- WLB MONEY CONTROLLER v1.5 (FULL REWRITE)
-- Based on MONEY DISPLAY v1.4
--
-- Display: "MONEY = X"
-- Persists across saves
--
-- Public API (core):
--   addMoney({amount=...}) / addMoney({delta=...}) / addMoney(number)
--   setMoney({amount=...}) / setMoney({delta=...}) / setMoney(number)
--   getMoney()
--   resetNewGame()
--   rebuildUI()
--
-- Extra API (compat for engines like ShopEngine):
--   API_spend({amount=...}) -> {ok=true/false, spent=..., requested=..., reason=...}
--   spendMoney({amount=...}) -> same
--   spend({amount=...}) -> same
--
-- Notes:
--  - spend is SAFE (blocks if insufficient funds)
--  - add/set remain simple and deterministic
-- =========================

local SAVE_VERSION = 3
local DEBUG = false

local START_MONEY = 200
local money = START_MONEY

-- Button/UI tuning
local BTN_INDEX  = 0
local BTN_POS_Y  = 0.5
local BTN_WIDTH  = 2700
local BTN_HEIGHT = 420
local BTN_FONT   = 340
local BTN_ROT_Y  = 0

local BTN_BG = {0.95, 0.95, 0.95, 1}
local BTN_FG = {0.05, 0.05, 0.05, 1}

-- ---------- helpers ----------
local function log(msg)
  if DEBUG then print("[WLB MONEY] "..tostring(msg)) end
end

local function clampInt(x)
  x = tonumber(x) or 0
  if x >= 0 then return math.floor(x + 0.00001) end
  return math.ceil(x - 0.00001)
end

local function labelText()
  return "MONEY = " .. tostring(money)
end

local function ensureButton()
  self.clearButtons()
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = labelText(),

    position       = {0, BTN_POS_Y, 0},
    rotation       = {0, BTN_ROT_Y, 0},

    width          = BTN_WIDTH,
    height         = BTN_HEIGHT,
    font_size      = BTN_FONT,

    color          = BTN_BG,
    font_color     = BTN_FG,

    alignment      = 3,
    tooltip        = ""
  })
end

local function updateLabel()
  local btns = self.getButtons()
  if not btns or #btns == 0 then
    ensureButton()
    return
  end
  self.editButton({ index = BTN_INDEX, label = labelText() })
end

local function readAmount(params)
  if type(params) == "table" then
    if params.amount ~= nil then return clampInt(params.amount) end
    if params.delta  ~= nil then return clampInt(params.delta)  end
    return 0
  end
  return clampInt(params)
end

function noop() end

-- ---------- persistence ----------
function onSave()
  return JSON.encode({
    v = SAVE_VERSION,
    money = money
  })
end

function onLoad(saved_data)
  local loaded = false

  if saved_data ~= nil and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" then
      if data.money ~= nil then
        money = clampInt(data.money)
        loaded = true
      end
      if data.v ~= nil then
        -- currently unused, kept for future migrations
      end
    end
  end

  if not loaded then
    money = START_MONEY
  end

  Wait.time(function()
    ensureButton()
    updateLabel()
  end, 0.15)

  log("Loaded. money="..tostring(money))
end

-- ---------- public API ----------
function rebuildUI()
  Wait.time(function()
    ensureButton()
    updateLabel()
  end, 0.05)
end

function getMoney()
  return money
end

function setMoney(params)
  local v = readAmount(params)
  money = clampInt(v)
  updateLabel()
  log("setMoney -> "..tostring(money))
  return money
end

function addMoney(params)
  local delta = readAmount(params)
  money = clampInt(money + delta)
  updateLabel()
  log("addMoney delta="..tostring(delta).." -> "..tostring(money))
  return money
end

function resetNewGame()
  money = START_MONEY
  updateLabel()
  log("resetNewGame -> "..tostring(money))
  return money
end

-- ---------- SAFE spend API (for ShopEngine etc.) ----------
local function spendInternal(amount)
  amount = clampInt(amount)
  if amount <= 0 then
    return {ok=true, spent=0, requested=amount}
  end

  if money < amount then
    return {ok=false, spent=0, requested=amount, reason="insufficient_funds", money=money}
  end

  money = clampInt(money - amount)
  updateLabel()
  log("spent "..tostring(amount).." -> "..tostring(money))
  return {ok=true, spent=amount, requested=amount, money=money}
end

function API_spend(params)
  local amount = 0
  if type(params)=="table" then
    amount = params.amount or params.delta or 0
  else
    amount = params or 0
  end
  return spendInternal(amount)
end

-- aliases (compat)
function spendMoney(params)
  return API_spend(params)
end

function spend(params)
  return API_spend(params)
end
