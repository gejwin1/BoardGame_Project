-- =========================================
-- WLB REST CONTROLLER (mini) v1.2.0
-- Works with: PB AP CTRL v2.7 + STATS CTRL + SHOP ENGINE
-- Only: REST + / REST -
-- Features:
--  - after each +/- shows big forecast:
--    REST count, current health, end-turn delta (REST-4), predicted health
--  - integrates with Shop Engine for rest-equivalent bonuses (PILLS/NATURE_TRIP)
--  - forecast uses calculated REST count (fixes timing issue with AP queries)
-- =========================================

local TAG_AP_CTRL      = "WLB_AP_CTRL"
local TAG_STATS_CTRL   = "WLB_STATS_CTRL"
local TAG_SHOP_ENGINE  = "WLB_SHOP_ENGINE"
local TAG_COLOR_PREFIX = "WLB_COLOR_"

local MIN_HEALTH = 0
local MAX_HEALTH = 9

-- UI (wizualnie: duże i daleko)
local BTN_Y = 0.22
local BTN_Z = 0.00
local BTN_X_PLUS  = -2.20
local BTN_X_MINUS =  2.20
local BTN_W = 1100
local BTN_H = 560
local BTN_FONT = 380

local COL_PLUS  = {0.15, 0.70, 0.20, 0.98}
local COL_MINUS = {0.85, 0.20, 0.20, 0.98}
local COL_TXT   = {1,1,1,1}

-- =========================================
-- UTILS
-- =========================================
local function clamp(v, a, b)
  v = tonumber(v) or 0
  if v < a then return a end
  if v > b then return b end
  return v
end

local function getColorTagFromSelf()
  if not self.getTags then return nil end
  for _, t in ipairs(self.getTags()) do
    if type(t) == "string" and string.sub(t, 1, #TAG_COLOR_PREFIX) == TAG_COLOR_PREFIX then
      return t
    end
  end
  return nil
end

local function findByTags(tagA, tagB)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(tagA) and o.hasTag(tagB) then
      return o
    end
  end
  return nil
end

local function findApCtrlForMyColor()
  local ctag = getColorTagFromSelf()
  if not ctag then
    print("[REST CTRL] Brak tagu koloru na Rest Controllerze (np. WLB_COLOR_Yellow).")
    return nil
  end

  local ap = findByTags(TAG_AP_CTRL, ctag)
  if not ap then
    print("[REST CTRL] Nie znaleziono AP Controllera dla tagu: "..tostring(ctag))
  end
  return ap
end

local function findStatsCtrlForMyColor()
  local ctag = getColorTagFromSelf()
  if not ctag then
    print("[REST CTRL] Brak tagu koloru na Rest Controllerze (np. WLB_COLOR_Yellow).")
    return nil
  end

  local st = findByTags(TAG_STATS_CTRL, ctag)
  if not st then
    print("[REST CTRL] Nie znaleziono STATS Controllera dla tagu: "..tostring(ctag))
  end
  return st
end

local function findShopEngine()
  local list = getObjectsWithTag(TAG_SHOP_ENGINE) or {}
  if #list > 0 and list[1] and list[1].call then return list[1] end
  return nil
end

local function getRestEquivalentBonus(color)
  -- Query Shop Engine for rest-equivalent bonus (from PILLS/NATURE_TRIP)
  local shop = findShopEngine()
  if not shop then return 0 end
  
  local ok, bonus = pcall(function()
    return shop.call("API_getRestEquivalent", {color=color})
  end)
  
  if ok and type(bonus) == "number" then
    return math.max(0, bonus)
  end
  
  return 0
end

-- =========================================
-- READERS
-- =========================================
local function statsGetHealthNow()
  local st = findStatsCtrlForMyColor()
  if not st then return MAX_HEALTH end

  -- Prefer: getState() -> {h=?, ...}
  local ok, res = pcall(function() return st.call("getState") end)
  if ok and type(res) == "table" then
    if type(res.h) == "number" then return math.floor(res.h) end
    if type(res.health) == "number" then return math.floor(res.health) end
  end

  -- Fallbacks
  local ok2, v = pcall(function() return st.call("getHealth") end)
  if ok2 and type(v) == "number" then return math.floor(v) end

  local ok3, v2 = pcall(function() return st.call("getHealthValue") end)
  if ok3 and type(v2) == "number" then return math.floor(v2) end

  return MAX_HEALTH
end

local function apGetRestCountNow(ap)
  if not ap then return 0 end

  local candidates = {
    function() return ap.call("getCount", {area="REST"}) end,
    function() return ap.call("getCount", {area="R"}) end,
    function() return ap.call("countArea", {area="REST"}) end,
    function() return ap.call("getRestCount") end,
  }

  for _, fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and type(res) == "number" then
      return math.max(0, math.floor(res))
    end
  end

  return 0
end

-- =========================================
-- FORECAST UI
-- =========================================
local function showRestForecast(ap, restCountOverride)
  -- Logic: effectiveREST = RESTcount + restEquivalentBonus
  -- deltaH = effectiveREST - 4
  -- restCountOverride: if provided, use this instead of querying AP controller
  local ctag = getColorTagFromSelf()
  local color = ""
  if ctag then
    -- Extract color from tag (e.g., "WLB_COLOR_Yellow" -> "Yellow")
    local prefixLen = #TAG_COLOR_PREFIX
    if string.sub(ctag, 1, prefixLen) == TAG_COLOR_PREFIX then
      color = string.sub(ctag, prefixLen + 1)
    end
  end
  
  local rest = restCountOverride
  if rest == nil then
    -- Query current REST count if not provided
    rest = apGetRestCountNow(ap)
  end
  
  local restBonus = getRestEquivalentBonus(color)
  local effectiveRest = rest + restBonus
  local hNow = statsGetHealthNow()
  local deltaH = effectiveRest - 4
  local hAfter = clamp(hNow + deltaH, MIN_HEALTH, MAX_HEALTH)

  local sign = (deltaH >= 0) and ("+"..deltaH) or tostring(deltaH)
  
  local bonusText = ""
  if restBonus > 0 then
    bonusText = "\nRest-equivalent bonus = +"..tostring(restBonus).." (effective REST = "..tostring(effectiveRest)..")"
  end

  local msg =
    "AP on REST = "..rest..bonusText..
    "\nEnd-turn Health change = "..sign..
    "\nHealth now = "..hNow..
    "\nHealth after turn = "..hAfter

  broadcastToAll(msg, {0.85, 0.95, 1})
end

-- =========================================
-- CORE ACTION
-- =========================================
local function doRestMove(amount)
  local ap = findApCtrlForMyColor()
  if not ap then return end

  -- Read REST count BEFORE moving AP (so we can calculate the new count)
  local restCountBefore = apGetRestCountNow(ap)

  local ok, ret = pcall(function()
    return ap.call("moveAP", {to="REST", amount=amount})
  end)

  -- PB AP CTRL v2.7 returns: {ok=true/false, moved=..., requested=..., reason=?}
  if not ok or type(ret) ~= "table" then
    print("[REST CTRL] moveAP error / bad return")
    return
  end

  if ret.ok ~= true then
    print("[REST CTRL] moveAP blocked. reason="..tostring(ret.reason))
    -- even if blocked, show forecast with current count
    showRestForecast(ap)
    return
  end

  local moved = tonumber(ret.moved or 0)
  if moved ~= 1 then
    if amount > 0 then
      print("[REST CTRL] REST +: brak wolnych AP/slotów (moved=0)")
    else
      print("[REST CTRL] REST -: nic do zdjęcia z REST (moved=0)")
    end
    -- Show forecast with unchanged count
    showRestForecast(ap, restCountBefore)
    return
  end

  -- Calculate new REST count: old count + amount moved
  local restCountAfter = restCountBefore + amount
  -- Ensure non-negative
  if restCountAfter < 0 then restCountAfter = 0 end

  -- Show forecast with CALCULATED new count (not queried, which would be stale)
  showRestForecast(ap, restCountAfter)
end

function rest_plus(_, player_color, alt_click)
  doRestMove(1)
end

function rest_minus(_, player_color, alt_click)
  doRestMove(-1)
end

-- =========================================
-- UI
-- =========================================
local function draw()
  self.clearButtons()

  self.createButton({
    click_function = "rest_plus",
    function_owner = self,
    label          = "+",
    position       = {BTN_X_PLUS, BTN_Y, BTN_Z},
    width          = BTN_W,
    height         = BTN_H,
    font_size      = BTN_FONT,
    color          = COL_PLUS,
    font_color     = COL_TXT,
    tooltip        = "REST +1"
  })

  self.createButton({
    click_function = "rest_minus",
    function_owner = self,
    label          = "−",
    position       = {BTN_X_MINUS, BTN_Y, BTN_Z},
    width          = BTN_W,
    height         = BTN_H,
    font_size      = BTN_FONT,
    color          = COL_MINUS,
    font_color     = COL_TXT,
    tooltip        = "REST -1"
  })
end

function onLoad()
  draw()
end
