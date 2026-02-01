-- =========================================================
-- WLB TURN CTRL + START WIZARD v2.9.2 (FULL REWRITE)
--
-- Goals:
--  1) Start Wizard (YOUTH/ADULT) + players (2/3/4) + roll order (physical die)
--  2) Start Game pipeline:
--     - reset sats + controllers
--     - global WLB_NEW_GAME
--     - EventController NEW GAME PREP
--     - TokenEngine (collect -> 3s -> prime) + ShopEngine reset
--     - auto-park estates (MarketController)
--     - set round + active turn
--     - Adult start allocation uses order-rolls (no 2nd roll)
--  3) RUNNING: Next Turn with confirm if AP left
--     - EventController auto next
--     - EndTurn health from REST
--     - BlockedInactiveNextRound from health
--     - finalize AP via Global.WLB_END_TURN
--  4) NEW (per turn automation):
--     - Start of EVERY TURN: ShopEngine.API_refill() (fill missing slots only)
--     - End of player's turn: expire one-turn statuses (SICK/WOUNDED)
--
-- Dependencies (tags):
--  - EventController: WLB_EVT_CONTROLLER or WLB_EVT_CTRL
--  - MarketController: WLB_MARKET_CTRL
--  - TokenEngine: WLB_TOKEN_ENGINE (must export API_collect / API_prime
--                and TE_RemoveStatus_ARGS(color,statusTag))
--  - ShopEngine:  WLB_SHOP_ENGINE (must export API_reset / API_refill)
--  - StatsCtrl: WLB_STATS_CTRL + WLB_COLOR_<Color>
--  - Money:     WLB_MONEY     + WLB_COLOR_<Color>
--  - AP Ctrl:   WLB_AP_CTRL   + WLB_COLOR_<Color>
--  - Sat tokens: SAT_TOKEN
--
-- FIXES in v2.9.2:
--  A) startBusy is single-scope (no global/local shadow). resetWizard resets the same flag.
--  B) startGame has failsafe unlock (xpcall) so a runtime error won't permanently lock START GAME.
--  C) findOneByTags supports 1-tag calls (tagB optional) to avoid nil-tag crashes (PSC lookup).
-- =========================================================

local DEBUG = true

-- =========================================================
-- [S1] CONFIG / CONSTANTS
-- =========================================================
local TOKENYEAR_GUID = "465776"
local DIE_GUID       = "14d4a4"

local MAX_ROUND = 13
local UIY = 0.25

-- Tags (existing)
local TAG_EVT_CONTROLLER_A = "WLB_EVT_CONTROLLER"
local TAG_EVT_CONTROLLER_B = "WLB_EVT_CTRL"

local TAG_STATS        = "WLB_STATS_CTRL"
local TAG_MONEY        = "WLB_MONEY"
local TAG_AP_CTRL      = "WLB_AP_CTRL"
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"
local TAG_SAT          = "SAT_TOKEN"
local TAG_BOARD        = "WLB_BOARD"

local COLOR_TAG_PREFIX = "WLB_COLOR_"

-- Market Controller tag
local TAG_MARKET_CTRL  = "WLB_MARKET_CTRL"

-- Token/Shop engines tags
local TAG_TOKEN_ENGINE = "WLB_TOKEN_ENGINE"
local TAG_SHOP_ENGINE  = "WLB_SHOP_ENGINE"
local TAG_VOCATIONS_CTRL = "WLB_VOCATIONS_CTRL"

-- === VOCATIONS CONTROLLER GUID (must match Global) ===
-- IMPORTANT: This must be the SAME GUID as in Global_Script_Complete.lua
-- If Global's VOC_CTRL_GUID is not accessible, set it here explicitly
VOC_CTRL_GUID = VOC_CTRL_GUID or "37f7a7"  -- VocationsController GUID (must match Global)

-- One-turn statuses (TokenEngine tags)
local TAG_STATUS_SICK      = "WLB_STATUS_SICK"
local TAG_STATUS_WOUNDED   = "WLB_STATUS_WOUNDED"
local TAG_STATUS_ADDICTION = "WLB_STATUS_ADDICTION"

local EVT_DEFAULT_MODE = "AUTO"
local DEFAULT_COLORS = {"Yellow","Blue","Red","Green"}

-- UI sizes
local BTN_W_BIG  = 2000
local BTN_H_BIG  = 520
local BTN_FS_BIG = 200

local BTN_W_MED  = 1150
local BTN_H_MED  = 420

local BTN_W_SM   = 900
local BTN_H_SM   = 360

-- Auto park estates tuning
local AUTO_PARK_DELAY = 1.2
local AUTO_PARK_SCAN  = true

-- Start-game automation timings
local AUTO_TOKEN_PRIME_DELAY = 3.0  -- collect -> wait -> prime
local AUTO_SHOP_RESET_DELAY  = 0.2  -- small delay to avoid collisions

-- Per-turn automation timings
local AUTO_SHOP_REFILL_DELAY = 0.05 -- tiny delay after setting active turn

-- =========================================================
-- [S2] STATE (Wizard)
-- =========================================================
local W = {
  step = "HOME",
  startMode = nil,     -- "YOUTH" | "ADULT"
  roundStart = 1,
  playersN = 4,

  colors = {},
  rollOrder = {},
  rolls = {},
  rollIdx = 1,
  finalOrder = {},
  orderDone = false,

  currentRound = 1,
  turnIndex = 1,

  adult = { stage="IDLE", per={} },

  endConfirm = nil, -- {color=<activeColor>, apLeft=<n>}

  -- Youth→Adult: set true when round advances to 6 so setActiveByTurnIndex triggers vocation selection (no Wait.time)
  triggerVocationSelectionAtRound6 = false,
}

-- IMPORTANT: single-scope start lock (no shadowing)
local startBusy = false

-- =========================================================
-- [S3] LOGGING / HELPERS
-- =========================================================
local function log(msg)  if DEBUG then print("[WLB TURN] "..tostring(msg)) end end
local function warn(msg) print("[WLB TURN][WARN] "..tostring(msg)) end

local function colorTag(c) return COLOR_TAG_PREFIX .. tostring(c) end

local function clampPlayers(n)
  n = tonumber(n) or 4
  if n ~= 2 and n ~= 3 and n ~= 4 then n = 4 end
  return n
end

local function shallowCopy(t)
  local out = {}
  for i,v in ipairs(t or {}) do out[i]=v end
  return out
end

local function shuffle(list)
  list = list or {}
  for i = #list, 2, -1 do
    local j = math.random(1, i)
    list[i], list[j] = list[j], list[i]
  end
end

local function sortByName(list)
  table.sort(list, function(a,b)
    return (a.getName() or "") < (b.getName() or "")
  end)
end

local function setTurnsColor(color)
  if Turns then Turns.turn_color = color end
end

local function safeGetObjectsWithTag(tag)
  local ok, list = pcall(function() return getObjectsWithTag(tag) end)
  if ok and type(list) == "table" then return list end
  return {}
end

local function pcallCall(obj, fnName, params)
  if not obj or not obj.call then return false, nil end
  local ok, ret = pcall(function()
    return obj.call(fnName, params or {})
  end)
  return ok, ret
end

local function globalCall(fn, params)
  if not (Global and Global.call) then return false, nil end
  local ok, ret = pcall(function()
    return Global.call(fn, params or {})
  end)
  return ok, ret
end

-- =========================================================
-- [S4] GUID GETTERS + TAG LOOKUPS
-- =========================================================
local function getTokenYear() return getObjectFromGUID(TOKENYEAR_GUID) end
local function getDie()      return getObjectFromGUID(DIE_GUID) end

-- FIX: tagB optional (supports 1-tag lookup, avoids nil-tag crashes)
local function findOneByTags(tagA, tagB)
  if not tagA or tagA == "" then return nil end
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(tagA) then
      if (not tagB) or tagB == "" then
        return o
      end
      if o.hasTag(tagB) then
        return o
      end
    end
  end
  return nil
end

local function getEvtController()
  local listA = safeGetObjectsWithTag(TAG_EVT_CONTROLLER_A)
  if #listA > 0 then return listA[1] end
  local listB = safeGetObjectsWithTag(TAG_EVT_CONTROLLER_B)
  if #listB > 0 then return listB[1] end
  return nil
end

local function evtCall(fnName, params)
  local evt = getEvtController()
  if not evt then return false, nil end
  return pcallCall(evt, fnName, params)
end

local function getMarketController()
  local list = safeGetObjectsWithTag(TAG_MARKET_CTRL)
  if #list > 0 then return list[1] end
  return nil
end

local function marketCall(fnName, params)
  local m = getMarketController()
  if not m then return false, nil end
  return pcallCall(m, fnName, params)
end

local function getTokenEngine()
  local list = safeGetObjectsWithTag(TAG_TOKEN_ENGINE)
  if #list > 0 then return list[1] end
  return nil
end

local function tokenCall(fnName, params)
  local t = getTokenEngine()
  if not t then return false, nil end
  return pcallCall(t, fnName, params)
end

local function getShopEngine()
  local list = safeGetObjectsWithTag(TAG_SHOP_ENGINE)
  if #list > 0 then return list[1] end
  return nil
end

local function shopCall(fnName, params)
  local s = getShopEngine()
  if not s then return false, nil end
  return pcallCall(s, fnName, params)
end

local function getPlayerStatusController()
  -- single-tag lookup (PSC is one object with TAG_PLAYER_STATUS_CTRL)
  local list = safeGetObjectsWithTag(TAG_PLAYER_STATUS_CTRL)
  if #list > 0 then return list[1] end
  -- fallback for older setups
  return findOneByTags(TAG_PLAYER_STATUS_CTRL)
end

local function pscCall(fnName, params)
  local psc = getPlayerStatusController()
  if not psc then return false, nil end
  return pcallCall(psc, fnName, params)
end

-- Money controller resolver (supports legacy money tiles OR player boards with embedded money)
local function getMoneyController(color)
  -- IMPORTANT:
  -- If both exist (old money tile + new money-on-board), we must prefer the board
  -- to avoid showing different values (board is the new source of truth).

  -- 1) Player board with embedded money API
  local b = findOneByTags(TAG_BOARD, colorTag(color))
  if b and b.call then
    local ok = pcall(function() return b.call("getMoney") end)
    if ok then return b end
  end

  -- 2) Legacy money tile
  local o = findOneByTags(TAG_MONEY, colorTag(color))
  if o then return o end

  return nil
end

local function getVocationsController()
  -- Use GUID-based lookup (preferred)
  local o = getObjectFromGUID(VOC_CTRL_GUID)
  if o then return o end
  
  -- Fallback to tag-based lookup
  local list = safeGetObjectsWithTag(TAG_VOCATIONS_CTRL)
  if #list > 0 then
    warn("[TURN][FALLBACK] Found VocationsController by tag, but GUID lookup failed. Update VOC_CTRL_GUID!")
    return list[1]
  end
  
  log("[TURN][ERR] VocationsController not found by GUID="..tostring(VOC_CTRL_GUID))
  return nil
end

local function vocationsCall(fnName, params)
  local voc = getVocationsController()
  if not voc then 
    log("vocationsCall: VocationsController not found")
    return false, "VocationsController not found"
  end
  
  if not voc.call then
    log("vocationsCall: VocationsController has no call method")
    return false, "VocationsController has no call method"
  end
  
  log("vocationsCall: Calling " .. fnName .. " on VocationsController")
  local ok, ret = pcallCall(voc, fnName, params)
  if not ok then
    log("vocationsCall: Error calling " .. fnName .. ": " .. tostring(ret))
  end
  return ok, ret
end

-- =========================================================
-- [S4B] PER TURN AUTOMATION HOOKS
-- =========================================================
local function countAddictionTokens(color)
  local count = 0
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_STATUS_ADDICTION) and o.hasTag(COLOR_TAG_PREFIX..color) then
      count = count + 1
    end
  end
  return count
end

local function removeOneAddictionToken(color)
  tokenCall("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_ADDICTION })
end

local function onTurnStart_ApplyAddiction(color)
  if not color or color == "" then return end

  local addictionCount = countAddictionTokens(color)
  if addictionCount == 0 then return end

  local ap = findOneByTags(TAG_AP_CTRL, colorTag(color))
  if ap and addictionCount > 0 then
    for i=1, addictionCount do
      Wait.time(function()
        if ap and ap.call then
          pcall(function() ap.call("moveAP", {to="INACTIVE", amount=1}) end)
        end
      end, 0.1 * i)
    end

    log("Addiction: "..color.." ma "..addictionCount.." tokeny -> przeniesiono "..addictionCount.." AP do INACTIVE")
    broadcastToAll("⚠️ "..color.." addiction: -"..addictionCount.." AP to INACTIVE", {1,0.7,0.3})
  end

  Wait.time(function()
    removeOneAddictionToken(color)
    log("Addiction: "..color.." usunięto 1 token (zostało: "..tostring(addictionCount-1)..")")
  end, 0.1 * (addictionCount + 1))
end

local function onTurnStart_AutoRefillShops()
  -- Skip refill during game start (first turn of first round)
  -- Reset will handle shop setup, refill is not needed
  if W.currentRound == W.roundStart and W.turnIndex == 1 then
    log("onTurnStart_AutoRefillShops: Skipping refill during game start (reset will handle shop setup)")
    return
  end
  
  Wait.time(function()
    shopCall("API_refill", {})
  end, AUTO_SHOP_REFILL_DELAY)
end

local function onTurnStart_ProcessInvestments(color)
  -- Process investment payments at start of turn (DEBENTURES, LOAN, ENDOWMENT, ESTATEINVEST)
  if not color then return end
  local ok = select(1, shopCall("API_processInvestmentPayments", {color=color}))
  if not ok then
    log("onTurnStart_ProcessInvestments: ShopEngine API_processInvestmentPayments failed for "..tostring(color))
  end
end

local function getNameSafe(obj)
  if not obj then return nil end
  local ok, name = pcall(function() return obj.getName() end)
  if ok and type(name) == "string" then return name end
  return nil
end

-- Per-color guard to prevent double-adding rental costs in the same turn
local rentalCostAddedThisTurn = { Yellow=false, Blue=false, Red=false, Green=false }

local function onTurnStart_AddRentalCosts(color)
  -- Add rental costs for owned apartments every turn
  if not color or color == "" then return end
  
   -- Per-color guard: prevent adding rental costs multiple times in the same turn
  -- This handles cases where the function might be called multiple times or
  -- where costs were already initialized elsewhere
  if rentalCostAddedThisTurn[color] == true then
    log("Rental cost already added this turn for "..color..", skipping")
    return
  end
  
  local TAG_COSTS_CALC = "WLB_COSTS_CALC"
  local TAG_ESTATE_OWNED = "WLB_ESTATE_OWNED"
  local TAG_ESTATE_MODE_RENT = "WLB_ESTATE_MODE_RENT"
  local COLOR_TAG_PREFIX = "WLB_COLOR_"
  local colorTagStr = COLOR_TAG_PREFIX .. tostring(color)
  
  -- Rental costs per apartment level (from EstateEngine)
  -- NOTE: This should ideally come from EstateEngine API to avoid duplication
  local ESTATE_RENTAL_COST = {
    L0 = 50,   -- Default (grandma's house)
    L1 = 200,  -- Studio apartment
    L2 = 350,  -- Flat with 3 rooms
    L3 = 550,  -- House in suburbs
    L4 = 1000  -- Mansion
  }
  
  -- Find owned estate card for this player (should only have one)
  -- Rental costs apply to all owned apartments (rented or bought)
  -- Use same method as EstateEngine to ensure consistency
  local totalRentalCost = ESTATE_RENTAL_COST.L0  -- Default: 50 WIN (grandma's house)
  
  -- Search for estate cards with player's color tag AND ESTATE_OWNED tag
  -- Must also have ESTATE_CARD tag to ensure it's an actual estate card
  local TAG_ESTATE_CARD = "WLB_ESTATE_CARD"
  for _, o in ipairs(getAllObjects()) do
    if o and o.tag == "Card" and o.hasTag and 
       o.hasTag(TAG_ESTATE_CARD) and  -- Must be an estate card
       o.hasTag(TAG_ESTATE_OWNED) and  -- Must be owned
       o.hasTag(colorTagStr) then  -- Must belong to this player
      -- This is an owned apartment (rented or bought)
      -- Extract level from card name (ESTATE_L1, ESTATE_L2, etc.)
      local cardName = getNameSafe(o)
      if cardName then
        local levelMatch = cardName:match("ESTATE_L([1-4])")
        if levelMatch then
          local level = "L" .. levelMatch
          local cost = ESTATE_RENTAL_COST[level]
          if cost then
            totalRentalCost = cost  -- Use apartment's rental cost
            log("Rental cost: Found "..level.." apartment for "..color..", cost="..tostring(cost))
            break  -- Player should only have one apartment
          end
        end
      end
    end
  end
  
  -- Add rental cost to cost calculator
  -- Check if rental cost was already added this turn (per-color guard)
  if rentalCostAddedThisTurn[color] == true then
    log("Rental cost already added this turn for "..color..", skipping duplicate")
    return
  end
  
  local costsCalc = findOneByTags(TAG_COSTS_CALC)
  if costsCalc and costsCalc.call then
    -- Check current cost to avoid double-adding if already initialized
    local currentCost = 0
    local okCheck, currentCostResult = pcall(function()
      return costsCalc.call("getCost", {color=color})
    end)
    if okCheck and type(currentCostResult) == "number" then
      currentCost = currentCostResult
    end
    
    -- Only add if the current cost doesn't already include rental cost
    -- (This prevents double-adding if costs were initialized elsewhere)
    -- We add rental cost regardless, as it's a per-turn recurring cost
    local ok = pcall(function()
      costsCalc.call("addCost", {color=color, amount=totalRentalCost})
    end)
    if ok then
      rentalCostAddedThisTurn[color] = true  -- Mark as added for this turn
      log("Rental cost: "..color.." added "..tostring(totalRentalCost).." WIN per turn (was: "..tostring(currentCost)..", now: "..tostring(currentCost + totalRentalCost)..")")
    else
      warn("Failed to add rental cost for "..tostring(color))
    end
  end
end

local function onTurnStart_ApplySmartwatch(color)
  if not color or color == "" then return end

  local ok, owns = shopCall("API_ownsHiTech", {color=color, kind="SMARTWATCH"})
  if not ok or not owns then return end

  local ap = findOneByTags(TAG_AP_CTRL, colorTag(color))
  if ap and ap.call then
    Wait.time(function()
      if ap and ap.call then
        pcall(function() ap.call("moveAP", {to="START", amount=1}) end)
        log("Smartwatch: "..color.." moved 1 AP from INACTIVE to START")
      end
    end, 0.2)
  end
end

local function onTurnStart_ReapplyChildBlockedAP(color)
  if not color or color == "" then return end

  local ok, blockedCount = pscCall("PS_GetChildBlockedAP", {color=color})
  if not ok or not blockedCount or blockedCount <= 0 then return end

  blockedCount = tonumber(blockedCount) or 0
  if blockedCount <= 0 then return end

  local ap = findOneByTags(TAG_AP_CTRL, colorTag(color))
  if ap and ap.call then
    Wait.time(function()
      if ap and ap.call then
        for i = 1, blockedCount do
          Wait.time(function()
            if ap and ap.call then
              pcall(function() ap.call("moveAP", {to="INACTIVE", amount=1}) end)
            end
          end, 0.1 * i)
        end
        log("Child-blocked AP: "..color.." re-applied "..tostring(blockedCount).." AP to INACTIVE at start of turn")
      end
    end, 0.3)
  end
end

local function onTurnEnd_ExpireOneTurnStatuses(color)
  if not color or color == "" then return end
  tokenCall("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_SICK })
  tokenCall("TE_RemoveStatus_ARGS", { color = color, statusTag = TAG_STATUS_WOUNDED })
end

-- Before player's turn: check vocation level-up requirements; if met, swap next-level tile (2 or 3) with current vocation tile.
local function onTurnStart_CheckVocationPromotion(color)
  if not color or color == "" then return end
  local ok, promoted = vocationsCall("VOC_CheckAndAutoPromote", { color = color })
  if ok and promoted then
    log("Vocation auto-promotion applied for " .. tostring(color))
  end
end

-- =========================================================
-- [S5] EVENT CONTROLLER COMPAT API
-- =========================================================
local function evtAPI_setPlayers(n)
  local payload = { players = n, n = n, count = n }
  local ok = false
  ok = (select(1, evtCall("API_setPlayers", payload)))
  if ok then return true end
  ok = (select(1, evtCall("setPlayers", payload)))
  if ok then return true end
  ok = (select(1, evtCall("api_setPlayers", payload)))
  return ok == true
end

local function evtAPI_setMode(mode)
  mode = tostring(mode or "AUTO"):upper()
  local payload = { mode = mode }
  local ok = false
  ok = (select(1, evtCall("API_setMode", payload)))
  if ok then return true end
  ok = (select(1, evtCall("setMode", payload)))
  if ok then return true end
  ok = (select(1, evtCall("api_setMode", payload)))
  return ok == true
end

local function evtAPI_newGamePrep(kind)
  kind = tostring(kind or "YOUTH"):upper()
  if kind ~= "YOUTH" and kind ~= "ADULT" then kind = "YOUTH" end

  local ok = select(1, evtCall("WLB_EVT_NEWGAME", { kind = kind, refill = true }))
  if ok then return true end
  ok = select(1, evtCall("EVT_NEW_GAME_PREP", { kind = kind, refill = true }))
  if ok then return true end
  ok = select(1, evtCall("EVT_NEW_GAME_SEQUENCED_SETUP", { kind = kind }))
  return ok == true
end

local function evtAPI_autoNextTurn()
  local ok, ret = evtCall("EVT_AUTO_NEXT_TURN", {})
  if ok then return ret end
  evtCall("ui_next", {})
  return nil
end

-- =========================================================
-- [S6] TOKENYEAR
-- =========================================================
local function tintForColor(color)
  if color == "Yellow" then return {1, 0.95, 0.2} end
  if color == "Blue"   then return {0.25, 0.55, 1} end
  if color == "Red"    then return {1, 0.25, 0.25} end
  if color == "Green"  then return {0.25, 1, 0.35} end
  return {1,1,1}
end

local function tokenYearSetRound(r)
  local ty = getTokenYear()
  if not ty then warn("TokenYear not found "..tostring(TOKENYEAR_GUID)); return end
  pcall(function() ty.call("setRound", {round = r}) end)
end

local function tokenYearSetColor(color)
  local ty = getTokenYear()
  if not ty then return end
  local ok = pcall(function()
    ty.call("setColor", {color = color})
  end)
  if not ok then
    pcall(function()
      ty.setColorTint(tintForColor(color))
    end)
  end
end

-- =========================================================
-- [S7] RESETS
-- =========================================================
local function resetSatisfactionTo10()
  local sats = safeGetObjectsWithTag(TAG_SAT)
  sortByName(sats)
  for i,obj in ipairs(sats) do
    pcall(function() obj.call("resetToStart", {slot = (i-1)}) end)
  end
  return #sats
end

local function resetControllersByTag(tag)
  local list = safeGetObjectsWithTag(tag)
  sortByName(list)
  for _,o in ipairs(list) do
    pcall(function() o.call("resetNewGame") end)
  end
  return #list
end

-- =========================================================
-- [S8] DIE ROLL
-- =========================================================
local function rollPhysicalDieAndRead(callback)
  local die = getDie()
  if not die then
    callback(nil, "Die not found (GUID "..tostring(DIE_GUID)..")")
    return
  end

  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)

  local timeout = os.time() + 6

  Wait.condition(
    function()
      local v = nil
      local ok = pcall(function() v = die.getValue() end)
      if ok and type(v)=="number" and v>=1 and v<=6 then
        callback(v, nil)
      else
        callback(nil, "Failed to read die value (getValue).")
      end
    end,
    function()
      local resting = false
      pcall(function() resting = die.resting end)
      if resting then return true end
      if os.time() >= timeout then return true end
      return false
    end
  )
end

-- =========================================================
-- [S9] AP / STATS INTEGRATION
-- =========================================================
local function getActiveColor()
  if not W.finalOrder or #W.finalOrder == 0 then return nil end
  return W.finalOrder[W.turnIndex] or W.finalOrder[1]
end

local function apGetUnspentCount(color)
  local ap = findOneByTags(TAG_AP_CTRL, colorTag(color))
  if not ap then return 0 end

  local candidates = {
    function() return ap.call("getUnspentCount") end,
    function() return ap.call("getUnspentAP") end,
    function() return ap.call("countUnspent") end,
  }

  for _,fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and type(res) == "number" then
      return math.max(0, math.floor(res))
    end
  end

  warn("AP_CTRL for "..tostring(color).." has no unspent getter.")
  return 0
end

local function apGetRestCount(color)
  local ap = findOneByTags(TAG_AP_CTRL, colorTag(color))
  if not ap then return 0 end

  local candidates = {
    function() return ap.call("getCount", {area="R"}) end,
    function() return ap.call("getCount", {area="REST"}) end,
    function() return ap.call("countArea", {area="R"}) end,
    function() return ap.call("getRestCount") end,
  }

  for _,fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and type(res) == "number" then
      return math.max(0, math.floor(res))
    end
  end

  warn("AP_CTRL for "..tostring(color).." has no REST counter API.")
  return 0
end

local function getRestEquivalentBonus(color)
  local ok, bonus = shopCall("API_getRestEquivalent", {color=color})
  if ok and type(bonus) == "number" then
    return math.max(0, bonus)
  end
  return 0
end

local function statsApplyHealthDelta(color, delta)
  if delta == 0 then return true end
  local st = findOneByTags(TAG_STATS, colorTag(color))
  if not st then return false end

  local candidates = {
    function() return st.call("applyDelta", {h = delta}) end,
    function() return st.call("applyDelta", {health = delta}) end,
  }

  for _,fn in ipairs(candidates) do
    local ok = pcall(fn)
    if ok then return true end
  end

  warn("STATS CTRL for "..tostring(color).." has no applyDelta({h=...}).")
  return false
end

local function statsGetHealth(color)
  local st = findOneByTags(TAG_STATS, colorTag(color))
  if not st then return 9 end

  local candidates = {
    function() return st.call("getHealth") end,
    function() return st.call("getHealthValue") end,
    function() return st.call("getState") end,
  }

  for _,fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok then
      if type(res) == "number" then
        return math.floor(res)
      elseif type(res) == "table" then
        if type(res.h) == "number" then return math.floor(res.h) end
        if type(res.health) == "number" then return math.floor(res.health) end
      end
    end
  end

  warn("STATS CTRL for "..tostring(color).." has no getter API. Assuming h=9.")
  return 9
end

local function blockedInactiveFromHealth(h)
  h = tonumber(h) or 9
  if h <= 0 then return 6 end
  if h <= 3 then return 3 end
  if h <= 6 then return 1 end
  return 0
end

local function setBlockedInactiveNextRound(color, count)
  count = tonumber(count) or 0
  if count < 0 then count = 0 end

  local ok = select(1, globalCall("WLB_SET_BLOCKED_INACTIVE", {color = color, count = count}))
  if ok then
    log("Blocked inactive set via Global: "..tostring(color).."="..tostring(count))
    return true
  end

  warn("Global has no WLB_SET_BLOCKED_INACTIVE (or call failed).")
  return false
end

local function onTurnEnd_PayCosts(color)
  if not color then return end
  
  local TAG_COSTS_CALC = "WLB_COSTS_CALC"
  local costsCalc = findOneByTags(TAG_COSTS_CALC)
  if not costsCalc or not costsCalc.call then
    -- Costs Calculator not found, skip (not an error)
    return
  end
  
  local ok, result = pcall(function()
    return costsCalc.call("onTurnEnd", {color=color})
  end)
  
  if not ok then
    warn("CostsCalculator.onTurnEnd failed for "..tostring(color)..": "..tostring(result))
  elseif result and result.ok == false then
    warn("CostsCalculator.onTurnEnd returned error: "..tostring(result.reason or "unknown"))
  end
end

local function endTurnProcessing(color)
  if not color then return end

  local restCount = apGetRestCount(color)
  local restBonus = getRestEquivalentBonus(color)
  local effectiveRest = restCount + restBonus
  local deltaH = effectiveRest - 4

  if deltaH ~= 0 then
    statsApplyHealthDelta(color, deltaH)
    if restBonus > 0 then
      log("EndTurn: "..color.." REST="..restCount.." + bonus="..restBonus.." (effective="..effectiveRest..") -> deltaH="..deltaH)
    else
      log("EndTurn: "..color.." REST="..restCount.." -> deltaH="..deltaH)
    end
  else
    if restBonus > 0 then
      log("EndTurn: "..color.." REST="..restCount.." + bonus="..restBonus.." (effective="..effectiveRest..") -> deltaH=0")
    else
      log("EndTurn: "..color.." REST="..restCount.." -> deltaH=0")
    end
  end

  if restBonus > 0 then
    shopCall("API_clearRestEquivalent", {color=color})
  end

  local h = statsGetHealth(color)
  local block = blockedInactiveFromHealth(h)
  setBlockedInactiveNextRound(color, block)
  log("EndTurn: "..color.." HEALTH="..h.." -> blockedInactiveNext="..block)
  
  -- Automatically pay costs at end of turn
  onTurnEnd_PayCosts(color)
end

local function finalizeAPAfterTurn(color)
  if not color then return end

  local ok = select(1, globalCall("WLB_END_TURN", { color = color }))
  if ok then
    log("EndTurn: Global.WLB_END_TURN applied for "..tostring(color))
    return true
  end

  warn("EndTurn: Global.WLB_END_TURN missing (AP not finalized).")
  return false
end

-- =========================================================
-- [S10] TURN / ROUND PROGRESSION
-- =========================================================
local lastActiveColor = nil

local function setActiveByTurnIndex()
  if not W.finalOrder or #W.finalOrder == 0 then return end

  -- Youth→Adult: trigger vocation selection when we just entered round 6 (call via self so it runs in chunk where adultInitFromOrderRolls/startVocationSelection are defined)
  if W.triggerVocationSelectionAtRound6 then
    W.triggerVocationSelectionAtRound6 = false
    if self and self.call then
      pcall(function() self.call("TriggerYouthToAdultVocationSelection", {}) end)
    end
  end

  local c = W.finalOrder[W.turnIndex] or W.finalOrder[1]

  -- Before this player's turn: check vocation level-up (1→2 or 2→3); if requirements met, swap next-level tile with current vocation tile.
  onTurnStart_CheckVocationPromotion(c)

  tokenYearSetColor(c)
  setTurnsColor(c)
  broadcastToAll("▶️ Tura: "..tostring(c).." | Runda: "..tostring(W.currentRound), {0.8,0.9,1})

  local prev = lastActiveColor
  lastActiveColor = c

  -- Reset per-color rental cost guard for new turn
  if prev and prev ~= "" then
    rentalCostAddedThisTurn[prev] = false
  end
  rentalCostAddedThisTurn[c] = false

  globalCall("WLB_ON_TURN_CHANGED", { newColor = c, prevColor = prev })

  onTurnStart_ApplyAddiction(c)
  onTurnStart_ReapplyChildBlockedAP(c)
  onTurnStart_AutoRefillShops()
  onTurnStart_ApplySmartwatch(c)
  onTurnStart_ProcessInvestments(c)
  onTurnStart_AddRentalCosts(c)
end

local function advanceTurn()
  if not W.finalOrder or #W.finalOrder == 0 then return end

  W.turnIndex = W.turnIndex + 1

  if W.turnIndex > #W.finalOrder then
    W.turnIndex = 1
    if W.currentRound < MAX_ROUND then
      W.currentRound = W.currentRound + 1
      tokenYearSetRound(W.currentRound)
      -- Youth → Adult: when reaching round 6, trigger vocation selection from setActiveByTurnIndex (same script context; Wait.time can run in Global and lose access to startVocationSelection)
      if W.startMode == "YOUTH" and W.currentRound == 6 then
        W.triggerVocationSelectionAtRound6 = true
      end
    else
      broadcastToAll("🏁 Game Over: reached round "..MAX_ROUND, {1,0.8,0.2})
    end
  end

  setActiveByTurnIndex()
  drawUI()
end

-- =========================================================
-- [S11] WIZARD CORE
-- =========================================================
local function resetWizard()
  W.step = "HOME"
  W.startMode = nil
  W.roundStart = 1
  W.playersN = 4

  W.colors = {}
  W.rollOrder = {}
  W.rolls = {}
  W.rollIdx = 1
  W.finalOrder = {}
  W.orderDone = false

  W.currentRound = 1
  W.turnIndex = 1

  W.adult = {stage="IDLE", per={}}
  W.endConfirm = nil
  W.triggerVocationSelectionAtRound6 = false

  -- FIX: reset the real startBusy (single-scope)
  startBusy = false

  drawUI()
end

local function chooseMode(mode)
  W.startMode = mode
  W.roundStart = (mode=="ADULT") and 6 or 1

  W.currentRound = W.roundStart
  tokenYearSetRound(W.currentRound)
  tokenYearSetColor("White")

  evtAPI_setMode(EVT_DEFAULT_MODE)

  W.step = "PLAYERS"
  drawUI()
end

local function choosePlayers(n)
  W.playersN = clampPlayers(n)
  evtAPI_setPlayers(W.playersN)

  W.colors = {}
  for i=1,W.playersN do table.insert(W.colors, DEFAULT_COLORS[i]) end

  W.rollOrder = shallowCopy(W.colors)
  shuffle(W.rollOrder)

  W.rolls = {}
  W.rollIdx = 1
  W.finalOrder = {}
  W.orderDone = false
  W.step = "ORDER"
  drawUI()
end

local function finalizeOrder()
  local idx = {}
  for i,c in ipairs(W.rollOrder) do idx[c]=i end

  local tmp = shallowCopy(W.rollOrder)
  table.sort(tmp, function(a,b)
    local ra, rb = W.rolls[a] or 0, W.rolls[b] or 0
    if ra ~= rb then return ra > rb end
    return (idx[a] or 999) < (idx[b] or 999)
  end)

  W.finalOrder = tmp
  W.orderDone = true

  local s={}
  for i,c in ipairs(W.finalOrder) do
    table.insert(s, i..") "..c.." ("..tostring(W.rolls[c])..")")
  end
  broadcastToAll("✅ Turn Order:\n"..table.concat(s,"\n"), {0.7,1,0.7})
end

local function adultBonuses(roll)
  local pool = 10 + roll
  local moneyTotal = 1400 - (200 * roll)
  return pool, moneyTotal
end

local rollingNow = false

local function doNextRoll()
  if W.step ~= "ORDER" then return end
  if rollingNow then return end
  if W.rollIdx > #W.rollOrder then return end

  local color = W.rollOrder[W.rollIdx]
  if W.rolls[color] then
    W.rollIdx = W.rollIdx + 1
    drawUI()
    return
  end

  rollingNow = true
  broadcastToAll("🎲 Rolling die: "..color, {1,1,0.6})

  rollPhysicalDieAndRead(function(v, err)
    rollingNow = false
    if err then
      broadcastToAll("❌ "..tostring(err), {1,0.3,0.3})
      drawUI()
      return
    end

    W.rolls[color] = v
    broadcastToAll("🎲 Result: "..color.." = "..v, {0.8,0.9,1})
    W.rollIdx = W.rollIdx + 1

    if W.rollIdx > #W.rollOrder then
      finalizeOrder()
    end

    drawUI()
  end)
end

local function adultInitFromOrderRolls()
  if not W.adult then
    W.adult = {stage="IDLE", per={}}
  end

  W.adult.stage = "ALLOC"
  W.adult.per = {}

  if not W.finalOrder or #W.finalOrder == 0 then
    warn("adultInitFromOrderRolls: W.finalOrder is empty or nil!")
    broadcastToAll("⚠️ ERROR: finalOrder is empty. Cannot initialize ADULT bonuses.", {1,0.5,0.5})
    return
  end

  for _,c in ipairs(W.finalOrder) do
    local r = W.rolls[c] or 1
    local pool, moneyTotal = adultBonuses(r)

    local moneyObj = getMoneyController(c)
    if moneyObj then
      pcall(function() moneyObj.call("setMoney", {amount = moneyTotal}) end)
    else
      warn("No MONEY controller for "..c.." (need WLB_MONEY tile or WLB_BOARD with money API)")
    end

    W.adult.per[c] = { pool=pool, k=0, s=0, active=true, roll=r, money=moneyTotal }
    log("ADULT INIT: "..c.." roll="..r.." pool="..pool.." money="..moneyTotal)
  end

  broadcastToAll("✅ ADULT START: used rolls from turn order setup (without second roll).", {0.7,1,0.7})
  log("ADULT INIT: stage="..W.adult.stage.." players="..#W.finalOrder)
end

local function adultAlloc(color, which)
  if W.adult.stage ~= "ALLOC" then return end
  local st = W.adult.per[color]
  if not st or not st.active or st.pool <= 0 then return end
  if which=="K" then st.k = st.k + 1 else st.s = st.s + 1 end
  st.pool = st.pool - 1
  drawUI()
end

-- =========================================================
-- VOCATION SELECTION FUNCTIONS (must be defined before adultApply)
-- =========================================================

local vocationSelectionState = {
  active = false,
  selectionOrder = {},
  currentIndex = 1,
}

local function getSciencePoints(color)
  -- Science Points = Knowledge + Skills
  local statsObj = findOneByTags(TAG_STATS, colorTag(color))
  if not statsObj then
    log("No Stats Controller for " .. color .. ", assuming 0 Science Points")
    return 0
  end
  
  local ok, stats = pcall(function()
    return statsObj.call("getState")
  end)
  
  if not ok or not stats then
    log("Could not get stats for " .. color .. ", assuming 0 Science Points")
    return 0
  end
  
  local knowledge = tonumber(stats.k) or 0
  local skills = tonumber(stats.s) or 0
  
  -- For Adult start or Youth→Adult (round 6): include bonus pool in calculation
  local useAdultPool = (W.startMode == "ADULT" or (W.currentRound >= 6 and W.adult and W.adult.stage == "ALLOC"))
  if useAdultPool and W.adult and W.adult.per and W.adult.per[color] then
    local bonusPool = W.adult.per[color].pool or 0
    -- Add the full bonus pool (player hasn't allocated it yet, but it counts for selection order)
    return knowledge + skills + bonusPool
  end
  
  return knowledge + skills
end

-- Expose getSciencePoints for external calls (e.g., from VocationsController)
function API_GetSciencePoints(params)
  local color = params and params.color or nil
  if not color then return 0 end
  return getSciencePoints(color)
end

local function calculateVocationSelectionOrder()
  -- Calculate Science Points for each player
  local playerScores = {}
  for i, color in ipairs(W.finalOrder) do
    local sciencePoints = getSciencePoints(color)
    table.insert(playerScores, {
      color = color,
      sciencePoints = sciencePoints,
      turnOrder = i  -- Original turn order for tie-breaking
    })
  end
  
  -- Sort by Science Points (highest first), then by turn order (earlier first)
  table.sort(playerScores, function(a, b)
    if a.sciencePoints ~= b.sciencePoints then
      return a.sciencePoints > b.sciencePoints
    end
    return a.turnOrder < b.turnOrder
  end)
  
  -- Extract just the colors in selection order
  local selectionOrder = {}
  for _, entry in ipairs(playerScores) do
    table.insert(selectionOrder, entry.color)
  end
  
  return selectionOrder
end

local function processNextVocationSelection()
  if not vocationSelectionState.active then return end
  
  if vocationSelectionState.currentIndex > #vocationSelectionState.selectionOrder then
    -- All players have chosen
    vocationSelectionState.active = false
    broadcastToAll("✅ All players have chosen their vocations!", {0.7, 1, 0.7})
    
    -- After all vocations are selected, start Science Points allocation (Adult start or Youth→Adult round 6)
    if (W.startMode == "ADULT" or W.currentRound >= 6) and W.adult and W.adult.stage == "ALLOC" then
      Wait.time(function()
        broadcastToAll("📊 Now allocate your Science Points (K/S bonuses).", {0.7, 1, 0.7})
        -- Science Points allocation UI is already active (W.adult.stage = "ALLOC")
        -- Players can now use the allocation buttons
      end, 1.0)
    end
    
    return
  end
  
  local currentColor = vocationSelectionState.selectionOrder[vocationSelectionState.currentIndex]
  
  -- Check if player already has a vocation (shouldn't happen, but safety check)
  local ok, hasVocation = vocationsCall("VOC_GetVocation", {color = currentColor})
  if ok and hasVocation then
    log("Player " .. currentColor .. " already has vocation: " .. tostring(hasVocation))
    vocationSelectionState.currentIndex = vocationSelectionState.currentIndex + 1
    Wait.time(processNextVocationSelection, 0.5)
    return
  end
  
  -- Start selection for this player
  local vocCtrl = getVocationsController()
  if not vocCtrl then
    broadcastToAll("❌ VocationsController not found. Cannot start selection for " .. currentColor, {1, 0.3, 0.3})
    log("ERROR: VocationsController not found when trying to start selection for " .. currentColor)
    vocationSelectionState.currentIndex = vocationSelectionState.currentIndex + 1
    Wait.time(processNextVocationSelection, 1.0)
    return
  end
  
  local pts = getSciencePoints(currentColor)
  local ok, err = vocationsCall("VOC_StartSelection", {color = currentColor, points = pts})
  if not ok then
    broadcastToAll("❌ Failed to start vocation selection for " .. currentColor .. ": " .. tostring(err), {1, 0.3, 0.3})
    log("ERROR: VOC_StartSelection failed for " .. currentColor .. ": " .. tostring(err))
    vocationSelectionState.currentIndex = vocationSelectionState.currentIndex + 1
    Wait.time(processNextVocationSelection, 1.0)
    return
  end
  
  broadcastToAll("🎯 " .. currentColor .. ", choose your vocation!", {0.3, 1, 0.3})
end

local function startVocationSelection()
  if vocationSelectionState.active then
    log("Vocation selection already active")
    return
  end
  
  local vocCtrl = getVocationsController()
  if not vocCtrl then
    broadcastToAll("⚠️ VocationsController not found. Vocation selection skipped.", {1, 0.8, 0.2})
    return
  end
  
  -- Calculate selection order
  local selectionOrder = calculateVocationSelectionOrder()
  
  if #selectionOrder == 0 then
    log("No players for vocation selection")
    return
  end
  
  -- Build selection order message
  local orderMsg = {}
  for i, color in ipairs(selectionOrder) do
    local sciencePoints = getSciencePoints(color)
    table.insert(orderMsg, i .. ") " .. color .. " (" .. sciencePoints .. " Science Points)")
  end
  
  broadcastToAll("🎯 Vocation Selection Order:\n" .. table.concat(orderMsg, "\n"), {0.7, 1, 0.7})
  
  vocationSelectionState.active = true
  vocationSelectionState.selectionOrder = selectionOrder
  vocationSelectionState.currentIndex = 1
  
  -- Start with first player
  processNextVocationSelection()
end

-- Global (object) function so setActiveByTurnIndex can invoke it via self.call when script is split into chunks (adultInitFromOrderRolls/startVocationSelection are in this chunk)
function TriggerYouthToAdultVocationSelection()
  if not W or W.currentRound ~= 6 or W.startMode ~= "YOUTH" then return end
  adultInitFromOrderRolls()
  startVocationSelection()
end

local function adultApply(color)
  if W.adult.stage ~= "ALLOC" then return end
  local st = W.adult.per[color]
  if not st or not st.active then return end
  if st.pool > 0 then
    broadcastToAll("⛔ "..color..": distribute pool to zero. Remaining: "..st.pool, {1,0.6,0.2})
    return
  end

  local statsObj = findOneByTags(TAG_STATS, colorTag(color))
  if not statsObj then
    broadcastToAll("❌ No STATS CTRL for "..color, {1,0.3,0.3})
    return
  end

  local ok = pcall(function()
    statsObj.call("adultStart_apply", {k=st.k, s=st.s})
  end)
  if not ok then
    broadcastToAll("❌ "..color..": missing adultStart_apply or error.", {1,0.3,0.3})
    return
  end

  st.active = false
  broadcastToAll("✅ "..color..": bonuses K="..st.k.." S="..st.s.." applied.", {0.7,1,0.7})

  local allDone = true
  for _,c in ipairs(W.finalOrder) do
    if W.adult.per[c] and W.adult.per[c].active then allDone=false break end
  end
  if allDone then
    W.adult.stage = "DONE"
    broadcastToAll("✅ All Science Points allocated.", {0.7,1,0.7})
    -- Vocation selection now happens BEFORE science points allocation
    -- No need to trigger it here anymore
  end

  drawUI()
end

-- =========================================================
-- [S10] VOCATION SELECTION
-- =========================================================
-- Note: getSciencePoints() and calculateVocationSelectionOrder() are defined earlier
-- (before startVocationSelection) to ensure proper function order

-- Callback function for when a player confirms their vocation selection
function VOC_OnVocationSelected(params)
  -- Handle both table parameter and direct parameters (for compatibility)
  local color, vocation
  if type(params) == "table" then
    color = tostring(params.color or "")
    vocation = tostring(params.vocation or "")
  else
    -- Legacy: direct parameters (shouldn't happen, but handle it)
    color = tostring(params or "")
    vocation = tostring(vocation or "")
  end
  
  if not vocationSelectionState.active then
    log("Vocation selected but selection not active: " .. color .. " -> " .. vocation)
    return
  end
  
  local currentColor = vocationSelectionState.selectionOrder[vocationSelectionState.currentIndex]
  if color ~= currentColor then
    log("Vocation selected by wrong player: expected " .. currentColor .. ", got " .. color)
    return
  end
  
  -- Move to next player
  vocationSelectionState.currentIndex = vocationSelectionState.currentIndex + 1
  
  -- Clean up selection UI
  vocationsCall("VOC_CleanupSelection", {color = color})
  
  -- Process next player
  Wait.time(processNextVocationSelection, 1.0)
end

-- =========================================================
-- [S11B] AUTO PARK ESTATES
-- =========================================================
local function autoParkEstates()
  local m = getMarketController()
  if not m then
    broadcastToAll("⚠️ Auto-PARK Estates: no MarketController (tag "..TAG_MARKET_CTRL..").", {1,0.8,0.2})
    return false
  end

  local payload = { delay = AUTO_PARK_DELAY }

  if AUTO_PARK_SCAN then
    local ok = select(1, marketCall("miRequestParkAndScan", payload))
    if ok then
      log("Auto-PARK Estates: miRequestParkAndScan scheduled ("..AUTO_PARK_DELAY.."s)")
      return true
    end
  end

  local ok = select(1, marketCall("miRequestPark", payload))
  if ok then
    log("Auto-PARK Estates: miRequestPark scheduled ("..AUTO_PARK_DELAY.."s)")
    return true
  end

  broadcastToAll("⚠️ Auto-PARK Estates: MarketController missing miRequestPark/miRequestParkAndScan or call failed.", {1,0.8,0.2})
  return false
end

-- =========================================================
-- [S11C] START-GAME AUTOMATION (TokenEngine + ShopEngine)
-- =========================================================
local function startGameAutomation()
  -- Note: Shop reset is now called directly in startGame() BEFORE this function
  -- This function only handles token operations (they don't conflict with shop)
  
  local okCollect = select(1, tokenCall("API_collect", {}))
  if not okCollect then
    broadcastToAll("⚠️ StartAuto: TokenEngine API_collect not working (tag "..TAG_TOKEN_ENGINE..").", {1,0.8,0.2})
  else
    Wait.time(function()
      local okPrime = select(1, tokenCall("API_prime", {}))
      if not okPrime then
        broadcastToAll("⚠️ StartAuto: TokenEngine API_prime not working.", {1,0.8,0.2})
      end
    end, AUTO_TOKEN_PRIME_DELAY)
  end
end

-- =========================================================
-- [S11D] START GAME
-- =========================================================
local function startGame()
  if not W.orderDone then return end
  if startBusy then warn("startGame blocked: startBusy"); return end
  startBusy = true

  -- Always-unlock wrapper (prevents permanent lock after runtime error)
  local function unlockSoon()
    Wait.time(function() startBusy = false end, 0.2)
  end

  local function traceback(err)
    if debug and debug.traceback then
      return debug.traceback(err, 2)
    end
    return tostring(err)
  end

  local ok, err = xpcall(function()
    log("startGame: mode="..tostring(W.startMode).." finalOrder="..tostring((W.finalOrder and #W.finalOrder) or 0))

    evtAPI_setPlayers(W.playersN)
    evtAPI_setMode(EVT_DEFAULT_MODE)

    resetSatisfactionTo10()
    resetControllersByTag(TAG_STATS)
    resetControllersByTag(TAG_AP_CTRL)
    resetControllersByTag(TAG_MONEY)
    -- If money is embedded in boards, reset those too (safe if boards implement resetNewGame)
    resetControllersByTag(TAG_BOARD)
    resetControllersByTag("WLB_COSTS_CALC")  -- Reset costs calculator for new game

    vocationsCall("VOC_ResetForNewGame", {})  -- Clear vocations from previous game

    globalCall("WLB_NEW_GAME", {mode=W.startMode, players=W.playersN})

    local evt = getEvtController()
    if not evt then
      broadcastToAll("❌ EventController not found (tag "..TAG_EVT_CONTROLLER_A.." or "..TAG_EVT_CONTROLLER_B..").", {1,0.3,0.3})
      return
    end

    local okPrep = evtAPI_newGamePrep(W.startMode)
    if not okPrep then
      broadcastToAll("❌ EventController does not support NEW GAME PREP (WLB_EVT_NEWGAME / EVT_NEW_GAME_PREP).", {1,0.3,0.3})
      return
    end

    -- Reset shop FIRST and wait for it to complete before starting turns
    -- This ensures shop is fully reset before first turn (avoids busy state conflicts)
    local okShop = select(1, shopCall("API_reset", {}))
    if not okShop then
      broadcastToAll("⚠️ ShopEngine API_reset not working (tag "..TAG_SHOP_ENGINE..").", {1,0.8,0.2})
    end
    
    -- Continue with other startup tasks (tokens, estates) in parallel
    startGameAutomation()
    autoParkEstates()

    W.currentRound = W.roundStart
    tokenYearSetRound(W.currentRound)

    -- Wait for shop reset to complete before starting first turn
    -- Shop reset takes ~2 seconds (STEP_DELAY * 4 + 0.6), so wait a bit longer
    Wait.time(function()
      W.turnIndex = 1
      setActiveByTurnIndex()
    end, 2.5)  -- Wait for shop reset to complete

    -- Ensure player tokens land on Apartment L0 at game start (all active colors)
    Wait.time(function()
      tokenCall("API_placePlayerTokens", { colors = W.finalOrder })
    end, 0.25)

    if W.startMode == "ADULT" then
      log("startGame: calling adultInitFromOrderRolls()...")
      adultInitFromOrderRolls()
      log("startGame: after adultInitFromOrderRolls, W.adult.stage="..tostring(W.adult and W.adult.stage or "nil"))
      
      -- Vocation selection starts BEFORE Science Points allocation
      -- (triggered after all vocations are selected in VOC_OnVocationSelected)
      Wait.time(function()
        startVocationSelection()
      end, 1.5)
    else
      W.adult = {stage="IDLE", per={}}
      -- For YOUTH mode, vocation selection happens later (when transitioning to Adult)
      -- This will be handled separately
    end

    W.step = "RUNNING"
    W.endConfirm = nil
    drawUI()
  end, traceback)

  if not ok then
    warn("startGame crashed:\n"..tostring(err))
    broadcastToAll("❌ startGame crashed (check console).", {1,0.3,0.3})
  end

  unlockSoon()
end

-- =========================================================
-- [S12] PERSISTENCE
-- =========================================================
function onSave()
  return JSON.encode(W)
end

function onLoad(saved)
  math.randomseed(os.time())

  if saved and saved ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved) end)
    if ok and type(data)=="table" then W = data end
  end

  W.playersN    = clampPlayers(W.playersN)
  W.colors      = W.colors or {}
  W.rollOrder   = W.rollOrder or {}
  W.rolls       = W.rolls or {}
  W.finalOrder  = W.finalOrder or {}
  W.adult       = W.adult or {stage="IDLE", per={}}
  W.adult.per   = W.adult.per or {}
  if W.endConfirm and type(W.endConfirm) ~= "table" then W.endConfirm = nil end

  drawUI()
  print("[WLB TURN] loaded | step="..tostring(W.step).." mode="..tostring(W.startMode))
end

-- =========================================================
-- [S13] UI CORE
-- =========================================================
function noop() end

local function btn(label, fn, x, z, w, h, fs, tip)
  self.createButton({
    label=label,
    click_function=fn,
    function_owner=self,
    position={x, UIY, z},
    width=w, height=h, font_size=fs,
    tooltip=tip or ""
  })
end

function drawUI()
  self.clearButtons()

  btn("RESTART",  "ui_restart",  -1.10,  1.25, BTN_W_MED, BTN_H_MED, 180, "Reset wizard")
  btn("NEXT TURN","ui_nextTurn",  1.10,  1.25, BTN_W_MED, BTN_H_MED, 180, "Next player / next round")
  
  -- Diagnostic button (always visible)
  btn("🔍 UI DUMP", "ui_uidump", 0, 1.25, BTN_W_SM, BTN_H_SM, 140, "Dump UI/Vocations diagnostics to Notes")

  if W.step == "RUNNING" and W.endConfirm and W.endConfirm.color then
    local msg = "⚠️ YOU STILL HAVE\n"..tostring(W.endConfirm.apLeft).." AP LEFT\n\nEND TURN ANYWAY?"
    btn(msg, "noop", 0, 0.30, BTN_W_BIG, 720, 160, "")
    btn("✅ YES\nEND TURN", "ui_confirmEndTurnYes", -0.75, -0.70, BTN_W_MED, 520, 200, "")
    btn("⛔ NO\nCANCEL",   "ui_confirmEndTurnNo",  0.75, -0.70, BTN_W_MED, 520, 200, "")
    return
  end

  if W.step == "HOME" then
    btn("START\nYOUTH", "ui_startYouth", -1.10, 0.35, BTN_W_MED, BTN_H_BIG, BTN_FS_BIG, "TokenYear -> 1")
    btn("START\nADULT", "ui_startAdult",  1.10, 0.35, BTN_W_MED, BTN_H_BIG, BTN_FS_BIG, "TokenYear -> 6")
    btn("Wybierz tryb startu", "noop", 0, -0.70, BTN_W_BIG, 300, 150, "")

  elseif W.step == "PLAYERS" then
    btn("2 PLAYERS", "ui_p2", 0, 0.65, BTN_W_BIG, BTN_H_SM, 170, "Yellow, Blue")
    btn("3 PLAYERS", "ui_p3", 0, 0.05, BTN_W_BIG, BTN_H_SM, 170, "Yellow, Blue, Red")
    btn("4 PLAYERS", "ui_p4", 0, -0.55, BTN_W_BIG, BTN_H_SM, 170, "Yellow, Blue, Red, Green")
    btn("MODE="..tostring(W.startMode).." | ROUND="..tostring(W.roundStart), "noop", 0, -1.25, BTN_W_BIG, 280, 140, "")

  elseif W.step == "ORDER" then
    local parts = {}
    for i,c in ipairs(W.rollOrder) do
      local r = W.rolls[c]
      table.insert(parts, c..(r and ("="..r) or "= ?"))
    end
    btn("ROLL ORDER: "..table.concat(parts, " | "), "noop", 0, 0.85, BTN_W_BIG, 300, 120, "")

    if not W.orderDone then
      local c = W.rollOrder[W.rollIdx]
      local label = rollingNow and ("ROLLING...\n"..tostring(c)) or ("ROLL NOW:\n"..tostring(c))
      btn(label, "ui_rollNext", 0, 0.15, BTN_W_BIG, BTN_H_BIG, 210, "Roll die for current player")
      btn("After rolling is finished, START GAME will appear", "noop", 0, -0.90, BTN_W_BIG, 280, 130, "")
    else
      btn("START GAME", "ui_startGame", 0, 0.10, BTN_W_BIG, BTN_H_BIG, 230, "Reset + start rund")
    end

  elseif W.step == "RUNNING" then
    local active = getActiveColor() or "?"
    btn("ROUND: "..tostring(W.currentRound).." / "..MAX_ROUND, "noop", -1.10, 0.35, BTN_W_MED, 300, 150, "")
    btn("ACTIVE: "..tostring(active), "noop",  1.10, 0.35, BTN_W_MED, 300, 150, "")

    if W.startMode == "ADULT" then
      if not W.adult then
        W.adult = {stage="IDLE", per={}}
      end

      btn("ADULT START: "..tostring(W.adult.stage or "IDLE"), "noop", 0, 0.85, BTN_W_BIG, 280, 140, "")

      if W.adult.stage == "ALLOC" then
        if W.finalOrder and #W.finalOrder > 0 then
          for _,c in ipairs(W.finalOrder) do
            local st = W.adult.per and W.adult.per[c]
            if st and st.active then
              btn(c..": roll="..st.roll.." money="..st.money.." | POOL="..st.pool.." K="..st.k.." S="..st.s, "noop", 0, -0.05, BTN_W_BIG, 280, 130, "")

              _G["ui_k_"..c]     = function() adultAlloc(c,"K") end
              _G["ui_s_"..c]     = function() adultAlloc(c,"S") end
              _G["ui_apply_"..c] = function() adultApply(c) end

              btn("+K", "ui_k_"..c, -1.10, -0.75, BTN_W_MED, BTN_H_MED, 220, "")
              btn("+S", "ui_s_"..c,  1.10, -0.75, BTN_W_MED, BTN_H_MED, 220, "")
              btn("APPLY", "ui_apply_"..c, 0, -1.35, BTN_W_BIG, BTN_H_MED, 220, "Działa gdy POOL=0")
              break
            end
          end
        else
          btn("DEBUG: finalOrder empty or nil", "noop", 0, -0.85, BTN_W_BIG, 200, 120, "")
        end
      end
    end
  end
end

-- =========================================================
-- [S14] UI HANDLERS
-- =========================================================
function ui_restart()    resetWizard() end
function ui_startYouth() chooseMode("YOUTH") end
function ui_startAdult() chooseMode("ADULT") end
function ui_p2()         choosePlayers(2) end
function ui_p3()         choosePlayers(3) end
function ui_p4()         choosePlayers(4) end
function ui_rollNext()   doNextRoll() end
function ui_startGame()  startGame() end

function ui_confirmEndTurnYes()
  if W.step ~= "RUNNING" then return end
  local active = (W.endConfirm and W.endConfirm.color) or getActiveColor()
  W.endConfirm = nil

  local moved = evtAPI_autoNextTurn()
  if moved == false then
    drawUI()
    return
  end

  endTurnProcessing(active)
  finalizeAPAfterTurn(active)
  onTurnEnd_ExpireOneTurnStatuses(active)

  advanceTurn()
end

function ui_confirmEndTurnNo()
  W.endConfirm = nil
  drawUI()
end

function ui_nextTurn()
  if W.step ~= "RUNNING" then
    broadcastToAll("⛔ Start the game first (START GAME).", {1,0.6,0.2})
    return
  end

  if W.endConfirm then
    drawUI()
    return
  end

  local active = getActiveColor()
  if not active then
    warn("ui_nextTurn: no active color.")
    advanceTurn()
    return
  end

  local apLeft = apGetUnspentCount(active)
  if apLeft and apLeft > 0 then
    W.endConfirm = {color = active, apLeft = apLeft}
    drawUI()
    return
  end

  local moved = evtAPI_autoNextTurn()
  if moved == false then
    drawUI()
    return
  end

  endTurnProcessing(active)
  finalizeAPAfterTurn(active)
  onTurnEnd_ExpireOneTurnStatuses(active)

  advanceTurn()
end
