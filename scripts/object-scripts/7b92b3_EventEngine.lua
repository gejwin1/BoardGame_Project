-- =========================================================
-- WLB EVENT ENGINE v1.7.2 (TARGETED FIXES: AD_KARMA + CHILD AP UNLOCK + BABYSITTER/AUNTY)
-- Compatible with Event Controller:
--   - playCardFromUI({card_guid, player_color, slot_idx}) -> "DONE"/"WAIT_*"/"BLOCKED"/"IGNORED"/"ERROR"
--   - isObligatoryCard({card_guid})
--
-- v1.7.2 changes (ONLY what you asked for):
--  1) Adult KARMA now works exactly like Youth KARMA:
--     - NOT keep, instantly discarded (USED)
--     - adds GOOD_KARMA status token (via PlayerStatusController hub)
--  2) Child logic improved:
--     - Introduced per-round "childUnlock[color]" (0..child.apBlock) to partially unlock AP blocked by child
--     - End-of-round applies INACTIVE AP = (child.apBlock - childUnlock[color]) and resets unlock to 0
--  3) Babysitter & Aunty now interact with childUnlock:
--     - Babysitter unlocks 1 or 2 AP from child block (this round)
--     - Aunty dice special unlocks AP from child block (this round)
-- =========================================================

local DEBUG = true

-- =========================================================
-- SECTION 1) CONFIG
-- =========================================================

local REAL_DICE_GUID     = "14d4a4"
-- Dice read can be slow if physics keeps the die rolling (or it falls).
-- Use a slightly longer timeout and fewer stable reads to reduce "no resolution" cases.
local DICE_ROLL_TIMEOUT  = 6.0
local DICE_STABLE_READS  = 3
local DICE_POLL          = 0.12
local diceHome           = nil

local TAG_STATS_CTRL        = "WLB_STATS_CTRL"
local TAG_AP_CTRL           = "WLB_AP_CTRL"
local TAG_MONEY             = "WLB_MONEY"
local TAG_SHOP_ENGINE       = "WLB_SHOP_ENGINE"
local TAG_MARKET_CTRL       = "WLB_MARKET_CTRL"
local COLOR_TAG_PREFIX      = "WLB_COLOR_"

-- PlayerStatusController hub
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"
-- VocationsController (salary per AP for work bonus)
local TAG_VOCATIONS_CTRL    = "WLB_VOCATIONS_CTRL"

-- Keep/discard targets are found by TAG (can be Zone or any marker object with position)
local TAG_KEEP_ZONE         = "WLB_KEEP_ZONE"
local TAG_DISCARD_ZONE      = "WLB_EVENT_DISCARD_ZONE" -- legacy
local TAG_DISCARD_ZONE_ALT  = "WLB_EVT_USED_ZONE"      -- new used zone
local TAG_COSTS_CALC        = "WLB_COSTS_CALC"
local TAG_BOARD             = "WLB_BOARD"              -- Player board tag

-- Status token tags (TokenEngine expects these tags)
local STATUS_TAG = {
  GOODKARMA = "WLB_STATUS_GOOD_KARMA",
  DATING   = "WLB_STATUS_DATING",
  SICK     = "WLB_STATUS_SICK",
  WOUNDED  = "WLB_STATUS_WOUNDED",
  ADDICT   = "WLB_STATUS_ADDICTION",
  EXP      = "WLB_STATUS_EXPERIENCE",
  VOUCH_C  = "WLB_STATUS_VOUCH_C",   -- 25% discount Consumables
  VOUCH_H  = "WLB_STATUS_VOUCH_H",   -- 25% discount Hi-Tech
  VOUCH_P  = "WLB_STATUS_VOUCH_P",   -- 20% discount Properties
}

local SAT_TOKEN_GUIDS = {
  Yellow = "d33a15",
  Red    = "6fe69b",
  Blue   = "b2b5e3",
  Green  = "e8834c",
}

local PREFIXES = { "YD_", "AD_", "CS_", "HS_", "IS_", "JOB_" }

-- =========================================================
-- SECTION 1a) STATUS CONSTANTS
-- =========================================================

local STATUS = {
  DONE        = "DONE",
  WAIT_CHOICE = "WAIT_CHOICE",
  WAIT_DICE   = "WAIT_DICE",
  BLOCKED     = "BLOCKED",
  IGNORED     = "IGNORED",
  ERROR       = "ERROR",
}

-- =========================================================
-- SECTION 1b) STATE
-- =========================================================

local activeColor = nil

local recentlyPlayed = {}     -- [cardGuid] = Time.time
local DEBOUNCE_SEC = 2.0

local lockUntil = {}          -- [cardGuid] = Time.time + sec
local LOCK_SEC = 8.0

local pendingDice   = {}      -- [cardGuid] = { color, kind, diceKey, cardId }
local pendingChoice = {}      -- [cardGuid] = { color, kind, choiceKey, cardId, meta }

-- Store slot extra AP for CAR coordination (set by playCardFromUI, used by playCardById)
local slotExtraAPForCard = {}  -- [cardGuid] = extra AP amount

-- adult state
local married = { Yellow=false, Blue=false, Red=false, Green=false }

-- child state:
-- child[color] = { active=true, cost=100/150/200, sat=2, apBlock=2, gender="BOY/GIRL" }
local child = { Yellow=nil, Blue=nil, Red=nil, Green=nil }

-- NEW: per-round unlock of child AP block (0..child.apBlock)
local childUnlock = { Yellow=0, Blue=0, Red=0, Green=0 }

-- Broken hi-tech items: [color] = {cardName1=true, cardName2=true, ...}
local brokenHiTech = { Yellow={}, Blue={}, Red={}, Green={} }

-- =========================================================
-- SECTION 1c) UTILS
-- =========================================================

local function log(msg)  if DEBUG then print("[WLB EVENT] " .. tostring(msg)) end end
local function warn(msg) print("[WLB EVENT][WARN] " .. tostring(msg)) end
local function colorTag(color) return COLOR_TAG_PREFIX .. tostring(color) end

-- Forward declaration (Lua local visibility rule):
-- resolveMoney() uses findOneByTags(), so we must declare it before resolveMoney is defined.
local findOneByTags

-- Money resolver: supports legacy money tiles OR player boards with embedded money API
local function resolveMoney(color)
  color = tostring(color or "")
  if color == "" then return nil end

  -- IMPORTANT:
  -- If both exist (legacy money tile + new money-on-board), we must prefer the board
  -- to avoid using the old tile by accident.

  -- 1) Player board with embedded money API (PlayerBoardController_Shared)
  local b = findOneByTags({TAG_BOARD, colorTag(color)})
  if b and b.call then
    local ok = pcall(function() return b.call("getMoney") end)
    if ok then return b end
  end

  -- 2) Legacy money tile
  local m = findOneByTags({TAG_MONEY, colorTag(color)})
  if m then return m end

  return nil
end

local function safeCall(fn)
  local ok, res = pcall(fn)
  if ok then return true, res end
  return false, nil
end

local function safeBroadcastTo(color, msg, rgb)
  rgb = rgb or {1,1,1}
  if color and Player[color] and Player[color].seated then
    broadcastToColor(tostring(msg), color, rgb)
  else
    broadcastToAll((color and ("["..tostring(color).."] ") or "") .. tostring(msg), rgb)
  end
end

local function startsWithAnyPrefix(id)
  if not id then return false end
  for _, p in ipairs(PREFIXES) do
    if string.sub(id, 1, #p) == p then return true end
  end
  return false
end

local function extractCardId(cardObj)
  if not cardObj then return nil end

  local name = (cardObj.getName and cardObj.getName()) or ""
  local id = name:match("^(%S+)")
  if id and id ~= "" and startsWithAnyPrefix(id) then return id end

  local desc = (cardObj.getDescription and cardObj.getDescription()) or ""
  local id2 = desc:match("^(%S+)")
  if id2 and id2 ~= "" and startsWithAnyPrefix(id2) then return id2 end

  return nil
end

findOneByTags = function(tags)
  for _, o in ipairs(getAllObjects()) do
    local ok = true
    for _, t in ipairs(tags) do
      if not (o and o.hasTag and o.hasTag(t)) then ok = false break end
    end
    if ok then return o end
  end
  return nil
end

local function normalizeColor(color)
  if not color or type(color) ~= "string" or color == "" then return color end
  return color:sub(1,1):upper() .. color:sub(2):lower()
end

local function getPlayerColor()
  local color = nil
  if Turns and Turns.turn_color and Turns.turn_color ~= "" then
    color = Turns.turn_color
  else
    color = activeColor
  end
  
  -- Normalize color format (capitalize first letter, lowercase rest) to match Shop Engine storage
  return normalizeColor(color)
end

-- =========================================================
-- SECTION 1d) PlayerStatusController bridge
-- =========================================================

local function findPlayerStatusCtrl()
  local list = getObjectsWithTag(TAG_PLAYER_STATUS_CTRL) or {}
  if #list > 0 then return list[1] end
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_PLAYER_STATUS_CTRL) then return o end
  end
  return nil
end

local function PS_EventCall(payload)
  local ctrl = findPlayerStatusCtrl()
  if not ctrl or not ctrl.call then
    warn("PlayerStatusCtrl not found (tag="..TAG_PLAYER_STATUS_CTRL..")")
    return false
  end
  local ok, res = pcall(function()
    return ctrl.call("PS_Event", payload or {})
  end)
  if not ok then
    warn("PS_EventCall failed: "..tostring(res))
    return false
  end
  return (res ~= false)
end

local function PS_AddStatus(color, statusTag)
  if not color or not statusTag then return false end
  return PS_EventCall({ color=color, op="ADD_STATUS", statusTag=statusTag })
end

local function PS_RemoveStatus(color, statusTag)
  if not color or not statusTag then return false end
  return PS_EventCall({ color=color, op="REMOVE_STATUS", statusTag=statusTag })
end

-- Check if player has DATING status token (required for marriage)
-- Uses PlayerStatusController as central authority (queries TokenEngine's internal state)
local function hasDatingStatus(color)
  if not color then return false end
  color = normalizeColor(color)
  
  -- Query PlayerStatusController (central authority for all status queries)
  local ctrl = findPlayerStatusCtrl()
  if not ctrl or not ctrl.call then
    warn("hasDatingStatus: PlayerStatusController not found, cannot check DATING status")
    return false
  end
  
  -- Use PS_Event with HAS_STATUS operation (queries TokenEngine's internal state)
  local ok, hasStatus = pcall(function()
    return ctrl.call("PS_Event", {color=color, op="HAS_STATUS", statusTag=STATUS_TAG.DATING})
  end)
  
  if not ok then
    warn("hasDatingStatus: PS_Event call failed: "..tostring(hasStatus))
    return false
  end
  
  if type(hasStatus) == "boolean" then
    if hasStatus then
      log("hasDatingStatus: Player "..tostring(color).." has DATING status")
    end
    return hasStatus
  end
  
  warn("hasDatingStatus: PS_Event returned invalid result type: "..type(hasStatus))
  return false
end

local function PS_AddMarriage(color)
  if not color then return false end
  return PS_EventCall({ color=color, op="ADD_MARRIAGE" })
end

-- Find and call Cost Calculator to add baby costs
local function addBabyCostToCalculator(color, cost)
  cost = tonumber(cost) or 0
  if cost <= 0 then return end
  
  -- Use findOneByTags for consistent tag searching (same as other functions)
  local costsCalc = findOneByTags({TAG_COSTS_CALC})
  
  if costsCalc and costsCalc.call then
    local ok, result = pcall(function()
      return costsCalc.call("addCost", {color=color, amount=cost})
    end)
    if ok then
      log("Baby cost: "..color.." added "..tostring(cost).." WIN per turn for baby")
      return true
    else
      warn("Baby cost: Failed to add cost to calculator: "..tostring(result))
      return false
    end
  else
    warn("Costs Calculator not found for baby cost (tag: "..TAG_COSTS_CALC..")")
    return false
  end
end

local function PS_AddChild(color, sex)
  if not color or not sex then return false end
  return PS_EventCall({ color=color, op="ADD_CHILD", sex=sex })
end

-- Salary per AP from current vocation (for work bonus card)
local function getSalaryPerAP(color)
  if not color then return 0 end
  color = normalizeColor(color)
  local voc = findOneByTags({TAG_VOCATIONS_CTRL})
  if not voc or not voc.call then return 0 end
  local ok, salary = pcall(function() return voc.call("VOC_GetSalary", { color = color }) end)
  if not ok or type(salary) ~= "number" then return 0 end
  return math.max(0, salary)
end

-- =========================================================
-- SECTION 2) MONEY / SAT / STATS / AP
-- =========================================================

local function moneyAdd(moneyObj, delta)
  if not moneyObj or not moneyObj.call then return false end
  local ok = pcall(function() moneyObj.call("addMoney", { amount = delta }) end)
  if ok then return true end
  ok = pcall(function() moneyObj.call("addMoney", { delta = delta }) end)
  return ok
end

local function moneyGet(moneyObj)
  if not moneyObj or not moneyObj.call then return nil end
  local ok, v

  ok, v = pcall(function() return moneyObj.call("getMoney") end)
  if ok and type(v) == "number" then return v end

  ok, v = pcall(function() return moneyObj.call("getValue") end)
  if ok and type(v) == "number" then return v end

  ok, v = pcall(function() return moneyObj.call("getAmount") end)
  if ok and type(v) == "number" then return v end

  ok, v = pcall(function() return moneyObj.call("getState") end)
  if ok and type(v) == "table" and type(v.money) == "number" then return v.money end

  return nil
end

local function canAfford(color, negativeDelta)
  local moneyObj = resolveMoney(color)
  if not moneyObj then return false end
  local cur = moneyGet(moneyObj)
  if type(cur) ~= "number" then return false end
  return (cur + (tonumber(negativeDelta) or 0)) >= 0
end

local function getSatToken(color)
  local guid = SAT_TOKEN_GUIDS[tostring(color or "")]
  if not guid then
    warn("SAT GUID missing for color="..tostring(color))
    return nil
  end
  local obj = getObjectFromGUID(guid)
  if not obj then
    warn("SAT token GUID not found: "..tostring(color).." guid="..tostring(guid))
    return nil
  end
  return obj
end

local function satAdd(satObj, delta, dbgLabel)
  if not satObj then return false end
  delta = tonumber(delta) or 0
  if delta == 0 then return true end

  pcall(function() satObj.setLock(false) end)

  local ok = false
  if satObj.call then
    ok = pcall(function() satObj.call("addSat", { delta = delta }) end)
  end

  if (not ok) and satObj.call then
    local stepFn = (delta >= 0) and "p1" or "m1"
    local n = math.abs(delta)
    for _=1,n do
      local ok2 = pcall(function() satObj.call(stepFn) end)
      if not ok2 then
        warn("SAT CALL FAILED: "..tostring(stepFn))
        return false
      end
    end
    ok = true
  end

  if DEBUG and dbgLabel then
    log("SAT "..tostring(dbgLabel).." delta="..tostring(delta).." ok="..tostring(ok))
  end
  return ok
end

local function statsApply(statsCtrl, d)
  if not d or not statsCtrl or not statsCtrl.call then return false end

  local ok = pcall(function() statsCtrl.call("applyDelta", d) end)
  if ok then return true end

  local function clickMany(fnPlus, fnMinus, val)
    local v = tonumber(val) or 0
    if v == 0 then return true end
    local fn = (v > 0) and fnPlus or fnMinus
    local n = math.abs(v)
    for _=1,n do
      local ok2 = pcall(function() statsCtrl.call(fn) end)
      if not ok2 then return false end
    end
    return true
  end

  local okH = clickMany("pb_h_plus","pb_h_minus", d.h)
  local okK = clickMany("pb_k_plus","pb_k_minus", d.k)
  local okS = clickMany("pb_s_plus","pb_s_minus", d.s)
  return okH and okK and okS
end

local function getApCtrl(color)
  return findOneByTags({TAG_AP_CTRL, colorTag(color)})
end

-- Find Shop Engine and check if player owns CAR (for -1 AP cost reduction)
local function hasCarReduction(color)
  if not color then 
    log("CAR check: no color provided")
    return false 
  end
  
  -- Normalize color to match Shop Engine's storage format (capitalize first letter, lowercase rest)
  local normalizedColor = color
  if type(color) == "string" and color ~= "" then
    normalizedColor = color:sub(1,1):upper() .. color:sub(2):lower()
  end
  
  local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
  if not shopEngine or not shopEngine.call then 
    warn("CAR check: Shop Engine not found (tag "..TAG_SHOP_ENGINE..")")
    return false 
  end
  
  local ok, hasCar = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=normalizedColor, kind="CAR"})
  end)
  
  if not ok then
    warn("CAR check: API call failed for "..tostring(normalizedColor).." error="..tostring(hasCar))
    return false
  end
  
  local result = (ok and hasCar == true)
  if result then
    log("CAR check: "..tostring(normalizedColor).." HAS CAR (reduction active)")
  else
    log("CAR check: "..tostring(normalizedColor).." NO CAR (ok="..tostring(ok).." hasCar="..tostring(hasCar)..")")
  end
  
  return result
end

-- Get count of owned hi-tech items for a player (for luxury tax)
local function getOwnedHiTechCount(color)
  color = normalizeColor(color)
  if not color or color == "" then return 0 end
  
  local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
  if not shopEngine or not shopEngine.call then
    warn("Luxury Tax: Shop Engine not found")
    return 0
  end
  
  local ok, ownedList = pcall(function()
    return shopEngine.call("API_getOwnedHiTech", {color=color})
  end)
  
  if not ok or type(ownedList) ~= "table" then
    warn("Luxury Tax: Failed to get owned hi-tech list for "..color)
    return 0
  end
  
  return #ownedList
end

-- Get current estate level for a player (for property tax)
-- Returns level number: L0=0, L1=1, L2=2, L3=3, L4=4
local function getCurrentEstateLevel(color)
  color = normalizeColor(color)
  if not color or color == "" then return 0 end
  
  -- Try to find EstateEngine and query current level
  local estateEngine = findOneByTags({TAG_MARKET_CTRL})
  if estateEngine and estateEngine.call then
    local ok, level = pcall(function()
      -- EstateEngine might expose an API, or we can check estate cards directly
      -- For now, check for placed estate cards on player board
      local TAG_ESTATE_OWNED = "WLB_ESTATE_OWNED"
      local colorTagStr = colorTag(color)
      
      for _, o in ipairs(getAllObjects()) do
        if o and o.hasTag and o.hasTag(TAG_ESTATE_OWNED) and o.hasTag(colorTagStr) then
          local name = o.getName and o.getName() or ""
          -- Check card name pattern: ESTATE_L1, ESTATE_L2, etc.
          if name:match("ESTATE_L([1-4])") then
            local levelNum = tonumber(name:match("ESTATE_L([1-4])"))
            if levelNum then return levelNum end
          end
        end
      end
      return nil
    end)
    
    if ok and level and type(level) == "number" then
      return level
    end
  end
  
  -- Fallback: check for estate cards directly
  local TAG_ESTATE_OWNED = "WLB_ESTATE_OWNED"
  local colorTagStr = colorTag(color)
  
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_ESTATE_OWNED) and o.hasTag(colorTagStr) then
      local name = o.getName and o.getName() or ""
      if name:match("ESTATE_L([1-4])") then
        local levelNum = tonumber(name:match("ESTATE_L([1-4])"))
        if levelNum then return levelNum end
      end
    end
  end
  
  -- Default: L0 (grandma's house) = 0
  return 0
end

local function tryPayAPOrBlock(color, apCost)
  if not apCost or not apCost.amount then return true end
  local amount = tonumber(apCost.amount) or 0
  if amount <= 0 then return true end

  local apCtrl = getApCtrl(color)
  if not apCtrl or not apCtrl.call then
    warn("AP CTRL not found for "..tostring(color).." -> BLOCK card.")
    return false
  end

  local okCan, can = pcall(function() return apCtrl.call("canSpendAP", apCost) end)
  if (not okCan) or (can ~= true) then
    log(color.." NOT ENOUGH AP for "..tostring(amount).." -> "..tostring(apCost.to).." (blocked)")
    return false
  end

  local okPay, paid = pcall(function() return apCtrl.call("spendAP", apCost) end)
  if (not okPay) or (paid ~= true) then
    warn(color.." spendAP failed (blocked).")
    return false
  end

  return true
end

local function applyAP_Move(color, apEff)
  if not apEff or not apEff.amount then return true end
  local amount = tonumber(apEff.amount) or 0
  if amount <= 0 then return true end

  local apCtrl = getApCtrl(color)
  if not apCtrl or not apCtrl.call then
    warn("AP CTRL not found for "..tostring(color).." -> cannot apply AP effect.")
    return false
  end

  local okMove = pcall(function() apCtrl.call("moveAP", apEff) end)
  if not okMove then
    warn("moveAP() not supported by AP CTRL.")
    return false
  end
  return true
end

-- Party-with-friends (HANGOVER) fix: move N AP to INACTIVE; if player has no available AP,
-- take the shortfall from REST and move those to INACTIVE as well.
local function applyAP_ToInactive_WithRestFallback(color, amount, duration)
  if not amount or (tonumber(amount) or 0) <= 0 then return true end
  amount = tonumber(amount) or 0
  local apCtrl = getApCtrl(color)
  if not apCtrl or not apCtrl.call then
    warn("AP CTRL not found for "..tostring(color).." -> cannot apply hangover AP.")
    return false
  end

  local apEff = { to = "INACTIVE", amount = amount }
  if duration then apEff.duration = duration end

  local ok, ret = pcall(function() return apCtrl.call("moveAP", apEff) end)
  if not ok then
    warn("moveAP(INACTIVE) failed for "..tostring(color))
    return false
  end

  local moved = (type(ret) == "table" and (tonumber(ret.moved) or 0)) or 0
  local shortfall = math.max(0, amount - moved)

  if shortfall <= 0 then return true end

  -- Get REST count (AP controller may use area="REST" or field="REST")
  local restCount = 0
  pcall(function()
    restCount = apCtrl.call("getCount", { area = "REST" })
      or apCtrl.call("getCount", { field = "REST" })
      or apCtrl.call("getCount", { to = "REST" })
      or 0
    restCount = tonumber(restCount) or 0
  end)

  local takeFromRest = math.min(shortfall, restCount)
  if takeFromRest <= 0 then return true end

  -- Move from REST to START, then from START to INACTIVE
  pcall(function() apCtrl.call("moveAP", { to = "REST", amount = -takeFromRest }) end)
  pcall(function()
    apCtrl.call("moveAP", { to = "INACTIVE", amount = takeFromRest, duration = duration })
  end)
  safeBroadcastTo(color, "🍻 Hangover: "..tostring(takeFromRest).." AP taken from REST to INACTIVE (no free AP left).", {0.9,0.7,0.4})
  return true
end

local function applyToPlayer_NoAP(color, effect, dbgLabel)
  if not effect then return true end

  if effect.money and effect.money ~= 0 then
    local moneyObj = resolveMoney(color)
    if not moneyObj then
      warn("Money object not found for "..tostring(color))
      safeBroadcastTo(color, "⛔ Money controller missing. Add PlayerBoardController_Shared to your player board (WLB_BOARD + WLB_COLOR_"..tostring(color)..") or restore legacy WLB_MONEY tile.", {1,0.6,0.2})
      return false
    end
    local ok = moneyAdd(moneyObj, effect.money)
    if not ok then warn("Money API mismatch for "..tostring(color)) end
  end

  if effect.sat and effect.sat ~= 0 then
    local satObj = getSatToken(color)
    if not satObj then return false end
    local ok = satAdd(satObj, effect.sat, dbgLabel or ("SAT:"..tostring(color)))
    if not ok then warn("SAT API mismatch for "..tostring(color)) end
  end

  if effect.stats then
    local statsCtrl = findOneByTags({TAG_STATS_CTRL, colorTag(color)})
    if not statsCtrl then warn("STATS CTRL not found for "..tostring(color)); return false end
    local ok = statsApply(statsCtrl, effect.stats)
    if not ok then warn("STATS API mismatch for "..tostring(color)) end
  end

  return true
end

local function applyEffect_WithAPMove_NoCost(color, eff, dbgLabel)
  eff = eff or {}

  if eff.money and eff.money < 0 then
    if not canAfford(color, eff.money) then
      warn("BLOCKED: not enough money (cannot go below 0).")
      return false
    end
  end

  if eff.ap then
    if not applyAP_Move(color, eff.ap) then return false end
  end

  local rest = {}
  for k,v in pairs(eff) do
    if k ~= "ap" then rest[k] = v end
  end
  return applyToPlayer_NoAP(color, rest, dbgLabel or ("applyEffect:"..tostring(color)))
end

-- =========================================================
-- SECTION 3) LOCK / DEBOUNCE
-- =========================================================

local function isLocked(guid)
  local t = guid and lockUntil[guid]
  return (t ~= nil) and (Time.time < t)
end

local function lockCard(guid, sec)
  if not guid then return end
  lockUntil[guid] = Time.time + (sec or LOCK_SEC)
end

local function clearDebounce(guid)
  if guid then recentlyPlayed[guid] = nil end
end

-- =========================================================
-- SECTION 4) FINALIZE
-- =========================================================

local function findDiscardTarget()
  return findOneByTags({TAG_DISCARD_ZONE}) or findOneByTags({TAG_DISCARD_ZONE_ALT})
end

local function finalizeCard(cardObj, kind, color)
  if not cardObj then return end
  pcall(function() cardObj.clearButtons() end)

  kind = kind or "instant"

  if kind == "keep" then
    pcall(function()
      cardObj.addTag("WLB_KEEP")
      cardObj.addTag(colorTag(color))
    end)

    local target = findOneByTags({TAG_KEEP_ZONE, colorTag(color)})
    local p = (target and target.getPosition and target.getPosition()) or self.getPosition()
    cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true)
    return
  end

  local target = findDiscardTarget()
  local p = (target and target.getPosition and target.getPosition()) or self.getPosition()
  cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true)
end

-- =========================================================
-- SECTION 5) CARD UI
-- =========================================================

function noop_engine() end

local function cardUI_clear(cardObj)
  if not cardObj then return end
  pcall(function() cardObj.clearButtons() end)
end

local function cardUI_title(cardObj, text)
  if not cardObj then return end
  cardObj.createButton({
    click_function = "noop_engine",
    function_owner = self,
    label = text or "",
    position = {0, 0.65, 0},
    rotation = {0, 0, 0},
    width = 0, height = 0,
    font_size = 160,
    tooltip = ""
  })
end

local function cardUI_btn(cardObj, label, fn, posZ)
  if not cardObj then return end
  cardObj.createButton({
    click_function = fn,
    function_owner = self,
    label = label,
    position = {0, 0.65, posZ or 0},
    rotation = {0, 0, 0},
    width = 2100, height = 420,
    font_size = 240,
    tooltip = ""
  })
end

local function startDiceOnCard(cardObj, color, defKind, diceKey, cardId)
  local g = cardObj.getGUID()
  pendingDice[g] = { color=color, kind=defKind, diceKey=diceKey, cardId=cardId }
  lockCard(g, LOCK_SEC)

  cardUI_clear(cardObj)
  cardUI_title(cardObj, "ROLL D6")
  cardUI_btn(cardObj, "ROLL", "evt_roll", -1.0)
  cardUI_btn(cardObj, "CANCEL", "evt_cancelPending", 1.0)

  safeBroadcastTo(color, "Dice required. Click ROLL on the card.", {1,1,1})
end

local function startChoiceOnCard_AB(cardObj, color, defKind, choiceKey, cardId, labelA, labelB, meta)
  local g = cardObj.getGUID()
  pendingChoice[g] = { color=color, kind=defKind, choiceKey=choiceKey, cardId=cardId, meta=meta or {} }
  lockCard(g, LOCK_SEC)

  cardUI_clear(cardObj)
  cardUI_title(cardObj, "CHOOSE")
  cardUI_btn(cardObj, labelA or "A", "evt_choiceA", -1.0)
  cardUI_btn(cardObj, labelB or "B", "evt_choiceB", 0.4)
  cardUI_btn(cardObj, "CANCEL", "evt_cancelPending", 1.8)

  safeBroadcastTo(color, "Choice required. Pick one option on the card.", {1,1,1})
end

function evt_cancelPending(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  pendingDice[g] = nil
  pendingChoice[g] = nil
  cardUI_clear(cardObj)
  lockCard(g, LOCK_SEC)
  clearDebounce(g)
  safeBroadcastTo(player_color, "Cancelled. You can click YES again if needed.", {1,0.8,0.3})
end

-- =========================================================
-- SECTION 6) REAL DIE
-- =========================================================

local function getRealDie()
  if not REAL_DICE_GUID or REAL_DICE_GUID == "" then return nil end
  return getObjectFromGUID(REAL_DICE_GUID)
end

local function cacheDieHomeIfNeeded(die)
  if diceHome or not die then return end
  local p = die.getPosition()
  local r = die.getRotation()
  diceHome = { pos={x=p.x,y=p.y,z=p.z}, rot={x=r.x,y=r.y,z=r.z} }
end

local function moveDieNearCard(die, cardObj)
  if not die or not cardObj then return end
  -- Moving the die near the card sometimes causes it to fall off the board/table.
  -- Prefer rolling at the cached home position (usually a safe area on the table).
  if diceHome and diceHome.pos then
    die.setPositionSmooth({diceHome.pos.x, diceHome.pos.y + 2.0, diceHome.pos.z}, false, true)
    return
  end
  local cp = cardObj.getPosition()
  die.setPositionSmooth({cp.x + 1.3, cp.y + 2.0, cp.z + 0.4}, false, true)
end

local function returnDieHome(die)
  if not die or not diceHome then return end
  die.setPositionSmooth({diceHome.pos.x, diceHome.pos.y, diceHome.pos.z}, false, true)
  die.setRotationSmooth({diceHome.rot.x, diceHome.rot.y, diceHome.rot.z}, false, true)
end

local function tryReadDieValue(die)
  if not die then return nil end
  if die.getValue then
    local ok, v = pcall(function() return die.getValue() end)
    if ok and type(v) == "number" and v >= 1 and v <= 6 then return v end
  end
  return nil
end

local function rollRealDieAsync(cardObj, onDone)
  local die = getRealDie()
  if not die then onDone(nil, "Die not found"); return end

  cacheDieHomeIfNeeded(die)
  moveDieNearCard(die, cardObj)
  pcall(function() die.randomize() end)

  local startT = Time.time
  local last, stable = nil, 0

  local function poll()
    if (Time.time - startT) > DICE_ROLL_TIMEOUT then onDone(nil, "Timeout"); return end
    local v = tryReadDieValue(die)

    if v and v == last then stable = stable + 1
    elseif v then last = v; stable = 1
    else stable = 0 end

    if stable >= DICE_STABLE_READS then onDone(last, nil); return end
    Wait.time(poll, DICE_POLL)
  end

  Wait.time(poll, 0.18)
end

-- =========================================================
-- SECTION 7) CHILD UNLOCK MECHANIC (NEW)
-- =========================================================

local function hasActiveChild(color)
  return (child[color] and child[color].active == true)
end

local function childMaxBlock(color)
  if not hasActiveChild(color) then return 0 end
  return tonumber(child[color].apBlock) or 2
end

local function addChildUnlock(color, amount)
  if not hasActiveChild(color) then
    safeBroadcastTo(color, "👶 AP Unlock: no child.", {0.8,0.8,0.8})
    return false
  end
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end

  local cap = childMaxBlock(color)
  local cur = tonumber(childUnlock[color]) or 0
  local nxt = math.min(cap, cur + amount)
  childUnlock[color] = nxt

  safeBroadcastTo(color, "👶 Unlocked "..tostring(nxt-cur).." AP from child lock (this round).", {0.7,1,0.7})
  return true
end

-- =========================================================
-- SECTION 8) CARD MAP (unchanged mapping)
-- =========================================================

local CARD_TYPE = {}

local function mapPair(id1, id2, typeKey)
  CARD_TYPE[id1] = typeKey
  CARD_TYPE[id2] = typeKey
end

local function mapRange(prefix, a, b, typeKey, suffix)
  suffix = suffix or ""
  for i=a,b do
    local n = (i < 10) and ("0"..tostring(i)) or tostring(i)
    CARD_TYPE[prefix..n..suffix] = typeKey
  end
end

-- YOUTH
mapRange("YD_", 1, 5, "DATE", "_DATE")
mapRange("YD_", 6, 8, "PARTY", "_PARTY")
mapRange("YD_", 9,10, "VOLUNTARY", "_VOLUNTARY")
mapRange("YD_",13,14, "MENTORSHIP", "_MENTORSHIP")
mapRange("YD_",11,12, "BEAUTY", "_BEAUTY")
mapRange("YD_",15,16, "BIRTHDAY", "_BIRTHDAY")

mapPair("YD_17_WORK1-150","YD_18_WORK1-150","WORK1_150")
mapPair("YD_19_WORK2-200","YD_20_WORK2-200","WORK2_200")
mapPair("YD_21_WORK3-250","YD_22_WORK3-250","WORK3_250")
mapPair("YD_23_WORK3-300","YD_24_WORK3-300","WORK3_300")
mapPair("YD_25_WORK5-500","YD_26_WORK5-500","WORK5_500")
mapPair("YD_27_VOUCH-HI","YD_28_VOUCH-HI","VOUCH_HI")
mapPair("YD_29_VOUCH-CONS","YD_30_VOUCH-CONS","VOUCH_CONS")
mapRange("YD_",31,35,"SICK_O","_SICK_O")
mapPair("YD_36_LOAN_O","YD_37_LOAN_O","LOAN_O")
mapPair("YD_38_KARMA","YD_39_KARMA","KARMA")

-- ADULT (1-57)
mapRange("AD_", 1, 5, "AD_SICK_O", "_SICK_O")
-- Also map variant with zero suffix (AD_XX_SICK_0) for compatibility
mapRange("AD_", 1, 5, "AD_SICK_O", "_SICK_0")
mapRange("AD_", 6, 9, "AD_VOUCH_CONS", "_VOUCH-CONS")
mapRange("AD_",10,11, "AD_VOUCH_HI", "_VOUCH-HI")
mapRange("AD_",12,13, "AD_LUXTAX_O", "_LUXTAX_O")
mapRange("AD_",14,15, "AD_PROPTAX_O", "_PROPTAX_O")
mapRange("AD_",16,20, "AD_DATE", "_DATE")
mapRange("AD_",21,23, "AD_CHILD100_O", "_CHILD100_O")
mapRange("AD_",24,26, "AD_CHILD150_O", "_CHILD150_O")
mapRange("AD_",27,29, "AD_CHILD200_O", "_CHILD200_O")
mapRange("AD_",30,31, "AD_HI_FAIL_O", "_HI-FAIL_O")
mapRange("AD_",32,34, "AD_WORKBONUS", "_WORKBONUS")
mapRange("AD_",35,41, "AD_MARRIAGE", "_MARRIAGE")
mapRange("AD_",42,43, "AD_VOUCH_PROP", "_VOUCH-PROP")
mapRange("AD_",44,46, "AD_KARMA", "_KARMA")
CARD_TYPE["AD_47_AUCTION_O"] = "AD_AUCTION_O"
mapRange("AD_",48,50, "AD_SPORT", "_SPORT")
mapPair("AD_51_BABYSITTER50","AD_52_BABYSITTER50","AD_BABYSITTER50")
mapPair("AD_53_BABYSITTER70","AD_54_BABYSITTER70","AD_BABYSITTER70")
mapRange("AD_",55,57, "AD_AUNTY_O", "_AUNTY_O")

-- VE pairs 58-81
mapPair("AD_58_VE-NGO2-SOC1","AD_59_VE-NGO2-SOC1","AD_VE_NGO2_SOC1")
mapPair("AD_60_VE-NGO1-GAN1","AD_61_VE-NGO1-GAN1","AD_VE_NGO1_GAN1")
mapPair("AD_62_VE-NGO1-ENT1","AD_63_VE-NGO1-ENT1","AD_VE_NGO1_ENT1")
mapPair("AD_64_VE-NGO2-CEL1","AD_65_VE-NGO2-CEL1","AD_VE_NGO2_CEL1")
mapPair("AD_66_VE-SOC2-CEL1","AD_67_VE-SOC2-CEL1","AD_VE_SOC2_CEL1")
mapPair("AD_68_VE-SOC1-PUB1","AD_69_VE-SOC1-PUB1","AD_VE_SOC1_PUB1")
mapPair("AD_70_VE-GAN1-PUB2","AD_71_VE-GAN1-PUB2","AD_VE_GAN1_PUB2")
mapPair("AD_72_VE-ENT1-PUB1","AD_73_VE-ENT1_PUB1","AD_VE_ENT1_PUB1") -- harmless if typo exists in your cards
mapPair("AD_74_VE-CEL2-PUB2","AD_75_VE-CEL2-PUB2","AD_VE_CEL2_PUB2")
mapPair("AD_76_VE-CEL2-GAN2","AD_77_VE-CEL2-GAN2","AD_VE_CEL2_GAN2")
mapPair("AD_78_VE-ENT2-GAN2","AD_79_VE-ENT2-GAN2","AD_VE_ENT2_GAN2")
mapPair("AD_80_VE-ENT2-SOC2","AD_81_VE-ENT2-SOC2","AD_VE_ENT2_SOC2")

-- =========================================================
-- SECTION 9) TYPE DEFINITIONS (only targeted edits)
-- =========================================================

local TYPES = {
  -- Youth
  DATE       = { kind="instant", money=-30,  ap={to="EVENT", amount=2}, sat=2, statusAddTag=STATUS_TAG.DATING },
  PARTY      = { kind="instant", money=-50,  ap={to="EVENT", amount=1}, sat=3, dice="HANGOVER" },
  VOLUNTARY  = { kind="instant", ap={to="EVENT", amount=2}, stats={ s=2 } },
  MENTORSHIP = { kind="instant", ap={to="EVENT", amount=2}, stats={ k=2 } },
  BEAUTY     = { kind="instant", ap={to="EVENT", amount=2}, dice="BEAUTY_D6" },
  BIRTHDAY   = { kind="instant", money=-100, ap={to="EVENT", amount=3}, sat=2, multi="BIRTHDAY_ALL_OTHERS" },

  WORK1_150  = { kind="instant", ap={to="EVENT", amount=1}, money=150 },
  WORK2_200  = { kind="instant", ap={to="EVENT", amount=2}, money=200 },
  WORK3_250  = { kind="instant", ap={to="EVENT", amount=3}, money=250 },
  WORK3_300  = { kind="instant", ap={to="EVENT", amount=3}, money=300 },
  WORK5_500  = { kind="instant", ap={to="EVENT", amount=5}, money=500 },

  VOUCH_HI   = { kind="keep", voucher={ category="HITECH",      discount=0.25 } },
  VOUCH_CONS = { kind="keep", voucher={ category="CONSUMABLES", discount=0.50 } },

  SICK_O     = { kind="obligatory", stats={ h=-2 } },
  LOAN_O     = { kind="obligatory", choice="LOAN_PAY_OR_SAT" },

  KARMA      = { kind="instant", ap={to="EVENT", amount=1}, karma=true, statusAddTag=STATUS_TAG.GOODKARMA },

  -- Adult
  AD_SICK_O     = { kind="obligatory", stats={ h=-3 }, statusAddTag=STATUS_TAG.SICK },

  AD_VOUCH_CONS = { kind="keep", voucher={ category="CONSUMABLES", discount=0.25 } },
  AD_VOUCH_HI   = { kind="keep", voucher={ category="HITECH", discount=0.25 } },

  AD_LUXTAX_O   = { kind="obligatory", special="AD_LUXTAX" },
  AD_PROPTAX_O  = { kind="obligatory", special="AD_PROPTAX" },

  AD_DATE       = { kind="instant", ap={to="EVENT", amount=2}, special="AD_DATE_MARRIED_DOUBLE" },

  AD_CHILD100_O = { kind="obligatory", dice="AD_CHILD_D6", childCost=100 },
  AD_CHILD150_O = { kind="obligatory", dice="AD_CHILD_D6", childCost=150 },
  AD_CHILD200_O = { kind="obligatory", dice="AD_CHILD_D6", childCost=200 },

  AD_HI_FAIL_O  = { kind="obligatory", special="AD_HI_FAIL" },

  AD_WORKBONUS  = { kind="instant", ap={to="EVENT", amount=1}, special="AD_WORKBONUS_PAY4" },

  AD_MARRIAGE   = { kind="instant", money=-500, ap={to="EVENT", amount=4}, sat=2, special="AD_MARRIAGE_MULTI" },

  AD_VOUCH_PROP = { kind="keep", voucher={ category="PROPERTY", discount=0.20 } },

  -- ✅ FIX: Adult Karma like Youth Karma (instant + GOODKARMA token, NOT keep)
  AD_KARMA      = { kind="instant", ap={to="EVENT", amount=1}, karma=true, statusAddTag=STATUS_TAG.GOODKARMA },

  AD_AUCTION_O  = { kind="obligatory", special="AD_AUCTION_SCHEDULE" },

  AD_SPORT      = { kind="instant", ap={to="EVENT", amount=1}, money=-100, dice="AD_SPORT_D6" },

  AD_BABYSITTER50 = { kind="instant", special="AD_BABYSITTER", babysitterCost=50 },
  AD_BABYSITTER70 = { kind="instant", special="AD_BABYSITTER", babysitterCost=70 },

  AD_AUNTY_O    = { kind="obligatory", dice="AD_AUNTY_D6" },

  AD_VE_NGO2_SOC1 = { kind="instant", todo=true, ve={a="NGO2", b="SOC1"} },
  AD_VE_NGO1_GAN1 = { kind="instant", todo=true, ve={a="NGO1", b="GAN1"} },
  AD_VE_NGO1_ENT1 = { kind="instant", todo=true, ve={a="NGO1", b="ENT1"} },
  AD_VE_NGO2_CEL1 = { kind="instant", todo=true, ve={a="NGO2", b="CEL1"} },
  AD_VE_SOC2_CEL1 = { kind="instant", todo=true, ve={a="SOC2", b="CEL1"} },
  AD_VE_SOC1_PUB1 = { kind="instant", todo=true, ve={a="SOC1", b="PUB1"} },
  AD_VE_GAN1_PUB2 = { kind="instant", todo=true, ve={a="GAN1", b="PUB2"} },
  AD_VE_ENT1_PUB1 = { kind="instant", todo=true, ve={a="ENT1", b="PUB1"} },
  AD_VE_CEL2_PUB2 = { kind="instant", todo=true, ve={a="CEL2", b="PUB2"} },
  AD_VE_CEL2_GAN2 = { kind="instant", todo=true, ve={a="CEL2", b="GAN2"} },
  AD_VE_ENT2_GAN2 = { kind="instant", todo=true, ve={a="ENT2", b="GAN2"} },
  AD_VE_ENT2_SOC2 = { kind="instant", todo=true, ve={a="ENT2", b="SOC2"} },
}

-- =========================================================
-- SECTION 10) DICE TABLES (only targeted edits)
-- =========================================================

local DICE = {
  HANGOVER = {
    [1] = { ap={to="INACTIVE", amount=2, duration=1} },
    [2] = { ap={to="INACTIVE", amount=1, duration=1} },
    [3] = { ap={to="INACTIVE", amount=1, duration=1} },
    [4] = {}, [5] = {}, [6] = {},
  },
  BEAUTY_D6 = {
    [1] = { money=500 },
    [2] = { money=300 },
    [3] = { money=300 },
    [4] = {}, [5] = {}, [6] = {},
  },
  AD_SPORT_D6 = {
    [1] = { sat=2 }, [2] = { sat=2 },
    [3] = { sat=3 }, [4] = { sat=3 },
    [5] = { sat=4 }, [6] = { sat=4 },
  },

  -- ✅ FIX: Aunty unlock is now "unlock child AP block THIS ROUND" (not weird hook)
  AD_AUNTY_D6 = {
    [1] = { money=-200 },
    [2] = { money=-200 },
    [3] = { money=-200, special="AD_AUNTY_UNLOCK_CHILD_AP_1" },
    [4] = { money=-200, special="AD_AUNTY_UNLOCK_CHILD_AP_2" },
    [5] = { money=600 },
    [6] = { money=600 },
  },
}

-- =========================================================
-- SECTION 10b) DICE RESULT UI MESSAGES (on-screen + chat)
-- =========================================================
-- Returns title (short, for big label on card) and full (for chat + description), or nil if no message.

local DICE_RESULT_UI = {
  BEAUTY_D6 = {
    [1] = {
      title = "Roll: 1 — You won! Main prize: 500 Vins",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 1\nCongratulations! You won the beauty contest! Main prize: 500 Vins.\n========================================",
    },
    [2] = {
      title = "Roll: 2 — Second place! 300 Vins",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 2\nCongratulations! You took second place in the beauty contest. You win 300 Vins.\n========================================",
    },
    [3] = {
      title = "Roll: 3 — Second place! 300 Vins",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 3\nCongratulations! You took second place in the beauty contest. You win 300 Vins.\n========================================",
    },
    [4] = {
      title = "Roll: 4 — No prize this time",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 4\nYour beauty didn't charm the jury. This time you didn't win anything.\n========================================",
    },
    [5] = {
      title = "Roll: 5 — No prize this time",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 5\nYour beauty didn't charm the jury. This time you didn't win anything.\n========================================",
    },
    [6] = {
      title = "Roll: 6 — No prize this time",
      full  = "========== BEAUTY CONTEST ==========\nYou rolled: 6\nYour beauty didn't charm the jury. This time you didn't win anything.\n========================================",
    },
  },
  HANGOVER = {
    [1] = {
      title = "Roll: 1 — Terrible hangover! −2 AP",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 1\nOh my God, you had a terrible hangover. You need to spend a lot of time in bed — or even in the toilet. (−2 AP to inactive)\n========================================",
    },
    [2] = {
      title = "Roll: 2 — Difficult morning, −1 AP",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 2\nYou had a difficult morning, but later you got on track. (−1 AP to inactive)\n========================================",
    },
    [3] = {
      title = "Roll: 3 — Difficult morning, −1 AP",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 3\nYou had a difficult morning, but later you got on track. (−1 AP to inactive)\n========================================",
    },
    [4] = {
      title = "Roll: 4 — Feel great! No penalty",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 4\nYou feel better than ever. Can't wait for the next party!\n========================================",
    },
    [5] = {
      title = "Roll: 5 — Feel great! No penalty",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 5\nYou feel better than ever. Can't wait for the next party!\n========================================",
    },
    [6] = {
      title = "Roll: 6 — Feel great! No penalty",
      full  = "========== PARTY WITH FRIENDS ==========\nYou rolled: 6\nYou feel better than ever. Can't wait for the next party!\n========================================",
    },
  },
  AD_SPORT_D6 = {
    [1] = {
      title = "Roll: 1 — Your team lost",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 1\nYour team lost. Better luck next time! (+2 SAT for taking part)\n========================================",
    },
    [2] = {
      title = "Roll: 2 — Your team lost",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 2\nYour team lost. Better luck next time! (+2 SAT for taking part)\n========================================",
    },
    [3] = {
      title = "Roll: 3 — Your team drew",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 3\nYour team drew. A fair result. (+3 SAT)\n========================================",
    },
    [4] = {
      title = "Roll: 4 — Your team drew",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 4\nYour team drew. A fair result. (+3 SAT)\n========================================",
    },
    [5] = {
      title = "Roll: 5 — Your team won!",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 5\nYour team won! Celebration time! (+4 SAT)\n========================================",
    },
    [6] = {
      title = "Roll: 6 — Your team won!",
      full  = "========== SPORTS EVENT ==========\nYou rolled: 6\nYour team won! Celebration time! (+4 SAT)\n========================================",
    },
  },
}

local function getDiceResultMessage(diceKey, roll)
  if not diceKey or not roll then return nil end
  local t = DICE_RESULT_UI[diceKey]
  if not t then return nil end
  return t[roll]
end

-- =========================================================
-- SECTION 11) CHOICES
-- =========================================================

local CHOICES = {
  LOAN_PAY_OR_SAT = {
    options = {
      PAY = { money=-200 },
      SAT = { sat=-2 },
    }
  }
}

local function applyChoice(color, choiceKey, optionKey)
  local ch = CHOICES[choiceKey]
  if not ch then warn("No choice: "..tostring(choiceKey)); return false end
  local eff = ch.options and ch.options[optionKey]
  if not eff then warn("No choice option: "..tostring(optionKey)); return false end
  return applyEffect_WithAPMove_NoCost(color, eff, "choice:"..tostring(choiceKey))
end

-- =========================================================
-- SECTION 12) MULTI EFFECTS (unchanged)
-- =========================================================

local function allPlayerColors()
  return {"Yellow","Blue","Red","Green"}
end

-- Invited players: obliged to go (always lose 1 AP). If they can pay 100 Vins they get +1 SAT and pay; otherwise no payment, no SAT.
local function resolveBirthday(activeColorNow)
  local moneyActive = resolveMoney(activeColorNow)
  for _, c in ipairs(allPlayerColors()) do
    if c ~= activeColorNow then
      -- Always "go" to the birthday: lose 1 AP to INACTIVE
      applyAP_Move(c, {to="INACTIVE", amount=1, duration=1})

      if canAfford(c, -100) then
        local satObj = getSatToken(c)
        if satObj then satAdd(satObj, 1, "Birthday:"..c) end
        local moneyOther = resolveMoney(c)
        if moneyOther and moneyActive then
          pcall(function()
            moneyAdd(moneyOther, -100)
            moneyAdd(moneyActive, 100)
          end)
        end
      end
      -- If cannot afford 100: no SAT, no payment (still went, so AP already applied)
    end
  end
  safeBroadcastTo(activeColorNow, "🎉 Birthday: inni +1 SAT, 1 AP INACTIVE (1 tura) i płatność 100 (jeśli mogli).", {0.7,1,0.7})
end

-- Invited players: obliged to attend (always lose 2 AP). If they can pay 200 Vins they get +2 SAT and pay; otherwise no payment, no SAT.
local function resolveMarriageMulti(activeColorNow)
  local moneyActive = resolveMoney(activeColorNow)
  for _, c in ipairs(allPlayerColors()) do
    if c ~= activeColorNow then
      -- Always attend the wedding: lose 2 AP to INACTIVE
      applyAP_Move(c, {to="INACTIVE", amount=2, duration=1})

      if canAfford(c, -200) then
        local satObj = getSatToken(c)
        if satObj then satAdd(satObj, 2, "Marriage:"..c) end
        local moneyOther = resolveMoney(c)
        if moneyOther and moneyActive then
          pcall(function()
            moneyAdd(moneyOther, -200)
            moneyAdd(moneyActive, 200)
          end)
        end
      end
      -- If cannot afford 200: no SAT, no payment (still attended, so 2 AP already applied)
    end
  end
end

-- =========================================================
-- SECTION 13) SPECIAL LOGIC (targeted edits)
-- =========================================================

local function handleSpecial(color, cardId, def, cardObj)
  if def.special == "AD_DATE_MARRIED_DOUBLE" then
    local sat = (married[color] == true) and 4 or 2
    local satObj = getSatToken(color)
    if satObj then satAdd(satObj, sat, "AD_DATE") end
    
    -- Add DATING status token (required for marriage)
    PS_AddStatus(color, STATUS_TAG.DATING)
    
    safeBroadcastTo(color, "💑 You went for your first date. Let's see if it can become something serious in the future! +"..tostring(sat).." SAT"..(married[color] and " (married bonus)" or "").." + DATING status.", {0.7,1,0.7})
    return STATUS.DONE
  end

  if def.special == "AD_WORKBONUS_PAY4" then
    -- Work bonus = 4× salary (salary = WIN per AP from current vocation)
    local salary = getSalaryPerAP(color)
    if salary and salary > 0 then
      local bonus = salary * 4
      applyToPlayer_NoAP(color, { money = bonus }, "AD_WORKBONUS")
      safeBroadcastTo(color, "💼 Work bonus: +"..tostring(bonus).." WIN (4× your salary: "..tostring(salary).." WIN/AP).", {0.7,0.95,1})
    else
      safeBroadcastTo(color, "💼 Work bonus: No vocation or salary — no bonus this time.", {0.8,0.8,0.8})
    end
    return STATUS.DONE
  end

  if def.special == "AD_MARRIAGE_MULTI" then
    -- DATING check already done in playCardById before AP/money spending
    -- This check here is redundant but kept for safety
    if not hasDatingStatus(color) then
      warn("AD_MARRIAGE_MULTI: DATING check should have blocked this earlier")
      return STATUS.BLOCKED
    end
    
    -- Remove DATING token (it effectively becomes the marriage token)
    PS_RemoveStatus(color, STATUS_TAG.DATING)
    married[color] = true
    PS_AddMarriage(color)
    resolveMarriageMulti(color)
    safeBroadcastTo(color, "💍 You just got married. Congratulations, and wish you a great future! (+2 SAT for you; others: +2 SAT, 2 AP INACTIVE, 200 WIN if they could pay.)", {0.7,1,0.7})
    return STATUS.DONE
  end

  if def.special == "AD_AUCTION_SCHEDULE" then
    -- Auction/property event: no design yet (what should this card do: schedule? bid? property?)
    safeBroadcastTo(color, "ℹ️ Auction: not implemented yet — no effect. (Design pending.)", {0.7,0.9,1})
    return STATUS.DONE
  end

  -- Luxury Tax: Pay 200 per owned hi-tech item
  if def.special == "AD_LUXTAX" then
    local itemCount = getOwnedHiTechCount(color)
    local totalTax = itemCount * 200
    
    if itemCount == 0 then
      safeBroadcastTo(color, "💼 Luxury Tax: You own no hi-tech items → 0 WIN tax.", {0.8,0.8,0.8})
      return STATUS.DONE
    end
    
    if not canAfford(color, -totalTax) then
      safeBroadcastTo(color, "⛔ Luxury Tax: You need "..tostring(totalTax).." WIN ("..tostring(itemCount).." items × 200), but don't have enough money.", {1,0.6,0.2})
      return STATUS.BLOCKED
    end
    
    applyToPlayer_NoAP(color, { money = -totalTax }, "AD_LUXTAX")
    safeBroadcastTo(color, "💼 Luxury Tax: Paid "..tostring(totalTax).." WIN ("..tostring(itemCount).." hi-tech items × 200).", {0.7,0.9,1})
    return STATUS.DONE
  end

  -- Property Tax: Pay 300 per apartment level (L0=0, L1=1, L2=2, L3=3, L4=4)
  if def.special == "AD_PROPTAX" then
    local estateLevel = getCurrentEstateLevel(color)
    local totalTax = estateLevel * 300
    
    if estateLevel == 0 then
      safeBroadcastTo(color, "🏠 Property Tax: You're in grandma's house (L0) → 0 WIN tax.", {0.8,0.8,0.8})
      return STATUS.DONE
    end
    
    -- Check if player can afford the tax
    if not canAfford(color, -totalTax) then
      -- Player cannot afford: add unpaid amount to Costs Calculator
      -- This gives player a chance to resolve it by end of round
      local TAG_COSTS_CALC = "WLB_COSTS_CALC"
      local costsCalc = nil
      for _, o in ipairs(getAllObjects()) do
        if o and o.hasTag and o.hasTag(TAG_COSTS_CALC) then
          costsCalc = o
          break
        end
      end
      
      if costsCalc and costsCalc.call then
        safeCall(function()
          costsCalc.call("addCost", {color=color, amount=totalTax})
        end)
        safeBroadcastTo(color, "🏠 Property Tax: "..tostring(totalTax).." WIN (Level L"..tostring(estateLevel).." × 300) added to Costs Calculator. Pay by end of round or lose satisfaction.", {1,0.7,0.3})
        log("Property Tax: Added "..tostring(totalTax).." WIN to Costs Calculator for "..color.." (cannot afford)")
        return STATUS.DONE  -- Card is resolved (cost added to calculator)
      else
        -- Costs Calculator not found: fall back to blocking
        safeBroadcastTo(color, "⛔ Property Tax: You need "..tostring(totalTax).." WIN (Level L"..tostring(estateLevel).." × 300), but don't have enough money.", {1,0.6,0.2})
        return STATUS.BLOCKED
      end
    end
    
    -- Player can afford: deduct immediately
    applyToPlayer_NoAP(color, { money = -totalTax }, "AD_PROPTAX")
    safeBroadcastTo(color, "🏠 Property Tax: Paid "..tostring(totalTax).." WIN (Apartment Level L"..tostring(estateLevel).." × 300).", {0.7,0.9,1})
    return STATUS.DONE
  end

  -- Hi-Tech Failure: Randomly break one owned hi-tech item (repair cost 25% of original value)
  if def.special == "AD_HI_FAIL" then
    local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
    if not shopEngine or not shopEngine.call then
      safeBroadcastTo(color, "⛔ Hi-Tech Failure: Shop Engine not found.", {1,0.6,0.2})
      return STATUS.ERROR
    end
    
    local ok, ownedList = pcall(function()
      return shopEngine.call("API_getOwnedHiTech", {color=color})
    end)
    
    if not ok or type(ownedList) ~= "table" or #ownedList == 0 then
      safeBroadcastTo(color, "💻 Hi-Tech Failure: You own no hi-tech items → nothing to break.", {0.8,0.8,0.8})
      return STATUS.DONE
    end
    
    -- Randomly select one item to break (exclude already broken items)
    local availableItems = {}
    brokenHiTech[color] = brokenHiTech[color] or {}
    for _, cardName in ipairs(ownedList) do
      if not brokenHiTech[color][cardName] then
        table.insert(availableItems, cardName)
      end
    end
    
    if #availableItems == 0 then
      safeBroadcastTo(color, "💻 Hi-Tech Failure: All your hi-tech items are already broken.", {0.9,0.9,0.6})
      return STATUS.DONE
    end
    
    -- Random selection
    local randomIdx = math.random(1, #availableItems)
    local brokenCardName = availableItems[randomIdx]
    
    -- Mark as broken
    brokenHiTech[color][brokenCardName] = true
    
    -- Get repair cost (25% of original cost from ShopEngine HI_TECH_DEF)
    local repairCost = 0
    local ok2, cost = pcall(function()
      -- Try to get cost from ShopEngine's HI_TECH_DEF
      local ok3, hiTechDef = pcall(function()
        return shopEngine.call("API_getHiTechDef", {cardName=brokenCardName})
      end)
      if ok3 and hiTechDef and hiTechDef.cost then
        return math.floor(hiTechDef.cost * 0.25)  -- 25% of original cost
      end
      -- Fallback: common costs if API not available
      local commonCosts = { 1200, 1100, 1400, 700, 1000 }
      local avgCost = 1000  -- Default average cost
      return math.floor(avgCost * 0.25)  -- 300 default repair cost
    end)
    repairCost = (ok2 and type(cost) == "number") and cost or 300  -- Default to 300 if API fails
    
    -- Store repair info in pending choice for repair button
    local cardGuid = cardObj.getGUID()
    pendingChoice[cardGuid] = {
      color = color,
      kind = def.kind or "obligatory",
      choiceKey = "HI_FAIL_REPAIR",
      cardId = cardId,
      meta = { brokenCardName = brokenCardName, repairCost = repairCost }
    }
    lockCard(cardGuid, LOCK_SEC)
    
    -- Show repair button on card
    cardUI_clear(cardObj)
    cardUI_title(cardObj, "REPAIR")
    cardUI_btn(cardObj, "REPAIR ("..tostring(repairCost).." WIN)", "evt_choiceRepair", -0.5)
    cardUI_btn(cardObj, "SKIP", "evt_choiceSkip", 0.5)
    
    safeBroadcastTo(color, "💻 Hi-Tech Failure: "..tostring(brokenCardName).." is broken! Repair cost: "..tostring(repairCost).." WIN (25% of original).", {1,0.5,0.2})
    return STATUS.WAIT_CHOICE
  end

  -- ✅ Babysitter: unlocks child AP block partially (this round)
  if def.special == "AD_BABYSITTER" then
    if not hasActiveChild(color) then
      safeBroadcastTo(color, "👶 Babysitter: no child → nothing to unlock.", {0.8,0.8,0.8})
      return STATUS.DONE
    end

    local costPer = tonumber(def.babysitterCost) or 50
    startChoiceOnCard_AB(
      cardObj, color, def.kind or "instant", "BABYSITTER_PICK", cardId,
      "UNLOCK 1 ("..tostring(costPer)..")",
      "UNLOCK 2 ("..tostring(costPer*2)..")",
      { costPer=costPer }
    )
    return STATUS.WAIT_CHOICE
  end

  if def.todo == true and def.ve then
    startChoiceOnCard_AB(
      cardObj, color, def.kind or "instant", "VE_PICK_SIDE", cardId,
      tostring(def.ve.a), tostring(def.ve.b), { ve=def.ve }
    )
    pcall(function() cardObj.setDescription("VE: "..tostring(def.ve.a).." OR "..tostring(def.ve.b).." (TODO)") end)
    return STATUS.WAIT_CHOICE
  end

  return nil
end

-- =========================================================
-- SECTION 14) DICE RESOLUTION (targeted edits for child + aunty)
-- =========================================================

local function resolveDiceByValue(color, diceKey, roll, cardId, def)
  if diceKey == "AD_CHILD_D6" then
    if roll <= 2 then
      safeBroadcastTo(color, "👶 Child: 1-2 -> no child.", {0.8,0.8,0.8})
      return true
    end

    local gender = (roll <= 4) and "BOY" or "GIRL"
    local cost = tonumber(def and def.childCost) or 100

    -- if you already have a child, we keep the existing one and just notify
    if hasActiveChild(color) then
      safeBroadcastTo(color, "👶 You already have a child — this event does not add another (keeping existing one).", {0.9,0.9,0.6})
      return true
    end

    child[color] = { active=true, cost=cost, sat=2, apBlock=2, gender=gender }
    childUnlock[color] = 0

    PS_AddChild(color, gender)
    
    -- Block 2 AP immediately when child is born (permanent, no duration)
    applyAP_Move(color, {to="INACTIVE", amount=2})

    -- Add baby cost to cost calculator (per turn)
    addBabyCostToCalculator(color, cost)

    safeBroadcastTo(color, "👶 Child ("..gender.."): from now on every round +2 SAT, -" .. tostring(cost) .. " WIN, block 2 AP (with unlock possibility).", {0.7,1,0.7})
    return true
  end

  local tbl = DICE[diceKey]
  if not tbl then warn("No dice table: "..tostring(diceKey)); return false end

  local eff = tbl[roll] or {}
  local special = eff.special

  local effCopy = {}
  for k,v in pairs(eff) do
    if k ~= "special" then effCopy[k] = v end
  end

  -- HANGOVER (Party with friends): apply AP to INACTIVE with REST fallback so penalty is always applied
  if diceKey == "HANGOVER" and effCopy.ap and effCopy.ap.to == "INACTIVE" and (tonumber(effCopy.ap.amount) or 0) > 0 then
    local okAp = applyAP_ToInactive_WithRestFallback(color, effCopy.ap.amount, effCopy.ap.duration)
    if not okAp then return false end
    effCopy.ap = nil
  end

  local ok = applyEffect_WithAPMove_NoCost(color, effCopy, "dice:"..tostring(diceKey))
  if not ok then return false end

  -- ✅ Aunty special: unlock child AP block partially (this round)
  if special == "AD_AUNTY_UNLOCK_CHILD_AP_1" then
    addChildUnlock(color, 1)
  elseif special == "AD_AUNTY_UNLOCK_CHILD_AP_2" then
    addChildUnlock(color, 2)
  end

  return true
end

function evt_roll(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pd = pendingDice[g]
  if not pd then
    safeBroadcastTo(player_color, "No pending dice on this card.", {1,0.4,0.4})
    return
  end

  lockCard(g, LOCK_SEC)
  cardUI_clear(cardObj)
  cardUI_title(cardObj, "ROLLING...")

  rollRealDieAsync(cardObj, function(roll, err)
    cardUI_clear(cardObj)

    if not roll then
      local fallback = math.random(1,6)
      warn("Real die roll failed ("..tostring(err)..") -> fallback="..tostring(fallback))
      roll = fallback
      safeBroadcastTo(pd.color, "Die read failed; used fallback roll: "..tostring(roll), {1,0.8,0.3})
    end

    -- Always show the roll result to the player (otherwise it feels like "no resolution").
    safeBroadcastTo(pd.color, "🎲 Roll result: "..tostring(roll), {0.85,0.95,1})

    local typeKey = CARD_TYPE[pd.cardId]
    local def = typeKey and TYPES[typeKey] or nil

    -- Resolve dice and handle any errors (log the error text for debugging)
    local okDice, resOrErr = pcall(function()
      return resolveDiceByValue(pd.color, pd.diceKey, roll, pd.cardId, def)
    end)

    if not okDice then
      warn("resolveDiceByValue failed for "..tostring(pd.cardId)..
        " (diceKey="..tostring(pd.diceKey).." roll="..tostring(roll)..") err="..tostring(resOrErr))
      safeBroadcastTo(pd.color, "⚠️ Card resolution error occurred. Card will still be moved to used deck.", {1,0.7,0.3})
    elseif resOrErr == false then
      -- Normal failure path (no Lua error), e.g. missing money controller
      warn("resolveDiceByValue returned false for "..tostring(pd.cardId)..
        " (diceKey="..tostring(pd.diceKey).." roll="..tostring(roll)..")")
    end

    local die = getRealDie()
    local msg = getDiceResultMessage(pd.diceKey, roll)

    if msg then
      -- Big on-screen result: label on card + full message in chat + on card description
      cardUI_title(cardObj, msg.title)
      safeBroadcastTo(pd.color, msg.full, {0.95,0.95,0.9})
      pcall(function() cardObj.setDescription(msg.full) end)
      pendingDice[g] = nil
      -- Keep result visible for a few seconds, then finalize
      Wait.time(function()
        cardUI_clear(cardObj)
        local finalizeOk = pcall(function() finalizeCard(cardObj, pd.kind, pd.color) end)
        if not finalizeOk then
          warn("finalizeCard failed for "..tostring(pd.cardId))
          local target = findDiscardTarget()
          if target and target.getPosition then
            local p = target.getPosition()
            pcall(function() cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true) end)
          else
            warn("Discard target not found - card may remain in slot")
          end
        end
        if die then returnDieHome(die) end
      end, 4.0)
    else
      pcall(function() cardObj.setDescription("DICE: "..tostring(pd.diceKey).." -> "..tostring(roll)) end)
      pendingDice[g] = nil
      local finalizeOk = pcall(function() finalizeCard(cardObj, pd.kind, pd.color) end)
      if not finalizeOk then
        warn("finalizeCard failed for "..tostring(pd.cardId))
        local target = findDiscardTarget()
        if target and target.getPosition then
          local p = target.getPosition()
          pcall(function() cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true) end)
        else
          warn("Discard target not found - card may remain in slot")
        end
      end
      if die then Wait.time(function() returnDieHome(die) end, 0.35) end
    end
  end)
end

-- =========================================================
-- SECTION 15) CHOICE HANDLERS (targeted babysitter fix)
-- =========================================================

local function finishChoice(cardObj, pc)
  pendingChoice[cardObj.getGUID()] = nil
  cardUI_clear(cardObj)
  finalizeCard(cardObj, pc.kind, pc.color)
end

function evt_choiceA(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc then return end
  lockCard(g, LOCK_SEC)

  if pc.choiceKey == "VE_PICK_SIDE" then
    safeBroadcastTo(pc.color, "VE: wybrano A (TODO).", {0.7,0.9,1})
    finishChoice(cardObj, pc)
    return
  end

  if pc.choiceKey == "BABYSITTER_PICK" then
    local costPer = tonumber(pc.meta and pc.meta.costPer) or 50
    if not canAfford(pc.color, -costPer) then
      safeBroadcastTo(pc.color, "⛔ You don't have enough money.", {1,0.6,0.2})
      return
    end
    applyToPlayer_NoAP(pc.color, { money = -costPer }, "BabysitterPay1")
    addChildUnlock(pc.color, 1)
    
    -- Immediately move 1 AP from INACTIVE back to START
    -- Use negative amount to return FROM INACTIVE TO START
    local apCtrl = getApCtrl(pc.color)
    if apCtrl and apCtrl.call then
      Wait.time(function()
        if apCtrl and apCtrl.call then
          pcall(function()
            -- Negative amount returns FROM area TO START
            apCtrl.call("moveAP", {to="INACTIVE", amount=-1})
            log("Babysitter (1 AP): "..pc.color.." moved 1 AP from INACTIVE to START")
          end)
        end
      end, 0.15)
    else
      warn("Babysitter: AP Controller not found for "..tostring(pc.color))
    end
    
    finishChoice(cardObj, pc)
    return
  end

  safeBroadcastTo(pc.color, "ℹ️ Choice A not configured for "..tostring(pc.choiceKey), {1,0.8,0.3})
end

function evt_choiceB(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc then return end
  lockCard(g, LOCK_SEC)

  if pc.choiceKey == "VE_PICK_SIDE" then
    safeBroadcastTo(pc.color, "VE: wybrano B (TODO).", {0.7,0.9,1})
    finishChoice(cardObj, pc)
    return
  end

  if pc.choiceKey == "BABYSITTER_PICK" then
    local costPer = tonumber(pc.meta and pc.meta.costPer) or 50
    local cost = costPer * 2
    if not canAfford(pc.color, -cost) then
      safeBroadcastTo(pc.color, "⛔ You don't have enough money.", {1,0.6,0.2})
      return
    end
    applyToPlayer_NoAP(pc.color, { money = -cost }, "BabysitterPay2")
    addChildUnlock(pc.color, 2)
    
    -- Immediately move 2 AP from INACTIVE back to START
    -- Use negative amount to return FROM INACTIVE TO START
    local apCtrl = getApCtrl(pc.color)
    if apCtrl and apCtrl.call then
      -- Move 2 AP (stagger slightly to avoid conflicts)
      Wait.time(function()
        if apCtrl and apCtrl.call then
          pcall(function()
            -- Negative amount returns FROM area TO START
            apCtrl.call("moveAP", {to="INACTIVE", amount=-1})
            log("Babysitter (2 AP): "..pc.color.." moved 1 AP from INACTIVE to START")
          end)
        end
      end, 0.15)
      Wait.time(function()
        if apCtrl and apCtrl.call then
          pcall(function()
            -- Negative amount returns FROM area TO START
            apCtrl.call("moveAP", {to="INACTIVE", amount=-1})
            log("Babysitter (2 AP): "..pc.color.." moved second 1 AP from INACTIVE to START")
          end)
        end
      end, 0.30)
    else
      warn("Babysitter: AP Controller not found for "..tostring(pc.color))
    end
    
    finishChoice(cardObj, pc)
    return
  end

  safeBroadcastTo(pc.color, "ℹ️ Choice B not configured for "..tostring(pc.choiceKey), {1,0.8,0.3})
end

function evt_choicePay(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc then return end
  lockCard(g, LOCK_SEC)

  if applyChoice(pc.color, pc.choiceKey, "PAY") then
    finishChoice(cardObj, pc)
  else
    safeBroadcastTo(pc.color, "Choice blocked/failed.", {1,0.6,0.2})
  end
end

function evt_choiceSat(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc then return end
  lockCard(g, LOCK_SEC)

  if applyChoice(pc.color, pc.choiceKey, "SAT") then
    finishChoice(cardObj, pc)
  else
    safeBroadcastTo(pc.color, "Choice blocked/failed.", {1,0.6,0.2})
  end
end

-- Repair broken hi-tech item
function evt_choiceRepair(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "HI_FAIL_REPAIR" then return end
  lockCard(g, LOCK_SEC)

  local brokenCardName = pc.meta and pc.meta.brokenCardName
  local repairCost = tonumber(pc.meta and pc.meta.repairCost) or 300
  
  if not brokenCardName then
    safeBroadcastTo(pc.color, "⛔ Repair: Missing broken item info.", {1,0.6,0.2})
    return
  end
  
  if not canAfford(pc.color, -repairCost) then
    safeBroadcastTo(pc.color, "⛔ Repair: You need "..tostring(repairCost).." WIN, but don't have enough money.", {1,0.6,0.2})
    return
  end
  
  -- Pay repair cost
  applyToPlayer_NoAP(pc.color, { money = -repairCost }, "HI_FAIL_REPAIR")
  
  -- Mark item as repaired
  brokenHiTech[pc.color] = brokenHiTech[pc.color] or {}
  brokenHiTech[pc.color][brokenCardName] = nil
  
  safeBroadcastTo(pc.color, "🔧 Repaired: "..tostring(brokenCardName).." is now working! (Paid "..tostring(repairCost).." WIN)", {0.7,1,0.7})
  finishChoice(cardObj, pc)
end

-- Skip repair (leave item broken)
function evt_choiceSkip(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "HI_FAIL_REPAIR" then return end
  lockCard(g, LOCK_SEC)

  local brokenCardName = pc.meta and pc.meta.brokenCardName
  safeBroadcastTo(pc.color, "💻 "..tostring(brokenCardName or "Item").." remains broken. You can repair it later.", {0.8,0.8,0.8})
  finishChoice(cardObj, pc)
end

-- =========================================================
-- SECTION 16) MAIN PLAY (mostly unchanged; keeps statusAddTag pipeline)
-- =========================================================

local function playCardById(cardId, cardObj, explicitSlotIdx)
  local color = getPlayerColor()
  if not color then
    warn("No active player color.")
    return STATUS.ERROR
  end

  local typeKey = CARD_TYPE[cardId]
  if not typeKey then
    warn("Unknown card ID: "..tostring(cardId))
    safeBroadcastTo(color, "⚠️ Unknown card ID: "..tostring(cardId), {1,0.6,0.2})
    return STATUS.ERROR
  end

  local def = TYPES[typeKey]
  if not def then
    warn("No TYPES def for "..tostring(typeKey))
    safeBroadcastTo(color, "⚠️ No TYPES def for: "..tostring(typeKey), {1,0.6,0.2})
    return STATUS.ERROR
  end

  -- VOUCHER-ONLY: grant token(s), move card to USED deck (no AP, no money, no other effects)
  if def.voucher then
    local msg = "🎫 Voucher: "
    if typeKey == "VOUCH_CONS" then
      -- Youth 50% Consumables → 2x 25% tokens; delay 2nd so they stack without collision
      PS_AddStatus(color, STATUS_TAG.VOUCH_C)
      msg = msg .. "2× Consumables discount (25% each)"
      safeBroadcastTo(color, msg, {0.85,0.95,0.9})
      finalizeCard(cardObj, "instant", color)
      Wait.time(function()
        PS_AddStatus(color, STATUS_TAG.VOUCH_C)
      end, 1.0)
      return STATUS.DONE
    elseif typeKey == "VOUCH_HI" then
      PS_AddStatus(color, STATUS_TAG.VOUCH_H)
      msg = msg .. "1× Hi-Tech discount (25%)"
    elseif typeKey == "AD_VOUCH_CONS" then
      PS_AddStatus(color, STATUS_TAG.VOUCH_C)
      msg = msg .. "1× Consumables discount (25%)"
    elseif typeKey == "AD_VOUCH_HI" then
      PS_AddStatus(color, STATUS_TAG.VOUCH_H)
      msg = msg .. "1× Hi-Tech discount (25%)"
    elseif typeKey == "AD_VOUCH_PROP" then
      PS_AddStatus(color, STATUS_TAG.VOUCH_P)
      msg = msg .. "1× Properties discount (20%)"
    else
      msg = msg .. "unknown voucher type"
    end
    safeBroadcastTo(color, msg, {0.85,0.95,0.9})
    finalizeCard(cardObj, "instant", color)
    return STATUS.DONE
  end

  -- marriage requirement guard (check DATING status BEFORE spending AP/money)
  if def.special == "AD_MARRIAGE_MULTI" then
    if not hasDatingStatus(color) then
      safeBroadcastTo(color, "⛔ Marriage blocked: You must have a DATING status token to get married. Use a 'Go out on a date' card first.", {1,0.6,0.2})
      return STATUS.BLOCKED
    end
  end

  -- money guard
  if def.money and def.money < 0 and (not canAfford(color, def.money)) then
    safeBroadcastTo(color, "⛔ You don't have enough money for this card.", {1,0.6,0.2})
    return STATUS.BLOCKED
  end

  -- IMPORTANT: Coordinate total AP reduction (base + slot extra) for CAR
  local base = (def.ap and def.ap.amount) and (tonumber(def.ap.amount) or 0) or 0
  local cardGuid = cardObj.getGUID()
  local slotExtra = tonumber(slotExtraAPForCard[cardGuid]) or 0
  
  -- Calculate total AP and apply CAR reduction once to total
  local total = base + slotExtra
  local originalTotal = total
  if total > 0 and hasCarReduction(color) then
    total = math.max(0, total - 1)
    log("CAR reduction: Total AP reduced by 1 (was: "..tostring(originalTotal)..", now: "..tostring(total)..") base="..tostring(base).." slotExtra="..tostring(slotExtra).." for "..tostring(color))
  end
  
  -- Split reduced total back to base and extra (base gets priority - reduce base first, then extra)
  local newBase = math.min(base, total)  -- Base can't exceed its original value
  local newSlotExtra = math.max(0, total - newBase)  -- Remaining goes to extra
  
  -- Store adjusted slot extra AP for Event Controller to read later
  slotExtraAPForCard[cardGuid] = newSlotExtra
  
  -- Use adjusted base AP for charging
  base = newBase
  
  if base > 0 then
    local apTo = (def.ap and def.ap.to) or "EVENT"
    local apCost = { to = apTo, amount = base, duration = def.ap and def.ap.duration or nil }
    if not tryPayAPOrBlock(color, apCost) then
      safeBroadcastTo(color, "⛔ You don't have enough AP for this card.", {1,0.6,0.2})
      return STATUS.BLOCKED
    end
  end

  -- CHOICE
  if def.choice then
    local g = cardObj.getGUID()
    pendingChoice[g] = { color=color, kind=def.kind, choiceKey=def.choice, cardId=cardId, meta={} }
    lockCard(g, LOCK_SEC)

    cardUI_clear(cardObj)
    cardUI_title(cardObj, "CHOOSE")
    cardUI_btn(cardObj, "PAY", "evt_choicePay", -1.2)
    cardUI_btn(cardObj, "SAT", "evt_choiceSat", 0.0)
    cardUI_btn(cardObj, "CANCEL", "evt_cancelPending", 1.2)
    safeBroadcastTo(color, "Choice required. Pick PAY or SAT on the card.", {1,1,1})
    return STATUS.WAIT_CHOICE
  end

  -- apply immediate effects excluding ap/dice/special/meta/multi/statusAddTag
  local rest = {}
  for k,v in pairs(def) do
    if k ~= "ap" and k ~= "dice" and k ~= "special"
       and k ~= "childCost" and k ~= "babysitterCost"
       and k ~= "ve" and k ~= "todo" and k ~= "note"
       and k ~= "multi" and k ~= "statusAddTag" then
      rest[k] = v
    end
  end

  if not applyToPlayer_NoAP(color, rest, "play:"..tostring(cardId)) then
    warn("Effect failed.")
    return STATUS.ERROR
  end

  -- STATUS ADD (via PlayerStatusController -> TokenEngine)
  if def.statusAddTag then
    PS_AddStatus(color, def.statusAddTag)
  end

  -- SPECIAL
  if def.special then
    local s = handleSpecial(color, cardId, def, cardObj)
    if s == STATUS.WAIT_CHOICE then return STATUS.WAIT_CHOICE end
  end

  -- DICE
  if def.dice then
    startDiceOnCard(cardObj, color, def.kind, def.dice, cardId)
    return STATUS.WAIT_DICE
  end

  -- MULTI
  if def.multi == "BIRTHDAY_ALL_OTHERS" then
    resolveBirthday(color)
  end

  -- TODO placeholder
  if def.todo == true and not def.ve then
    safeBroadcastTo(color, "ℹ️ "..tostring(cardId).." -> TODO (mechanika jeszcze nie wdrożona).", {0.7,0.9,1})
    log("TODO played: "..tostring(cardId).." type="..tostring(typeKey).." note="..tostring(def.note or ""))
  end

  finalizeCard(cardObj, def.kind, color)
  return STATUS.DONE
end

local function handleIncomingCard(cardObj, reason, explicitSlotIdx)
  if not cardObj or cardObj.tag ~= "Card" then return STATUS.IGNORED end
  local guid = cardObj.getGUID()

  if isLocked(guid) then
    if DEBUG then log("LOCKED: "..guid.." ("..tostring(reason)..")") end
    return STATUS.IGNORED
  end

  local nowT = Time.time
  if recentlyPlayed[guid] and (nowT - recentlyPlayed[guid]) < DEBOUNCE_SEC then
    if DEBUG then log("DEBOUNCE: "..guid.." ("..tostring(reason)..")") end
    return STATUS.IGNORED
  end
  recentlyPlayed[guid] = nowT

  local cardId = extractCardId(cardObj)
  if not cardId then
    warn("No cardId ("..tostring(reason)..") name="..tostring(cardObj.getName and cardObj.getName() or ""))
    clearDebounce(guid)
    return STATUS.ERROR
  end

  local res = playCardById(cardId, cardObj, explicitSlotIdx)

  if res == STATUS.BLOCKED then
    clearDebounce(guid)
  end

  return res
end

-- =========================================================
-- SECTION 17) PUBLIC API
-- =========================================================

function playCardFromUI(args)
  args = args or {}
  if not args.card_guid or args.card_guid == "" then
    warn("playCardFromUI: missing card_guid")
    return STATUS.ERROR
  end

  local cardObj = getObjectFromGUID(args.card_guid)
  if not cardObj or cardObj.tag ~= "Card" then
    warn("playCardFromUI: card not found / not Card guid="..tostring(args.card_guid))
    return STATUS.ERROR
  end

  if args.player_color and args.player_color ~= "" then
    activeColor = args.player_color
  end

  -- Store slot extra AP for CAR coordination (will be used by playCardById)
  local cardGuid = args.card_guid
  local slotExtra = tonumber(args.slot_extra_ap) or 0
  slotExtraAPForCard[cardGuid] = slotExtra

  return handleIncomingCard(cardObj, "ui", tonumber(args.slot_idx))
end

-- API for Event Controller to get adjusted slot extra AP after CAR reduction
function getAdjustedSlotExtraAP(args)
  args = args or {}
  local cardGuid = args.card_guid
  if not cardGuid then return 0 end
  return tonumber(slotExtraAPForCard[cardGuid]) or 0
end

function isObligatoryCard(args)
  args = args or {}
  local guid = args.card_guid or args.cardGuid
  if not guid or guid == "" then return false end

  local cardObj = getObjectFromGUID(guid)
  if not cardObj or cardObj.tag ~= "Card" then return false end

  local cardId = extractCardId(cardObj)
  if not cardId then return false end

  local typeKey = CARD_TYPE[cardId]
  local def = typeKey and TYPES[typeKey] or nil
  if def and tostring(def.kind) == "obligatory" then return true end
  if cardId:match("_O$") then return true end
  return false
end

-- ✅ Updated end-of-round for child:
--  - Applies SAT
--  - Pays money if possible
--  - Blocks AP = apBlock - childUnlock[color] (min 0)
--  - Resets childUnlock[color] to 0 for next round
function applyEndOfRoundForColor(args)
  args = args or {}
  local color = args.player_color or args.color
  if not color or color == "" then return false end

  local st = child[color]
  if not (st and st.active) then
    childUnlock[color] = 0
    return true
  end

  applyToPlayer_NoAP(color, { sat = tonumber(st.sat) or 2 }, "ChildRoundSAT")

  local cost = tonumber(st.cost) or 0
  if cost > 0 then
    if canAfford(color, -cost) then
      applyToPlayer_NoAP(color, { money = -cost }, "ChildRoundMoney")
    else
      warn("ChildRoundMoney blocked (not enough money).")
    end
  end

  local block = tonumber(st.apBlock) or 2
  local unlock = tonumber(childUnlock[color]) or 0
  local finalBlock = math.max(0, block - unlock)

  if finalBlock > 0 then
    -- Child-blocked AP is PERMANENT (no duration) - stays blocked until end of game or unblocked by special cards
    -- Event-based blocking uses duration=1 (temporary, released after turn)
    applyAP_Move(color, {to="INACTIVE", amount=finalBlock})  -- No duration = permanent
  end

  if DEBUG then
    log("Child EOR: "..tostring(color).." block="..tostring(block).." unlock="..tostring(unlock).." final="..tostring(finalBlock))
  end

  childUnlock[color] = 0
  return true
end

-- Optional: drop-to-play (collision) still supported
function onCollisionEnter(info)
  local obj = info and info.collision_object
  if obj then handleIncomingCard(obj, "collision", nil) end
end

-- =========================================================
-- SECTION 18) LOAD
-- =========================================================

function onSave()
  -- Save broken hi-tech state
  return JSON.encode({ brokenHiTech = brokenHiTech })
end

function onLoad(saved_data)
  print("[WLB EVENT] onLoad OK - engine alive (v1.7.2)")

  -- Load broken hi-tech state
  if saved_data and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" and data.brokenHiTech then
      brokenHiTech = data.brokenHiTech
    end
  end
  
  -- Ensure all colors exist in brokenHiTech
  brokenHiTech = brokenHiTech or {}
  for _, c in ipairs({"Yellow","Blue","Red","Green"}) do
    brokenHiTech[c] = brokenHiTech[c] or {}
  end

  local die = getRealDie()
  if die and die.getPosition and die.getRotation then
    local p = die.getPosition()
    local r = die.getRotation()
    diceHome = { pos={x=p.x,y=p.y,z=p.z}, rot={x=r.x,y=r.y,z=r.z} }
  end

  if DEBUG then
    for _, c in ipairs({"Yellow","Blue","Red","Green"}) do
      local o = getObjectFromGUID(SAT_TOKEN_GUIDS[c])
      if o then
        log("SAT GUID OK: "..c.." -> "..SAT_TOKEN_GUIDS[c].." name="..tostring(o.getName and o.getName() or ""))
      else
        warn("SAT GUID MISSING IN SAVE: "..c.." -> "..tostring(SAT_TOKEN_GUIDS[c]))
      end
    end
  end
end

function setActiveYellow() activeColor="Yellow"; log("ActiveColor=Yellow (fallback)") end
function setActiveBlue()   activeColor="Blue";   log("ActiveColor=Blue (fallback)") end
function setActiveRed()    activeColor="Red";    log("ActiveColor=Red (fallback)") end
function setActiveGreen()  activeColor="Green";  log("ActiveColor=Green (fallback)") end
