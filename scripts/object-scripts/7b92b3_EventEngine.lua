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

-- Events Controller (notify on cancel so card becomes interactable again)
local EVENTS_CONTROLLER_GUID = "1339d3"

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
local pendingVECrime = {}     -- [cardGuid] = { color, cardId, targetColor? } for VE crime flow
local auctionHandoffCardGuids = {}  -- [cardGuid]=true when card was handed to Events Controller for Call for Auction (skip finalizeCard)

-- Store slot extra AP for CAR coordination (set by playCardFromUI, used by playCardById)
local slotExtraAPForCard = {}  -- [cardGuid] = extra AP amount
local veSlotExtraCharged = {}  -- [cardGuid] = slotExtra AP amount that was charged by Events Controller (for refund on cancel)

-- adult state
local married = { Yellow=false, Blue=false, Red=false, Green=false }

-- child state:
-- child[color] = { active=true, cost=100/150/200, sat=2, apBlock=2, gender="BOY/GIRL" }
local child = { Yellow=nil, Blue=nil, Red=nil, Green=nil }

-- NEW: per-round unlock of child AP block (0..child.apBlock)
local childUnlock = { Yellow=0, Blue=0, Red=0, Green=0 }

-- Broken hi-tech items: [color] = {cardName1=true, ...}; repair cost when broken: [color][cardName] = cost
local brokenHiTech = { Yellow={}, Blue={}, Red={}, Green={} }
local brokenRepairCost = { Yellow={}, Blue={}, Red={}, Green={} }

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
  local all = (type(getAllObjects) == "function" and getAllObjects()) or {}
  for _, o in ipairs(all) do
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
      return costsCalc.call("addCost", {color=color, amount=cost, label="Baby"})
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

-- Celebrity event card obligation: Record event card play for Celebrity players
-- Called once per card play, right after card validation (before any early returns)
-- This ensures ALL event board cards are tracked, including vouchers, instant, choice, dice cards
local function recordCelebrityEventCardPlay(color, cardId, typeKey)
  if not color or color == "White" then
    return
  end
  
  local vocCtrl = findOneByTags({TAG_VOCATIONS_CTRL})
  if not vocCtrl or not vocCtrl.call then
    return
  end
  
  local ok, err = pcall(function()
    -- VOC_GetVocation returns the vocation directly, not (ok, vocation)
    local vocation = vocCtrl.call("VOC_GetVocation", { color = color })
    
    if not vocation then
      return
    end
    
    if vocation == "CELEBRITY" then
      vocCtrl.call("VOC_RecordCelebrityEventCardPlay", { color = color })
    end
  end)
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

-- Find Shop Engine and check if player owns CAR (for -1 AP cost reduction; shop-bought or PS perk)
local function hasCarReduction(color)
  if not color then
    log("CAR check: no color provided")
    return false
  end

  local normalizedColor = (color .. ""):sub(1,1):upper() .. (color .. ""):sub(2):lower()

  local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
  if not shopEngine or not shopEngine.call then
    shopEngine = nil
    for _, o in ipairs(getAllObjects()) do
      if o and o.hasTag and o.hasTag(TAG_SHOP_ENGINE) and o.call then shopEngine = o break end
    end
  end
  if not shopEngine or not shopEngine.call then
    warn("CAR check: Shop Engine not found (tag "..TAG_SHOP_ENGINE..")")
    return false
  end

  local ok, hasCar = pcall(function()
    return shopEngine.call("API_ownsHiTech", { color = normalizedColor, kind = "CAR" })
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

-- Anti-burglary Alarm: victim is protected from theft (money/hi-tech) but can still be WOUNDED
local function targetHasAlarm(targetColor)
  if not targetColor or targetColor == "" then return false end
  local normalizedColor = (targetColor .. ""):sub(1,1):upper() .. (targetColor .. ""):sub(2):lower()
  local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
  if not shopEngine or not shopEngine.call then return false end
  local ok, hasAlarm = pcall(function()
    return shopEngine.call("API_ownsHiTech", { color = normalizedColor, kind = "ALARM" })
  end)
  return (ok and hasAlarm == true)
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
  local g = cardObj.getGUID()
  -- Don't finalize if this card was handed off to Events Controller for auction (it's already at auction position)
  if auctionHandoffCardGuids and auctionHandoffCardGuids[g] then
    if DEBUG then log("finalizeCard: skipped - card "..tostring(g).." is auction handoff") end
    auctionHandoffCardGuids[g] = nil
    return
  end
  -- Don't finalize if there's a pending crime flow
  if pendingVECrime and pendingVECrime[g] then
    if DEBUG then log("finalizeCard: blocked - pendingVECrime exists for "..tostring(g)) end
    return
  end
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
    font_size = 100,
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
    width = 650, height = 200,
    font_size = 120,
    tooltip = ""
  })
end

local function cardUI_btnBottom(cardObj, label, fn, posZ)
  if not cardObj then return end
  cardObj.createButton({
    click_function = fn,
    function_owner = self,
    label = label,
    position = {0, 0.15, posZ or 0},
    rotation = {0, 0, 0},
    width = 650, height = 200,
    font_size = 120,
    tooltip = ""
  })
end

-- Button at explicit (posX, posY, posZ) for four-corner layouts
local function cardUI_btnAt(cardObj, label, fn, posX, posY, posZ)
  if not cardObj then return end
  cardObj.createButton({
    click_function = fn,
    function_owner = self,
    label = label,
    position = {posX or 0, posY or 0.65, posZ or 0},
    rotation = {0, 0, 0},
    width = 650, height = 200,
    font_size = 120,
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
  
  -- Refund slotExtra AP if it was charged for VE card
  -- Events Controller charges the adjusted slotExtra AP (after CAR reduction), so we need to refund the same amount
  if veSlotExtraCharged[g] then
    -- Use the stored slotExtra value (the amount that Events Controller actually charged)
    -- veSlotExtraCharged[g] stores the actual amount charged (set when VE UI was shown)
    local slotExtra = tonumber(veSlotExtraCharged[g]) or 0
    if slotExtra > 0 then
      local pc = pendingChoice[g]
      local color = pc and pc.color or player_color
      local apCtrl = getApCtrl(color)
      if apCtrl and apCtrl.call then
        -- Use a shared tracker for async callbacks
        local refundTracker = { total = 0 }
        -- Refund AP one at a time using sequential Wait.time callbacks
        -- Use longer delay (0.4s) to ensure each token fully settles before next one moves
        for i = 1, slotExtra do
          Wait.time(function()
            if apCtrl and apCtrl.call then
              local okRefund, result = pcall(function() 
                return apCtrl.call("moveAP", { to = "E", amount = -1 })
              end)
              if okRefund and result and type(result) == "table" and result.ok == true then
                local moved = tonumber(result.moved or 0) or 0
                if moved > 0 then
                  refundTracker.total = refundTracker.total + moved
                  if DEBUG then log("VE card cancelled: refunded slotExtra AP chunk "..tostring(i)..": moved="..tostring(moved)) end
                else
                  if DEBUG then log("VE card cancelled: WARNING slotExtra refund chunk "..tostring(i).." succeeded but moved=0") end
                end
              else
                if DEBUG then log("VE card cancelled: FAILED slotExtra refund chunk "..tostring(i).." okRefund="..tostring(okRefund).." result="..tostring(result)) end
              end
              -- After last refund, clear state and send message
              if i == slotExtra then
                if DEBUG then log("VE card cancelled: Total slotExtra refunded="..tostring(refundTracker.total).." (requested "..tostring(slotExtra)..") for card "..tostring(g)) end
                -- Add small delay to let tokens settle before clearing state
                Wait.time(function()
                  -- Clear state after all refunds complete and tokens settle
                  veSlotExtraCharged[g] = nil -- Clear after all refunds complete
                  pendingDice[g] = nil
                  pendingChoice[g] = nil
                  pendingVECrime[g] = nil
                  cardUI_clear(cardObj)
                  if lockUntil then lockUntil[g] = nil end
                  clearDebounce(g)
                  -- Notify Events Controller
                  pcall(function()
                    local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
                    if ctrl and ctrl.call then
                      ctrl.call("onCardCancelled", { card_guid = g })
                    end
                  end)
                  -- Send refund message
                  if refundTracker.total > 0 then
                    safeBroadcastTo(color, "Cancelled. Refunded "..tostring(refundTracker.total).." AP.", {0.7,1,0.7})
                  end
                end, 0.2) -- Small delay to let tokens settle
              end
            end
          end, 0.4 * i) -- Increased delay to 0.4s per token to ensure full settlement
      end
      -- Don't clear veSlotExtraCharged until refunds complete - cleared in final callback
      -- Return early - state clearing and message will happen in the last callback
      return
    end
    end
  end
  
  -- No refund needed, clear state immediately
  pendingDice[g] = nil
  pendingChoice[g] = nil
  pendingVECrime[g] = nil
  cardUI_clear(cardObj)
  -- Unlock the card immediately so YES can be clicked again
  if lockUntil then lockUntil[g] = nil end
  clearDebounce(g)
  -- Notify Events Controller so it closes modal and re-adds YES/click catcher (card becomes interactable again)
  pcall(function()
    local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
    if ctrl and ctrl.call then
      ctrl.call("onCardCancelled", { card_guid = g })
    end
  end)
end

-- Vocation Event: Crime flow (charge AP, choose target, roll 1d6, apply table)
function evt_veCrime(cardObj, player_color, alt_click)
  if not cardObj then return end
  if type(pendingChoice) ~= "table" then return end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "VE_PICK_SIDE" then return end
  -- Spectator (White): allow action and use card's player (pc.color) as actor; otherwise only that player may click
  local clickerNorm = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if clickerNorm ~= "" and clickerNorm ~= "White" and clickerNorm ~= (pc.color and (pc.color:sub(1,1):upper()..pc.color:sub(2):lower()) or "") then
    return
  end
  lockCard(g, LOCK_SEC)
  local cardId = pc.cardId
  -- Convert cardId to typeKey for VE_CRIME_TABLE lookup (chunk-safe: CARD_TYPE may be in later chunk)
  local cardTypeTbl = (type(CARD_TYPE) == "table" and CARD_TYPE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.CARD_TYPE)
  local typeKey = nil
  if cardTypeTbl and type(cardTypeTbl) == "table" then
    typeKey = cardTypeTbl[cardId]
  end
  if not typeKey then
    if DEBUG then log("evt_veCrime: typeKey not found for cardId="..tostring(cardId).." CARD_TYPE="..tostring(cardTypeTbl)) end
    -- Try to extract typeKey from cardId pattern (e.g., AD_59_VE-NGO2-SOC1 -> AD_VE_NGO2_SOC1)
    if cardId and type(cardId) == "string" then
      -- Pattern: AD_XX_VE-XXX-YYY -> AD_VE_XXX_YYY
      local pattern = cardId:match("^(AD_%d+_VE%-)(.+)")
      if pattern then
        local rest = cardId:match("^AD_%d+_VE%-(.+)$")
        if rest then
          -- Replace hyphens with underscores
          typeKey = "AD_VE_" .. rest:gsub("-", "_")
          if DEBUG then log("evt_veCrime: extracted typeKey="..tostring(typeKey).." from cardId="..tostring(cardId)) end
        end
      end
    end
    if not typeKey then
      safeBroadcastTo(pc.color, "Crime: Card type not found. Cannot commit crime.", {1,0.6,0.2})
      return
    end
  end
  -- Chunk-safe: VE_CRIME_TABLE may be in later chunk
  local crimeTable = (type(VE_CRIME_TABLE) == "table" and VE_CRIME_TABLE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.VE_CRIME_TABLE)
  if not crimeTable or type(crimeTable) ~= "table" then
    if DEBUG then log("evt_veCrime: VE_CRIME_TABLE is nil, using fallback table") end
    -- Fallback crime table if VE_CRIME_TABLE is not accessible
    crimeTable = {
      AD_VE_NGO1_ENT1 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_NGO1_GAN1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 250, steal3 = 600 },
      AD_VE_NGO2_SOC1 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_NGO2_CEL1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 800 },
      AD_VE_ENT1_PUB1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_ENT2_GAN2 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_ENT2_SOC2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_GAN1_PUB2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_CEL2_GAN2 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_SOC1_PUB1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_SOC2_CEL1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_CEL2_PUB2 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
    }
  end
  local crimeDef = crimeTable[typeKey]
  if not crimeDef then
    if DEBUG then log("evt_veCrime: crimeDef not found for typeKey="..tostring(typeKey)) end
    safeBroadcastTo(pc.color, "Crime: This card has no crime option.", {1,0.6,0.2})
    return
  end
  local apCost = { to = "EVENT", amount = crimeDef.ap }
  if not tryPayAPOrBlock(pc.color, apCost) then
    safeBroadcastTo(pc.color, "Not enough AP for Crime (need "..tostring(crimeDef.ap)..").", {1,0.6,0.2})
    return
  end
  -- Set pendingVECrime BEFORE clearing pendingChoice to prevent premature finalization
  -- Store crime AP amount for refund on cancel
  pendingVECrime[g] = { color = pc.color, cardId = cardId, typeKey = typeKey, cardObj = cardObj, crimeAP = crimeDef.ap }
  pendingChoice[g] = nil
  cardUI_clear(cardObj)
  -- Use VocationsController target selection UI instead of card buttons
  local voc = findOneByTags({TAG_VOCATIONS_CTRL})
  if voc and voc.call then
    pcall(function()
      voc.call("StartVECrimeTargetSelection", {
        initiator = pc.color,
        cardGuid = g
      })
    end)
  else
    -- Fallback to card buttons if VocationsController not available
    cardUI_title(cardObj, "Choose target")
    cardUI_btn(cardObj, "Yellow", "evt_veTargetYellow", -1.0)
    cardUI_btn(cardObj, "Blue", "evt_veTargetBlue", -0.3)
    cardUI_btn(cardObj, "Red", "evt_veTargetRed", 0.4)
    cardUI_btn(cardObj, "Green", "evt_veTargetGreen", 1.1)
    cardUI_btn(cardObj, "Cancel", "evt_cancelPending", 1.8)
    safeBroadcastTo(pc.color, "Choose a player to commit crime on.", {1,0.9,0.5})
  end
end

-- Helper function to process crime roll results
local function processCrimeRollResult(roll, data, cardObj, g, targetColor)
  if not roll or roll < 1 or roll > 6 then
    if DEBUG then log("processCrimeRollResult: invalid roll="..tostring(roll)) end
    return
  end
  -- Use typeKey if available, otherwise try to convert cardId (chunk-safe fallback)
  local cardTypeTbl = (type(CARD_TYPE) == "table" and CARD_TYPE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.CARD_TYPE)
  local crimeKey = data.typeKey or (cardTypeTbl and cardTypeTbl[data.cardId]) or data.cardId
  local crimeTable = (type(VE_CRIME_TABLE) == "table" and VE_CRIME_TABLE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.VE_CRIME_TABLE)
  if not crimeTable or type(crimeTable) ~= "table" then
    -- Fallback crime table if VE_CRIME_TABLE is not accessible
    crimeTable = {
      AD_VE_NGO1_ENT1 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_NGO1_GAN1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 250, steal3 = 600 },
      AD_VE_NGO2_SOC1 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_NGO2_CEL1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 800 },
      AD_VE_ENT1_PUB1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_ENT2_GAN2 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_ENT2_SOC2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_GAN1_PUB2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_CEL2_GAN2 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
      AD_VE_SOC1_PUB1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_SOC2_CEL1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      AD_VE_CEL2_PUB2 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
    }
  end
  local crimeDef = crimeTable[crimeKey]
  if not crimeDef then
    if DEBUG then log("processCrimeRollResult: crimeDef not found for crimeKey="..tostring(crimeKey)) end
    pendingVECrime[g] = nil
    if type(finalizeCard) == "function" then
      finalizeCard(cardObj, "instant", data.color)
    else
      pcall(function() cardObj.clearButtons() end)
      if type(findDiscardTarget) == "function" then
        local target = findDiscardTarget()
        if target then
          local p = target.getPosition()
          cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true)
        end
      end
    end
    return
  end
  local band = (roll <= 2) and 1 or ((roll <= 4) and 2 or 3)
  local outcome = crimeDef[band]
  local crimeGainsVIN = 0  -- for Heat & Investigation (Tier 3 restitution)
  if outcome == "nothing" then
    pcall(function() broadcastToAll("Crime: Nothing happens.", {0.8,0.8,0.8}) end)
  elseif outcome == "wounded" then
    -- Add wounded token
    if STATUS_TAG and STATUS_TAG.WOUNDED then
      local ok, err = pcall(function() 
        PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      end)
      if not ok and DEBUG then
        log("processCrimeRollResult: Failed to add WOUNDED status: "..tostring(err))
      end
    end
    -- Reduce health by 3
    local statsCtrl = findOneByTags({TAG_STATS_CTRL, colorTag(targetColor)})
    if statsCtrl then
      local ok = statsApply(statsCtrl, { h = -3 })
      if not ok and DEBUG then
        log("processCrimeRollResult: Failed to reduce health for "..tostring(targetColor))
      end
    end
    pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED and loses 3 Health.", {1,0.6,0.4}) end)
  elseif outcome == "wounded_steal" then
    -- Add wounded token
    if STATUS_TAG and STATUS_TAG.WOUNDED then
      local ok, err = pcall(function() 
        PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      end)
      if not ok and DEBUG then
        log("processCrimeRollResult: Failed to add WOUNDED status: "..tostring(err))
      end
    end
    -- Reduce health by 3
    local statsCtrl = findOneByTags({TAG_STATS_CTRL, colorTag(targetColor)})
    if statsCtrl then
      local ok = statsApply(statsCtrl, { h = -3 })
      if not ok and DEBUG then
        log("processCrimeRollResult: Failed to reduce health for "..tostring(targetColor))
      end
    end

    -- Anti-burglary Alarm: victim keeps all items and cash; still WOUNDED
    if targetHasAlarm(targetColor) then
      crimeGainsVIN = 0
      pcall(function() broadcastToAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..data.color.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5}) end)
    else
      -- Steal money: take from target, give to initiator
      local steal = (band == 2 and crimeDef.steal2) or (band == 3 and crimeDef.steal3) or crimeDef.steal or 0
      if steal > 0 then
        -- Get target's current money
        local targetMoneyObj = resolveMoney(targetColor)
        local targetCurrentMoney = 0
        if targetMoneyObj then
          targetCurrentMoney = moneyGet(targetMoneyObj) or 0
        end

        -- Calculate amount to steal (can't steal more than they have)
        local amountToSteal = math.min(steal, targetCurrentMoney)

        if amountToSteal > 0 then
          crimeGainsVIN = amountToSteal
          -- Take money from target
          local targetMoneyObj2 = resolveMoney(targetColor)
          if targetMoneyObj2 then
            pcall(function() moneyAdd(targetMoneyObj2, -amountToSteal) end)
          end

          -- Give money to initiator
          local initiatorMoneyObj = resolveMoney(data.color)
          if initiatorMoneyObj then
            pcall(function() moneyAdd(initiatorMoneyObj, amountToSteal) end)
          end

          if amountToSteal < steal then
            pcall(function() broadcastToAll("Crime: "..targetColor.." WOUNDED, loses 3 Health and "..tostring(amountToSteal).." WIN (only had "..tostring(targetCurrentMoney).."). "..data.color.." gains "..tostring(amountToSteal).." WIN.", {1,0.6,0.4}) end)
          else
            pcall(function() broadcastToAll("Crime: "..targetColor.." WOUNDED, loses 3 Health and "..tostring(amountToSteal).." WIN. "..data.color.." gains "..tostring(amountToSteal).." WIN.", {1,0.6,0.4}) end)
          end
        else
          pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED and loses 3 Health but has no money to steal.", {1,0.6,0.4}) end)
        end
      else
        pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED and loses 3 Health.", {1,0.6,0.4}) end)
      end
    end
  end
  -- Heat & Investigation (only after successful crime: wounded or wounded_steal)
  if outcome ~= "nothing" then
    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    if voc and voc.call then
      pcall(function()
        voc.call("RunCrimeInvestigation", {
          initiatorColor = data.color,
          crimeGainsVIN = crimeGainsVIN,
          targetColor = targetColor,
        })
      end)
    end
  end
  pendingVECrime[g] = nil
  -- Clear veSlotExtraCharged flag since crime action completed successfully
  veSlotExtraCharged[g] = nil
  if type(finalizeCard) == "function" then
    finalizeCard(cardObj, "instant", data.color)
  else
    pcall(function() cardObj.clearButtons() end)
    if type(findDiscardTarget) == "function" then
      local target = findDiscardTarget()
      if target then
        local p = target.getPosition()
        cardObj.setPositionSmooth({p.x, p.y + 2, p.z}, false, true)
      end
    end
  end
end

-- Called by VocationsController when target is selected via UI
function VECrimeTargetSelected(params)
  if DEBUG then log("VECrimeTargetSelected: called with params="..tostring(params and (params.cardGuid or "nil").." targetColor="..tostring(params and params.targetColor or "nil"))) end
  if not params or not params.cardGuid or not params.targetColor then 
    if DEBUG then log("VECrimeTargetSelected: missing params") end
    return 
  end
  local g = params.cardGuid
  local data = pendingVECrime[g]
  if not data then 
    if DEBUG then log("VECrimeTargetSelected: no pendingVECrime data for guid="..tostring(g)) end
    return 
  end
  local targetColor = params.targetColor
  if data.color == targetColor then
    safeBroadcastTo(data.color, "You cannot target yourself.", {1,0.6,0.2})
    return
  end
  local cardObj = data.cardObj or getObjectFromGUID(g)
  if not cardObj then 
    if DEBUG then log("VECrimeTargetSelected: cardObj not found for guid="..tostring(g)) end
    return 
  end
  lockCard(g, LOCK_SEC)
  data.targetColor = targetColor
  cardUI_clear(cardObj)
  safeBroadcastTo(data.color, "Crime target: "..targetColor..". Rolling dice...", {1,0.9,0.5})
  if DEBUG then log("VECrimeTargetSelected: starting dice roll for target="..tostring(targetColor)) end
  local rollFn = _G.EVT_rollDieForPlayer or rollDieForPlayer
  if type(rollFn) ~= "function" then
    print("[WLB EVENT][FATAL] rollDieForPlayer is nil (chunk): "..tostring(type(_G.EVT_rollDieForPlayer)))
    return
  end
  rollFn(data.color, "evt_crime", function(roll, err)
    if not roll or roll < 1 or roll > 6 then
      safeBroadcastTo(data.color, "ERROR: Failed to read die value.", {1,0,0})
      pendingVECrime[g] = nil
      cardUI_clear(cardObj)
      return
    end
    if DEBUG then log("VECrimeTargetSelected: final value="..tostring(roll)) end
    processCrimeRollResult(roll, data, cardObj, g, targetColor)
  end)
end

local function evt_veTarget(cardObj, targetColor)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local data = pendingVECrime[g]
  if not data then return end
  if data.color == targetColor then
    safeBroadcastTo(data.color, "You cannot target yourself.", {1,0.6,0.2})
    return
  end
  lockCard(g, LOCK_SEC)
  data.targetColor = targetColor
  cardUI_clear(cardObj)
  safeBroadcastTo(data.color, "Crime target: "..targetColor..". Rolling dice...", {1,0.9,0.5})
  -- Automatically roll dice instead of showing ROLL UI
  rollRealDieAsync(cardObj, function(roll, err)
    if err or not roll then
      roll = math.random(1, 6)
    end
    -- Use typeKey if available (chunk-safe fallback)
    local cardTypeTbl = (type(CARD_TYPE) == "table" and CARD_TYPE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.CARD_TYPE)
    local crimeKey = data.typeKey or (cardTypeTbl and cardTypeTbl[data.cardId]) or data.cardId
    local crimeTable = (type(VE_CRIME_TABLE) == "table" and VE_CRIME_TABLE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.VE_CRIME_TABLE)
    if not crimeTable or type(crimeTable) ~= "table" then
      -- Fallback crime table if VE_CRIME_TABLE is not accessible
      crimeTable = {
        AD_VE_NGO1_ENT1 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
        AD_VE_NGO1_GAN1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 250, steal3 = 600 },
        AD_VE_NGO2_SOC1 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
        AD_VE_NGO2_CEL1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 800 },
        AD_VE_ENT1_PUB1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
        AD_VE_ENT2_GAN2 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
        AD_VE_ENT2_SOC2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
        AD_VE_GAN1_PUB2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
        AD_VE_CEL2_GAN2 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
        AD_VE_SOC1_PUB1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
        AD_VE_SOC2_CEL1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
        AD_VE_CEL2_PUB2 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
      }
    end
    local crimeDef = crimeTable[crimeKey]
    if not crimeDef then
      if DEBUG then log("evt_veTarget roll: crimeDef not found for crimeKey="..tostring(crimeKey)) end
      pendingVECrime[g] = nil
      finalizeCard(cardObj, "instant", data.color)
      return
    end
    local band = (roll <= 2) and 1 or ((roll <= 4) and 2 or 3)
    local outcome = crimeDef[band]
    local targetColor = data.targetColor
    local crimeGainsVIN = 0
    if outcome == "nothing" then
      pcall(function() broadcastToAll("Crime: Nothing happens.", {0.8,0.8,0.8}) end)
    elseif outcome == "wounded" then
      PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED.", {1,0.6,0.4}) end)
    elseif outcome == "wounded_steal" then
      PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      if targetHasAlarm(targetColor) then
        crimeGainsVIN = 0
        pcall(function() broadcastToAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..data.color.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5}) end)
      else
        local steal = (band == 2 and crimeDef.steal2) or (band == 3 and crimeDef.steal3) or crimeDef.steal or 0
        if steal > 0 then
          applyToPlayer_NoAP(targetColor, { money = -steal }, "VECrimeSteal")
          crimeGainsVIN = steal
          pcall(function() broadcastToAll("Crime: "..targetColor.." WOUNDED and loses "..tostring(steal).." WIN.", {1,0.6,0.4}) end)
        else
          pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED.", {1,0.6,0.4}) end)
        end
      end
    end
    -- Heat & Investigation (same as processCrimeRollResult: only after successful crime)
    if outcome ~= "nothing" then
      local voc = findOneByTags({TAG_VOCATIONS_CTRL})
      if voc and voc.call then
        pcall(function()
          voc.call("RunCrimeInvestigation", {
            initiatorColor = data.color,
            crimeGainsVIN = crimeGainsVIN,
            targetColor = targetColor,
          })
        end)
      end
    end
    pendingVECrime[g] = nil
    finalizeCard(cardObj, "instant", data.color)
  end)
end
function evt_veTargetYellow(cardObj, p, alt) evt_veTarget(cardObj, "Yellow") end
function evt_veTargetBlue(cardObj, p, alt)  evt_veTarget(cardObj, "Blue") end
function evt_veTargetRed(cardObj, p, alt)   evt_veTarget(cardObj, "Red") end
function evt_veTargetGreen(cardObj, p, alt) evt_veTarget(cardObj, "Green") end

function evt_veCrimeRoll(cardObj, player_color, alt_click)
  if not cardObj then return end
  local g = cardObj.getGUID()
  local data = pendingVECrime[g]
  if not data or not data.targetColor then return end
  lockCard(g, LOCK_SEC)
  rollRealDieAsync(cardObj, function(roll, err)
    if err or not roll then
      roll = math.random(1, 6)
    end
    -- Use typeKey if available (chunk-safe fallback)
    local cardTypeTbl = (type(CARD_TYPE) == "table" and CARD_TYPE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.CARD_TYPE)
    local crimeKey = data.typeKey or (cardTypeTbl and cardTypeTbl[data.cardId]) or data.cardId
    local crimeTbl = (type(VE_CRIME_TABLE) == "table" and VE_CRIME_TABLE) or (type(_G.WLB_EVT) == "table" and _G.WLB_EVT.VE_CRIME_TABLE)
    local crimeDef = crimeTbl and crimeTbl[crimeKey]
    if not crimeDef then
      pendingVECrime[g] = nil
      finalizeCard(cardObj, "instant", data.color)
      return
    end
    local band = (roll <= 2) and 1 or ((roll <= 4) and 2 or 3)
    local outcome = crimeDef[band]
    local targetColor = data.targetColor
    local crimeGainsVIN = 0
    if outcome == "nothing" then
      pcall(function() broadcastToAll("Crime: Nothing happens.", {0.8,0.8,0.8}) end)
    elseif outcome == "wounded" then
      PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED.", {1,0.6,0.4}) end)
    elseif outcome == "wounded_steal" then
      PS_AddStatus(targetColor, STATUS_TAG.WOUNDED)
      if targetHasAlarm(targetColor) then
        crimeGainsVIN = 0
        pcall(function() broadcastToAll("🔔 Alarm raised! "..targetColor.."'s Anti-burglary Alarm prevented the theft. "..data.color.."'s attempt was noticed; "..targetColor.." is WOUNDED but nothing was stolen.", {0.9,0.85,0.5}) end)
      else
        local steal = (band == 2 and crimeDef.steal2) or (band == 3 and crimeDef.steal3) or crimeDef.steal or 0
        if steal > 0 then
          applyToPlayer_NoAP(targetColor, { money = -steal }, "VECrimeSteal")
          crimeGainsVIN = steal
          pcall(function() broadcastToAll("Crime: "..targetColor.." WOUNDED and loses "..tostring(steal).." WIN.", {1,0.6,0.4}) end)
        else
          pcall(function() broadcastToAll("Crime: "..targetColor.." is WOUNDED.", {1,0.6,0.4}) end)
        end
      end
    end
    -- Heat & Investigation (only after successful crime: wounded or wounded_steal)
    if outcome ~= "nothing" then
      local voc = findOneByTags({TAG_VOCATIONS_CTRL})
      if voc and voc.call then
        pcall(function()
          voc.call("RunCrimeInvestigation", {
            initiatorColor = data.color,
            crimeGainsVIN = crimeGainsVIN,
            targetColor = targetColor,
          })
        end)
      end
    end
    pendingVECrime[g] = nil
    finalizeCard(cardObj, "instant", data.color)
  end)
end

-- Vocation Event: only the player who played the card and has that vocation can use the button
local function veChoiceAllowed(cardObj, player_color, veCode)
  if DEBUG then log("veChoiceAllowed: START - player_color="..tostring(player_color).." veCode="..tostring(veCode)) end
  if not cardObj or not player_color or not veCode then 
    if DEBUG then log("veChoiceAllowed: missing params - cardObj="..tostring(cardObj).." player_color="..tostring(player_color).." veCode="..tostring(veCode)) end
    return false 
  end
  if type(pendingChoice) ~= "table" then 
    if DEBUG then log("veChoiceAllowed: pendingChoice is not a table") end
    return false 
  end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "VE_PICK_SIDE" then 
    if DEBUG then log("veChoiceAllowed: no pc or wrong choiceKey - pc="..tostring(pc).." choiceKey="..tostring(pc and pc.choiceKey)) end
    return false 
  end
  -- White player can use vocation cards as current turn color (for testing)
  if player_color == "White" then
    -- Get current turn color and use that for vocation check
    local turnColor = nil
    if Turns and Turns.turn_color and Turns.turn_color ~= "" then
      turnColor = Turns.turn_color
    elseif activeColor and activeColor ~= "" then
      turnColor = activeColor
    end
    if turnColor and turnColor ~= "White" then
      if DEBUG then log("veChoiceAllowed: White player using turn color "..tostring(turnColor).." for vocation check") end
      -- Use turn color for vocation check instead of White
      player_color = turnColor
    else
      if DEBUG then log("veChoiceAllowed: White player bypass - no turn color, allowing") end
      return true
    end
  end
  -- Normalize colors for comparison (handle case differences)
  local function normColor(c)
    if not c or type(c) ~= "string" or c == "" then return c end
    return c:sub(1,1):upper() .. c:sub(2):lower()
  end
  local playerColorNorm = normColor(player_color)
  local pcColorNorm = normColor(pc.color)
  -- Spectator (White): allow and treat as acting for pc.color (current turn player)
  if playerColorNorm ~= "White" and playerColorNorm ~= pcColorNorm then
    if DEBUG then log("veChoiceAllowed: color mismatch - player='"..tostring(player_color).."' ("..tostring(playerColorNorm)..") pc.color='"..tostring(pc.color).."' ("..tostring(pcColorNorm)..")") end
    return false
  end
  -- VE_CODE_TO_VOCATION might be nil due to chunking - use fallback mapping
  local codeToVoc = VE_CODE_TO_VOCATION
  if not codeToVoc or type(codeToVoc) ~= "table" then
    if DEBUG then log("veChoiceAllowed: VE_CODE_TO_VOCATION is nil, using fallback mapping") end
    -- Fallback mapping if VE_CODE_TO_VOCATION is not accessible
    codeToVoc = {
      SOC1 = "SOCIAL_WORKER", SOC2 = "SOCIAL_WORKER",
      CEL1 = "CELEBRITY", CEL2 = "CELEBRITY",
      PUB1 = "PUBLIC_SERVANT", PUB2 = "PUBLIC_SERVANT",
      GAN1 = "GANGSTER", GAN2 = "GANGSTER",
      NGO1 = "NGO_WORKER", NGO2 = "NGO_WORKER",
      ENT1 = "ENTREPRENEUR", ENT2 = "ENTREPRENEUR",
    }
  end
  local requiredVoc = codeToVoc[veCode]
  if not requiredVoc then 
    if DEBUG then log("veChoiceAllowed: requiredVoc not found for veCode="..tostring(veCode)) end
    return false 
  end
  if DEBUG then log("veChoiceAllowed: requiredVoc="..tostring(requiredVoc).." for veCode="..tostring(veCode)) end
  local voc = findOneByTags({TAG_VOCATIONS_CTRL})
  if not voc or not voc.call then 
    if DEBUG then log("veChoiceAllowed: VocationsController not found or no call method") end
    return false 
  end
  if DEBUG then log("veChoiceAllowed: calling VOC_GetVocation with color="..tostring(player_color)) end
  local ok, gotVoc = pcall(function() return voc.call("VOC_GetVocation", { color = player_color }) end)
  if not ok then 
    if DEBUG then log("veChoiceAllowed: VOC_GetVocation call failed for "..tostring(player_color).." error="..tostring(gotVoc)) end
    return false 
  end
  if DEBUG then log("veChoiceAllowed: VOC_GetVocation returned: "..tostring(gotVoc).." (type="..type(gotVoc)..")") end
  -- Handle nil vocation (player has no vocation assigned)
  if not gotVoc or gotVoc == "" then
    if DEBUG then log("veChoiceAllowed: player has no vocation - gotVoc=nil") end
    return false
  end
  -- Normalize both values for comparison (handle case differences, whitespace)
  local gotVocStr = tostring(gotVoc):gsub("%s+", ""):upper()
  local requiredVocStr = tostring(requiredVoc):gsub("%s+", ""):upper()
  if gotVocStr == "" or requiredVocStr == "" then
    if DEBUG then log("veChoiceAllowed: empty vocation after normalize - got='"..tostring(gotVoc).."' required='"..tostring(requiredVoc).."'") end
    return false
  end
  if gotVocStr ~= requiredVocStr then
    if DEBUG then log("veChoiceAllowed: mismatch - got='"..tostring(gotVoc).."' ("..gotVocStr..") required='"..tostring(requiredVoc).."' ("..requiredVocStr..")") end
    return false
  end
  if DEBUG then log("veChoiceAllowed: ✓ match - got='"..tostring(gotVoc).."' required='"..tostring(requiredVoc).."'") end
  return true
end

function evt_veChoiceA(cardObj, player_color, alt_click)
  if not cardObj then return end
  if DEBUG then log("evt_veChoiceA: called by "..tostring(player_color)) end
  if type(pendingChoice) ~= "table" then 
    if DEBUG then log("evt_veChoiceA: pendingChoice is not a table") end
    return 
  end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "VE_PICK_SIDE" then 
    if DEBUG then log("evt_veChoiceA: no pendingChoice or wrong choiceKey - pc="..tostring(pc and pc.choiceKey)) end
    return 
  end
  local meta = pc.meta
  if not meta or not meta.ve then 
    if DEBUG then log("evt_veChoiceA: no meta or ve") end
    return 
  end
  local veCode = meta.ve.a
  if not veCode then 
    if DEBUG then log("evt_veChoiceA: no veCode from meta.ve.a") end
    return 
  end
  if DEBUG then log("evt_veChoiceA: veCode="..tostring(veCode).." checking if allowed...") end
  if not veChoiceAllowed(cardObj, player_color, veCode) then
    -- Always use full vocation name, never show codes like ENT1 or NGO1
    local displayNames = VE_DISPLAY_NAMES
    if not displayNames or type(displayNames) ~= "table" then
      displayNames = {
        SOC1 = "Social Worker", SOC2 = "Social Worker",
        CEL1 = "Celebrity", CEL2 = "Celebrity",
        PUB1 = "Public Servant", PUB2 = "Public Servant",
        GAN1 = "Gangster", GAN2 = "Gangster",
        NGO1 = "NGO Worker", NGO2 = "NGO Worker",
        ENT1 = "Entrepreneur", ENT2 = "Entrepreneur",
      }
    end
    local vocationName = displayNames[veCode]
    if not vocationName or vocationName == "" then
      -- Fallback: try to get name from code-to-vocation mapping
      local codeToVoc = VE_CODE_TO_VOCATION
      if codeToVoc and codeToVoc[veCode] then
        local vocConst = codeToVoc[veCode]
        local vocNameMap = {
          SOCIAL_WORKER = "Social Worker",
          CELEBRITY = "Celebrity",
          PUBLIC_SERVANT = "Public Servant",
          GANGSTER = "Gangster",
          NGO_WORKER = "NGO Worker",
          ENTREPRENEUR = "Entrepreneur",
        }
        vocationName = vocNameMap[vocConst] or vocConst
      else
        vocationName = "the required vocation"
      end
    end
    safeBroadcastTo(player_color, "Only "..tostring(vocationName).." can use this action.", {1,0.6,0.2})
    return
  end
  lockCard(g, LOCK_SEC)
  local actionIds = VE_ACTION_IDS
  if not actionIds or type(actionIds) ~= "table" then
    -- Fallback if VE_ACTION_IDS is not accessible
    actionIds = {
      SOC1 = "SW_SPECIAL_HOMELESS",   SOC2 = "SW_SPECIAL_REMOVAL",
      CEL1 = "CELEB_SPECIAL_COLLAB",  CEL2 = "CELEB_SPECIAL_MEETUP",
      PUB1 = "PS_SPECIAL_POLICY",     PUB2 = "PS_SPECIAL_BOTTLENECK",
      GAN1 = "GANG_SPECIAL_ROBIN",    GAN2 = "GANG_SPECIAL_PROTECTION",
      NGO1 = "NGO_SPECIAL_CRISIS",    NGO2 = "NGO_SPECIAL_SCANDAL",
      ENT1 = "ENT_SPECIAL_EXPANSION", ENT2 = "ENT_SPECIAL_TRAINING",
    }
  end
  local actionId = actionIds[veCode]
  if actionId then
    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    if voc and voc.call then
      if DEBUG then log("evt_veChoiceA: calling RunVocationEventCardAction with actionId="..tostring(actionId)) end
      pcall(function() voc.call("RunVocationEventCardAction", { playerColor = pc.color, actionId = actionId }) end)
    else
      if DEBUG then log("evt_veChoiceA: VocationsController not found") end
    end
  else
    if DEBUG then log("evt_veChoiceA: no actionId for veCode="..tostring(veCode)) end
  end
  -- Clear veSlotExtraCharged flag since action completed successfully
  veSlotExtraCharged[g] = nil
  
  -- finishChoice might be nil due to chunking - inline the logic
  if type(finishChoice) == "function" then
    finishChoice(cardObj, pc)
  else
    pendingChoice[g] = nil
    cardUI_clear(cardObj)
    finalizeCard(cardObj, pc.kind, pc.color)
  end
end

function evt_veChoiceB(cardObj, player_color, alt_click)
  if not cardObj then return end
  if DEBUG then log("evt_veChoiceB: called by "..tostring(player_color)) end
  if type(pendingChoice) ~= "table" then 
    if DEBUG then log("evt_veChoiceB: pendingChoice is not a table") end
    return 
  end
  local g = cardObj.getGUID()
  local pc = pendingChoice[g]
  if not pc or pc.choiceKey ~= "VE_PICK_SIDE" then 
    if DEBUG then log("evt_veChoiceB: no pendingChoice or wrong choiceKey - pc="..tostring(pc and pc.choiceKey)) end
    return 
  end
  local meta = pc.meta
  if not meta or not meta.ve then 
    if DEBUG then log("evt_veChoiceB: no meta or ve") end
    return 
  end
  local veCode = meta.ve.b
  if not veCode then 
    if DEBUG then log("evt_veChoiceB: no veCode from meta.ve.b") end
    return 
  end
  if DEBUG then log("evt_veChoiceB: veCode="..tostring(veCode).." checking if allowed...") end
  if not veChoiceAllowed(cardObj, player_color, veCode) then
    -- Always use full vocation name, never show codes like ENT1 or NGO1
    local displayNames = VE_DISPLAY_NAMES
    if not displayNames or type(displayNames) ~= "table" then
      displayNames = {
        SOC1 = "Social Worker", SOC2 = "Social Worker",
        CEL1 = "Celebrity", CEL2 = "Celebrity",
        PUB1 = "Public Servant", PUB2 = "Public Servant",
        GAN1 = "Gangster", GAN2 = "Gangster",
        NGO1 = "NGO Worker", NGO2 = "NGO Worker",
        ENT1 = "Entrepreneur", ENT2 = "Entrepreneur",
      }
    end
    local vocationName = displayNames[veCode]
    if not vocationName or vocationName == "" then
      -- Fallback: try to get name from code-to-vocation mapping
      local codeToVoc = VE_CODE_TO_VOCATION
      if codeToVoc and codeToVoc[veCode] then
        local vocConst = codeToVoc[veCode]
        local vocNameMap = {
          SOCIAL_WORKER = "Social Worker",
          CELEBRITY = "Celebrity",
          PUBLIC_SERVANT = "Public Servant",
          GANGSTER = "Gangster",
          NGO_WORKER = "NGO Worker",
          ENTREPRENEUR = "Entrepreneur",
        }
        vocationName = vocNameMap[vocConst] or vocConst
      else
        vocationName = "the required vocation"
      end
    end
    safeBroadcastTo(player_color, "Only "..tostring(vocationName).." can use this action.", {1,0.6,0.2})
    return
  end
  lockCard(g, LOCK_SEC)
  local actionIds = VE_ACTION_IDS
  if not actionIds or type(actionIds) ~= "table" then
    -- Fallback if VE_ACTION_IDS is not accessible
    actionIds = {
      SOC1 = "SW_SPECIAL_HOMELESS",   SOC2 = "SW_SPECIAL_REMOVAL",
      CEL1 = "CELEB_SPECIAL_COLLAB",  CEL2 = "CELEB_SPECIAL_MEETUP",
      PUB1 = "PS_SPECIAL_POLICY",     PUB2 = "PS_SPECIAL_BOTTLENECK",
      GAN1 = "GANG_SPECIAL_ROBIN",    GAN2 = "GANG_SPECIAL_PROTECTION",
      NGO1 = "NGO_SPECIAL_CRISIS",    NGO2 = "NGO_SPECIAL_SCANDAL",
      ENT1 = "ENT_SPECIAL_EXPANSION", ENT2 = "ENT_SPECIAL_TRAINING",
    }
  end
  local actionId = actionIds[veCode]
  if actionId then
    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    if voc and voc.call then
      if DEBUG then log("evt_veChoiceB: calling RunVocationEventCardAction with actionId="..tostring(actionId)) end
      pcall(function() voc.call("RunVocationEventCardAction", { playerColor = pc.color, actionId = actionId }) end)
    else
      if DEBUG then log("evt_veChoiceB: VocationsController not found") end
    end
  else
    if DEBUG then log("evt_veChoiceB: no actionId for veCode="..tostring(veCode)) end
  end
  -- Clear veSlotExtraCharged flag since action completed successfully
  veSlotExtraCharged[g] = nil
  
  -- finishChoice might be nil due to chunking - inline the logic
  if type(finishChoice) == "function" then
    finishChoice(cardObj, pc)
  else
    pendingChoice[g] = nil
    cardUI_clear(cardObj)
    finalizeCard(cardObj, pc.kind, pc.color)
  end
end

-- =========================================================
-- SECTION 6) REAL DIE
-- =========================================================

local function getRealDie()
  if not REAL_DICE_GUID or REAL_DICE_GUID == "" then return nil end
  if type(getObjectFromGUID) ~= "function" then return nil end
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
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)

  local timeout = (os and os.time and os.time()) or 0
  timeout = timeout + 6
  if not (Wait and Wait.condition) then onDone(math.random(1,6), nil); return end
  Wait.condition(
    function()
      local v = tryReadDieValue(die)
      if v then onDone(v, nil)
      else onDone(nil, "Failed to read die value after resting") end
    end,
    function()
      local resting = false
      pcall(function() resting = die.resting end)
      return resting or (os.time() >= timeout)
    end
  )
end

-- Callback function for die roll results from VocationsController
function OnDieRollResult(params)
  if not params or not params.result then return end
  local requestId = params.requestId
  local dieValue = params.result
  
  -- Find the pending callback for this requestId
  if not _G.EVT_DieRollCallbacks then return end
  local callbackInfo = _G.EVT_DieRollCallbacks[requestId]
  if not callbackInfo then return end
  
  -- Validate die value
  if type(dieValue) ~= "number" or dieValue < 1 or dieValue > 6 then
    dieValue = math.random(1, 6)
  end
  
  -- Call the original callback
  if callbackInfo.onDone then
    callbackInfo.onDone(dieValue, nil)
  end
  
  -- Clean up
  _G.EVT_DieRollCallbacks[requestId] = nil
end

-- Roll die: ONE physical roll, result used immediately. Exception: Entrepreneur L2 during their turn gets Reroll/Go on choice.
local function rollDieForPlayer(color, requestPrefix, onDone)
  if not color then onDone(math.random(1,6), nil) return end
  local voc = findOneByTags and findOneByTags({TAG_VOCATIONS_CTRL}) or nil
  local needsEntRerollUI = false
  if voc and voc.call then
    local ok, res = pcall(function() return voc.call("VOC_CanUseEntrepreneurReroll", { color = color }) end)
    needsEntRerollUI = (ok and res == true)
  end
  if not needsEntRerollUI then
    -- Default: direct physical roll, one roll, immediate result
    rollRealDieAsync(nil, function(v, err) onDone(v and v >= 1 and v <= 6 and v or math.random(1,6), err) end)
    return
  end
  -- Entrepreneur L2 during their turn: use VocationsController for Reroll/Go on UI
  local ts = 0
  if Time and Time.time then ts = (type(Time.time) == "function") and Time.time() or Time.time
  elseif os and os.time then ts = os.time() end
  local requestId = (requestPrefix or "evt") .. "_" .. tostring(color) .. "_" .. tostring(ts)
  
  -- Get reference to this object (EventEngine) for callback
  -- In TTS, scripts run on objects, so 'self' should be available
  local eventEngineObject = self
  if not eventEngineObject then
    -- Fallback: try to find EventEngine object by GUID (from config)
    eventEngineObject = getObjectFromGUID and getObjectFromGUID(EVENTS_CONTROLLER_GUID) or nil
  end
  
  if not eventEngineObject then
    -- If we can't find the object, fall back to direct roll
    rollRealDieAsync(nil, function(v, err) onDone(v and v >= 1 and v <= 6 and v or math.random(1,6), err) end)
    return
  end
  
  -- Store callback info for OnDieRollResult
  if not _G.EVT_DieRollCallbacks then _G.EVT_DieRollCallbacks = {} end
  _G.EVT_DieRollCallbacks[requestId] = {
    onDone = onDone,
    color = color,
    requestId = requestId
  }
  
  -- Set up timeout fallback
  Wait.time(function()
    if _G.EVT_DieRollCallbacks and _G.EVT_DieRollCallbacks[requestId] then
      -- Timeout: clean up and use fallback
      _G.EVT_DieRollCallbacks[requestId] = nil
      onDone(math.random(1,6), nil)
    end
  end, 30)  -- 30 second timeout
  
  -- Call VocationsController with callback info
  pcall(function() 
    voc.call("VOC_RollDieForPlayer", { 
      requestId = requestId, 
      color = color,
      callbackObject = eventEngineObject,
      callbackFunction = "OnDieRollResult"
    }) 
  end)
end
-- CHUNK-SAFE: VECrimeTargetSelected is called via .call() and may run in different chunk
_G.EVT_rollDieForPlayer = rollDieForPlayer

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
mapPair("AD_72_VE-ENT1-PUB1","AD_73_VE-ENT1-PUB1","AD_VE_ENT1_PUB1")
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

-- Vocation Event (VE) card data
local VE_DISPLAY_NAMES = {
  SOC1 = "Social Worker", SOC2 = "Social Worker",
  CEL1 = "Celebrity",     CEL2 = "Celebrity",
  PUB1 = "Public Servant", PUB2 = "Public Servant",
  GAN1 = "Gangster",      GAN2 = "Gangster",
  NGO1 = "NGO Worker",    NGO2 = "NGO Worker",
  ENT1 = "Entrepreneur",  ENT2 = "Entrepreneur",
}
local VE_ACTION_IDS = {
  SOC1 = "SW_SPECIAL_HOMELESS",   SOC2 = "SW_SPECIAL_REMOVAL",
  CEL1 = "CELEB_SPECIAL_COLLAB",  CEL2 = "CELEB_SPECIAL_MEETUP",
  PUB1 = "PS_SPECIAL_POLICY",     PUB2 = "PS_SPECIAL_BOTTLENECK",
  GAN1 = "GANG_SPECIAL_ROBIN",    GAN2 = "GANG_SPECIAL_PROTECTION",
  NGO1 = "NGO_SPECIAL_CRISIS",    NGO2 = "NGO_SPECIAL_SCANDAL",
  ENT1 = "ENT_SPECIAL_EXPANSION", ENT2 = "ENT_SPECIAL_TRAINING",
}
local VE_CODE_TO_VOCATION = {
  SOC1 = "SOCIAL_WORKER", SOC2 = "SOCIAL_WORKER",
  CEL1 = "CELEBRITY",     CEL2 = "CELEBRITY",
  PUB1 = "PUBLIC_SERVANT", PUB2 = "PUBLIC_SERVANT",
  GAN1 = "GANGSTER",      GAN2 = "GANGSTER",
  NGO1 = "NGO_WORKER",    NGO2 = "NGO_WORKER",
  ENT1 = "ENTREPRENEUR",  ENT2 = "ENTREPRENEUR",
}
local VE_CRIME_TABLE = {
  AD_VE_NGO1_ENT1 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
  AD_VE_NGO1_GAN1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 250, steal3 = 600 },
  AD_VE_NGO2_SOC1 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
  AD_VE_NGO2_CEL1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 800 },
  AD_VE_ENT1_PUB1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
  AD_VE_ENT2_GAN2 = { ap = 1, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
  AD_VE_ENT2_SOC2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
  AD_VE_GAN1_PUB2 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
  AD_VE_CEL2_GAN2 = { ap = 2, [1] = "nothing", [2] = "wounded", [3] = "wounded_steal", steal = 1000 },
  AD_VE_SOC1_PUB1 = { ap = 2, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
  AD_VE_SOC2_CEL1 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
  AD_VE_CEL2_PUB2 = { ap = 1, [1] = "nothing", [2] = "wounded_steal", [3] = "wounded_steal", steal2 = 200, steal3 = 500 },
}
-- Chunk-safe: evt_veCrime and processCrimeRollResult may run in earlier chunks; expose for fallback
if not _G.WLB_EVT then _G.WLB_EVT = {} end
_G.WLB_EVT.CARD_TYPE = CARD_TYPE
_G.WLB_EVT.VE_CRIME_TABLE = VE_CRIME_TABLE
_G.WLB_EVT.rollDieForPlayer = rollDieForPlayer  -- chunk-safe: VECrimeTargetSelected calls this via .call()

-- AP costs for vocation event actions (used to calculate minimum action AP cost)
local VE_ACTION_AP_COSTS = {
  -- Social Worker
  SOC1 = 2,  -- SW_SPECIAL_HOMELESS
  SOC2 = 3,  -- SW_SPECIAL_REMOVAL
  -- Celebrity
  CEL1 = 2,  -- CELEB_SPECIAL_COLLAB
  CEL2 = 2,  -- CELEB_SPECIAL_MEETUP
  -- Public Servant
  PUB1 = 2,  -- PS_SPECIAL_POLICY
  PUB2 = 2,  -- PS_SPECIAL_BOTTLENECK
  -- Gangster
  GAN1 = 2,  -- GANG_SPECIAL_ROBIN
  GAN2 = 3,  -- GANG_SPECIAL_PROTECTION
  -- NGO Worker
  NGO1 = 2,  -- NGO_SPECIAL_CRISIS
  NGO2 = 2,  -- NGO_SPECIAL_SCANDAL
  -- Entrepreneur
  ENT1 = 2,  -- ENT_SPECIAL_EXPANSION
  ENT2 = 2,  -- ENT_SPECIAL_TRAINING
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
    -- Call for Auction: hand off to Events Controller (card moves to auction area, JOINING phase)
    local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
    local cardGuid = cardObj and cardObj.getGUID and cardObj.getGUID()
    if ctrl and ctrl.call and cardGuid then
      if type(auctionHandoffCardGuids) ~= "table" then auctionHandoffCardGuids = {} end
      auctionHandoffCardGuids[cardGuid] = true
      local ok, err = pcall(function()
        ctrl.call("Auction_Start", { initiatorColor = color, cardGuid = cardGuid })
      end)
      if not ok then
        auctionHandoffCardGuids[cardGuid] = nil
        safeBroadcastTo(color, "⚠️ Auction start failed: "..tostring(err), {1,0.6,0.2})
      end
    else
      if not ctrl or not ctrl.call then
        safeBroadcastTo(color, "⚠️ Events Controller not found. Cannot start auction.", {1,0.6,0.2})
      end
    end
    return STATUS.DONE
  end

  -- Luxury Tax: Pay 200 per owned hi-tech item (Public Servant may waive once per level)
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

    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    local canWaive = (voc and voc.call and (function()
      local ok, w = pcall(function() return voc.call("API_CanPublicServantWaiveTax", { color = color }) end)
      return ok and w == true
    end)())
    if canWaive then
      startChoiceOnCard_AB(
        cardObj, color, def.kind or "instant", "TAX_WAIVER_PS", cardId,
        "PAY\n(" .. tostring(totalTax) .. " WIN)",
        "WAIVE TAX",
        { totalTax = totalTax, taxType = "AD_LUXTAX", label = "Luxury Tax" }
      )
      return STATUS.WAIT_CHOICE
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
          costsCalc.call("addCost", {color=color, amount=totalTax, label="Property Tax L"..tostring(estateLevel)})
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
    
    -- Player can afford: offer Public Servant waiver (once per level) or deduct
    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    local canWaive = (voc and voc.call and (function()
      local ok, w = pcall(function() return voc.call("API_CanPublicServantWaiveTax", { color = color }) end)
      return ok and w == true
    end)())
    if canWaive then
      startChoiceOnCard_AB(
        cardObj, color, def.kind or "instant", "TAX_WAIVER_PS", cardId,
        "PAY\n(" .. tostring(totalTax) .. " WIN)",
        "WAIVE TAX",
        { totalTax = totalTax, taxType = "AD_PROPTAX", label = "Property Tax" }
      )
      return STATUS.WAIT_CHOICE
    end

    applyToPlayer_NoAP(color, { money = -totalTax }, "AD_PROPTAX")
    safeBroadcastTo(color, "🏠 Property Tax: Paid "..tostring(totalTax).." WIN (Apartment Level L"..tostring(estateLevel).." × 300).", {0.7,0.9,1})
    return STATUS.DONE
  end

  -- Hi-Tech Failure: Randomly break ONE owned hi-tech item (repair cost 25% of original). Card moves to used immediately.
  if def.special == "AD_HI_FAIL" then
    local shopEngine = findOneByTags({TAG_SHOP_ENGINE})
    if not shopEngine or not shopEngine.call then
      safeBroadcastTo(color, "⛔ Hi-Tech Failure: Shop Engine not found.", {1,0.6,0.2})
      return STATUS.ERROR
    end

    local ok, ownedList = pcall(function()
      return shopEngine.call("API_getOwnedHiTech", { color = color, excludePerkProxies = true })
    end)

    if not ok or type(ownedList) ~= "table" or #ownedList == 0 then
      safeBroadcastTo(color, "💻 Hi-Tech Failure: You own no hi-tech items → nothing to break.", {0.8,0.8,0.8})
      if type(finalizeCard) == "function" then finalizeCard(cardObj, "instant", color) end
      return STATUS.DONE
    end

    -- Randomly select ONE item to break (exclude already broken)
    local availableItems = {}
    brokenHiTech[color] = brokenHiTech[color] or {}
    brokenRepairCost[color] = brokenRepairCost[color] or {}
    for _, cardName in ipairs(ownedList) do
      if not brokenHiTech[color][cardName] then
        table.insert(availableItems, cardName)
      end
    end

    if #availableItems == 0 then
      safeBroadcastTo(color, "💻 Hi-Tech Failure: All your hi-tech items are already broken.", {0.9,0.9,0.6})
      if type(finalizeCard) == "function" then finalizeCard(cardObj, "instant", color) end
      return STATUS.DONE
    end

    local randomIdx = math.random(1, #availableItems)
    local brokenCardName = availableItems[randomIdx]

    brokenHiTech[color][brokenCardName] = true

    -- Repair cost: 25% of original (ShopEngine API_getHiTechDef returns equivalent cost for perks, e.g. HMONITOR=300 → 75)
    local repairCost = 75
    local ok2, cost = pcall(function()
      local ok3, hiTechDef = pcall(function()
        return shopEngine.call("API_getHiTechDef", {cardName=brokenCardName})
      end)
      if ok3 and hiTechDef and type(hiTechDef.cost) == "number" and hiTechDef.cost > 0 then
        return math.floor(hiTechDef.cost * 0.25)
      end
      if ok3 and hiTechDef and hiTechDef.kind == "HMONITOR" then return 75 end
      if ok3 and hiTechDef and hiTechDef.kind == "ALARM" then return math.floor(700 * 0.25) end
      if ok3 and hiTechDef and hiTechDef.kind == "CAR" then return math.floor(1200 * 0.25) end
      return 75
    end)
    repairCost = (ok2 and type(cost) == "number" and cost > 0) and cost or 75
    brokenRepairCost[color][brokenCardName] = repairCost

    safeBroadcastTo(color, "💻 Hi-Tech Failure: "..tostring(brokenCardName).." is broken! Repair cost: "..tostring(repairCost).." WIN (25% of original). Use the Repair button on the broken item.", {1,0.5,0.2})

    -- Refresh Shop Engine hi-tech card buttons so the broken card shows the Repair button
    pcall(function()
      if shopEngine and shopEngine.call then
        shopEngine.call("API_RefreshHiTechButtonsForColor", { color = color })
      end
    end)

    -- Move this event card to used pile immediately (no REPAIR/SKIP on event card)
    if type(finalizeCard) == "function" then finalizeCard(cardObj, "instant", color) end
    return STATUS.DONE
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
    local ve = def.ve
    if not ve or not ve.a or not ve.b then return nil end
    
    -- Check minimum AP required: slotExtra + lowest action cost
    -- NOTE: slotExtra AP will be charged by Events Controller after engine returns successfully
    -- We just need to check that player has enough AP, and mark that slotExtra will be charged
    local g = cardObj.getGUID()
    -- Read slotExtra AFTER CAR reduction (which happens earlier in playCardById)
    local slotExtra = tonumber(slotExtraAPForCard[g]) or 0
    
    -- Calculate actual minimum action AP cost:
    -- 1. Get crime AP cost from VE_CRIME_TABLE
    local typeKey = CARD_TYPE[cardId]
    local crimeAP = 1  -- Default fallback
    if typeKey then
      local crimeTable = VE_CRIME_TABLE
      if not crimeTable or type(crimeTable) ~= "table" then
        -- Fallback crime table
        crimeTable = {
          AD_VE_NGO1_ENT1 = { ap = 1 }, AD_VE_NGO1_GAN1 = { ap = 1 },
          AD_VE_NGO2_SOC1 = { ap = 2 }, AD_VE_NGO2_CEL1 = { ap = 2 },
          AD_VE_ENT1_PUB1 = { ap = 1 }, AD_VE_ENT2_GAN2 = { ap = 1 },
          AD_VE_ENT2_SOC2 = { ap = 2 }, AD_VE_GAN1_PUB2 = { ap = 2 },
          AD_VE_CEL2_GAN2 = { ap = 2 }, AD_VE_SOC1_PUB1 = { ap = 2 },
          AD_VE_SOC2_CEL1 = { ap = 1 }, AD_VE_CEL2_PUB2 = { ap = 1 },
        }
      end
      local crimeDef = crimeTable[typeKey]
      if crimeDef and crimeDef.ap then
        crimeAP = tonumber(crimeDef.ap) or 1
      end
    end
    
    -- 2. Get vocation action AP costs
    local actionAPCosts = VE_ACTION_AP_COSTS
    if not actionAPCosts or type(actionAPCosts) ~= "table" then
      -- Fallback action AP costs
      actionAPCosts = {
        SOC1 = 2, SOC2 = 3, CEL1 = 2, CEL2 = 2,
        PUB1 = 2, PUB2 = 2, GAN1 = 2, GAN2 = 3,
        NGO1 = 2, NGO2 = 2, ENT1 = 2, ENT2 = 2,
      }
    end
    local actionAAP = tonumber(actionAPCosts[ve.a]) or 999
    local actionBAP = tonumber(actionAPCosts[ve.b]) or 999
    
    -- 3. Find minimum: min(crimeAP, actionAAP, actionBAP)
    local minActionAP = math.min(crimeAP, actionAAP, actionBAP)
    local minTotalAP = slotExtra + minActionAP
    
    if DEBUG then log("VE card: slotExtra="..tostring(slotExtra).." minActionAP="..tostring(minActionAP).." minTotalAP="..tostring(minTotalAP).." for card "..tostring(g)) end
    
    -- Pre-check: ensure player has enough AP for slotExtra + minimum action
    -- Check even if slotExtra is 0, because there's still a minimum action cost
    if minTotalAP > 0 then
      local apCtrl = getApCtrl(color)
      if apCtrl and apCtrl.call then
        local apCostCheck = { to = "EVENT", amount = minTotalAP }
        local okCan, can = pcall(function() return apCtrl.call("canSpendAP", apCostCheck) end)
        if (not okCan) or (can ~= true) then
          safeBroadcastTo(color, "⛔ Not enough AP. Need "..tostring(minTotalAP).." AP (slot cost: "..tostring(slotExtra).." + action: "..tostring(minActionAP)..").", {1,0.6,0.2})
          -- Clear veSlotExtraCharged if it was set, since we're blocking
          veSlotExtraCharged[g] = nil
          return STATUS.BLOCKED
        end
      end
    end
    
    -- Mark that slotExtra AP will be charged by Events Controller (for refund on cancel)
    -- Events Controller charges slotExtra AP after engine returns STATUS.WAIT_CHOICE
    -- Store the adjusted slotExtra value that Events Controller will charge
    if slotExtra > 0 then
      veSlotExtraCharged[g] = slotExtra  -- Store the actual amount that will be charged (for accurate refund)
      if DEBUG then log("VE card: marked slotExtra AP="..tostring(slotExtra).." will be charged by Events Controller for card "..tostring(g)) end
    end
    
    local labelA = VE_DISPLAY_NAMES[ve.a] or ve.a
    local labelB = VE_DISPLAY_NAMES[ve.b] or ve.b
    pendingChoice[g] = { color = color, kind = def.kind or "instant", choiceKey = "VE_PICK_SIDE", cardId = cardId, meta = { ve = ve } }
    lockCard(g, LOCK_SEC)
    cardUI_clear(cardObj)
    cardUI_title(cardObj, "VOCATION EVENT")
    -- Four corners: top-left Crime, top-right Cancel, bottom-left vocation A, bottom-right vocation B
    cardUI_btnAt(cardObj, "Crime", "evt_veCrime", -0.6, 0.65, -0.6)
    cardUI_btnAt(cardObj, "Cancel", "evt_cancelPending", 0.6, 0.65, -0.6)
    cardUI_btnAt(cardObj, labelA, "evt_veChoiceA", -0.6, 0.15, 0.6)
    cardUI_btnAt(cardObj, labelB, "evt_veChoiceB", 0.6, 0.15, 0.6)
    safeBroadcastTo(color, "Choose: Crime, Cancel, or a vocation action.", {1,1,0.9})
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

  rollDieForPlayer(pd.color, "evt_dice", function(roll, err)
    cardUI_clear(cardObj)
    if not roll or roll < 1 or roll > 6 then
      roll = math.random(1,6)
      safeBroadcastTo(pd.color, "Die read failed; used fallback roll: "..tostring(roll), {1,0.8,0.3})
    end
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
    return
  end

  if pc.choiceKey == "TAX_WAIVER_PS" then
    local totalTax = tonumber(pc.meta and pc.meta.totalTax) or 0
    local taxType = (pc.meta and pc.meta.taxType) or "TAX"
    if totalTax > 0 and not canAfford(pc.color, -totalTax) then
      safeBroadcastTo(pc.color, "⛔ You don't have enough money to pay.", {1,0.6,0.2})
      return
    end
    if totalTax > 0 then
      applyToPlayer_NoAP(pc.color, { money = -totalTax }, taxType)
      safeBroadcastTo(pc.color, "💼 Tax paid: "..tostring(totalTax).." WIN.", {0.7,0.9,1})
    end
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
    return
  end

  if pc.choiceKey == "TAX_WAIVER_PS" then
    local voc = findOneByTags({TAG_VOCATIONS_CTRL})
    if voc and voc.call then
      pcall(function() voc.call("API_UsePublicServantTaxWaiver", { color = pc.color }) end)
    end
    safeBroadcastTo(pc.color, "📜 Tax waived (Mastery of Administrative Law – once per level).", {0.5,0.9,0.6})
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
  log("EventEngine: playCardById called for cardId=" .. tostring(cardId))
  
  local color = getPlayerColor()
  if not color then
    warn("No active player color.")
    return STATUS.ERROR
  end
  
  log("EventEngine: playCardById - color=" .. tostring(color))

  local typeKey = CARD_TYPE[cardId]
  if not typeKey then
    warn("Unknown card ID: "..tostring(cardId))
    safeBroadcastTo(color, "⚠️ Unknown card ID: "..tostring(cardId), {1,0.6,0.2})
    return STATUS.ERROR
  end
  
  log("EventEngine: playCardById - typeKey=" .. tostring(typeKey))

  local def = TYPES[typeKey]
  if not def then
    warn("No TYPES def for "..tostring(typeKey))
    safeBroadcastTo(color, "⚠️ No TYPES def for: "..tostring(typeKey), {1,0.6,0.2})
    return STATUS.ERROR
  end
  
  -- Celebrity event card obligation: Record event card play IMMEDIATELY after card validation
  -- This ensures ALL event board cards are tracked, including vouchers (which return early)
  -- Track before any early returns so we don't miss any cards
  recordCelebrityEventCardPlay(color, cardId, typeKey)

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

  -- SPECIAL (and Vocation Event cards: def.ve triggers 4-button choice)
  if def.special or (def.todo and def.ve) then
    local s = handleSpecial(color, cardId, def, cardObj)
    if s == STATUS.WAIT_CHOICE then return STATUS.WAIT_CHOICE end
    if s == STATUS.BLOCKED then return STATUS.BLOCKED end
    -- Call for Auction: Events Controller already moved the card to auction position; do not finalize (move to discard)
    if def.special == "AD_AUCTION_SCHEDULE" and s == STATUS.DONE then return STATUS.DONE end
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

  -- Use clicking player; in spectator mode (White) use current turn so the card is played as the active player
  if args.player_color and args.player_color ~= "" then
    local clicker = (args.player_color):sub(1,1):upper()..(args.player_color):sub(2):lower()
    if clicker == "White" and Turns and Turns.turn_color and Turns.turn_color ~= "" then
      activeColor = Turns.turn_color
    else
      activeColor = args.player_color
    end
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

-- Broken hi-tech: APIs for ShopEngine (check before use, show Repair button, perform repair)
function API_isHiTechBroken(args)
  args = args or {}
  local color = (args.color or args.player_color or ""):sub(1,1):upper()..(args.color or args.player_color or ""):sub(2):lower()
  local cardName = args.cardName or args.card_name
  if not color or color == "" or not cardName then return false end
  brokenHiTech[color] = brokenHiTech[color] or {}
  return (brokenHiTech[color][cardName] == true)
end

function API_getBrokenRepairCost(args)
  args = args or {}
  local color = (args.color or args.player_color or ""):sub(1,1):upper()..(args.color or args.player_color or ""):sub(2):lower()
  local cardName = args.cardName or args.card_name
  if not color or not cardName then return 0 end
  brokenRepairCost[color] = brokenRepairCost[color] or {}
  return tonumber(brokenRepairCost[color][cardName]) or 0
end

function API_repairBrokenHiTech(args)
  args = args or {}
  local color = (args.color or args.player_color or ""):sub(1,1):upper()..(args.color or args.player_color or ""):sub(2):lower()
  local cardName = args.cardName or args.card_name
  if not color or color == "" or not cardName then return false end
  brokenHiTech[color] = brokenHiTech[color] or {}
  brokenRepairCost[color] = brokenRepairCost[color] or {}
  if not brokenHiTech[color][cardName] then return false end
  local repairCost = tonumber(brokenRepairCost[color][cardName]) or 0
  if repairCost <= 0 then
    brokenHiTech[color][cardName] = nil
    brokenRepairCost[color][cardName] = nil
    return true
  end
  if not canAfford(color, -repairCost) then return false end
  applyToPlayer_NoAP(color, { money = -repairCost }, "HI_FAIL_REPAIR")
  brokenHiTech[color][cardName] = nil
  brokenRepairCost[color][cardName] = nil
  return true
end

-- Clear broken state for one card (e.g. when placing Public Servant proxy so it does not show as broken)
function API_clearBrokenHiTechForCard(args)
  args = args or {}
  local color = (args.color or args.player_color or ""):sub(1,1):upper()..(args.color or args.player_color or ""):sub(2):lower()
  local cardName = args.cardName or args.card_name
  if not color or color == "" or not cardName then return false end
  brokenHiTech[color] = brokenHiTech[color] or {}
  brokenRepairCost[color] = brokenRepairCost[color] or {}
  brokenHiTech[color][cardName] = nil
  brokenRepairCost[color][cardName] = nil
  return true
end

-- Clear all broken hi-tech state (e.g. on game reset so new game does not show spurious Repair)
function API_ClearBrokenState(_)
  for _, c in ipairs({"Yellow", "Blue", "Red", "Green"}) do
    brokenHiTech[c] = {}
    brokenRepairCost[c] = {}
  end
  return true
end

-- Called by VocationsController when canceling VE crime target selection
-- Refunds both slotExtra AP and crime action AP, and makes card interactable again
function CancelVECrimeTargetSelection(args)
  args = args or {}
  local cardGuid = args.card_guid or args.cardGuid
  if not cardGuid then
    log("CancelVECrimeTargetSelection: missing cardGuid")
    return false
  end
  
  local g = cardGuid
  local data = pendingVECrime[g]
  if not data then
    log("CancelVECrimeTargetSelection: no pendingVECrime for "..tostring(g))
    return false
  end
  
  local color = data.color
  
  log("CancelVECrimeTargetSelection: Starting refund for card "..tostring(g).." color="..tostring(color))
  
  -- Refund slotExtra AP if it was charged
  -- Get slotExtra from veSlotExtraCharged[g] (stored when VE UI was shown)
  -- OR from slotExtraAPForCard[g] as fallback (in case veSlotExtraCharged was cleared)
  local slotExtra = 0
  if veSlotExtraCharged[g] then
    slotExtra = tonumber(veSlotExtraCharged[g]) or 0
    log("CancelVECrimeTargetSelection: slotExtra from veSlotExtraCharged="..tostring(slotExtra))
  else
    -- Fallback: read from slotExtraAPForCard (should be the same value)
    slotExtra = tonumber(slotExtraAPForCard[g]) or 0
    log("CancelVECrimeTargetSelection: slotExtra from slotExtraAPForCard="..tostring(slotExtra))
  end
  
  -- Use a shared table to track refunds across async callbacks
  local refundTracker = { slotExtra = 0, crime = 0 }
  
  -- Refund slotExtra AP - refund one AP at a time using sequential Wait.time callbacks
  if slotExtra > 0 then
    local apCtrl = getApCtrl(color)
    if apCtrl and apCtrl.call then
      log("CancelVECrimeTargetSelection: Attempting to refund slotExtra AP="..tostring(slotExtra).." (one at a time, sequential)")
      -- Use sequential Wait.time callbacks to ensure each refund completes before the next
      -- Use longer delay (0.4s) to ensure each token fully settles before next one moves
      for i = 1, slotExtra do
        Wait.time(function()
          if apCtrl and apCtrl.call then
            local okRefund, result = pcall(function() 
              return apCtrl.call("moveAP", { to = "E", amount = -1 })
            end)
            if okRefund and result and type(result) == "table" and result.ok == true then
              local moved = tonumber(result.moved or 0) or 0
              if moved > 0 then
                refundTracker.slotExtra = refundTracker.slotExtra + moved
                log("CancelVECrimeTargetSelection: Refunded slotExtra AP chunk "..tostring(i)..": moved="..tostring(moved))
              else
                log("CancelVECrimeTargetSelection: WARNING slotExtra refund chunk "..tostring(i).." succeeded but moved=0")
              end
            else
              log("CancelVECrimeTargetSelection: FAILED slotExtra refund chunk "..tostring(i).." okRefund="..tostring(okRefund).." result="..tostring(result))
            end
            -- Log total after last refund
            if i == slotExtra then
              log("CancelVECrimeTargetSelection: Total slotExtra refunded="..tostring(refundTracker.slotExtra).." (requested "..tostring(slotExtra)..")")
            end
          end
        end, 0.4 * i) -- Increased delay to 0.4s per token to ensure full settlement
      end
    else
      log("CancelVECrimeTargetSelection: FAILED no apCtrl for color="..tostring(color))
    end
    -- Don't clear veSlotExtraCharged until refunds complete - cleared in final callback
  else
    log("CancelVECrimeTargetSelection: slotExtra is 0, skipping refund")
  end
  
  -- Refund crime action AP - refund one AP at a time using sequential Wait.time callbacks
  local crimeAP = data.crimeAP or 0
  log("CancelVECrimeTargetSelection: crimeAP="..tostring(crimeAP))
  if crimeAP > 0 then
    local apCtrl = getApCtrl(color)
    if apCtrl and apCtrl.call then
      log("CancelVECrimeTargetSelection: Attempting to refund crime AP="..tostring(crimeAP).." (one at a time, sequential)")
      -- Start crime AP refunds after slotExtra refunds complete
      -- Use longer delay (0.4s) to ensure each token fully settles before next one moves
      local startDelay = 0.4 * (slotExtra + 1)
      for i = 1, crimeAP do
        Wait.time(function()
          if apCtrl and apCtrl.call then
            local okRefund, result = pcall(function() 
              return apCtrl.call("moveAP", { to = "E", amount = -1 })
            end)
            if okRefund and result and type(result) == "table" and result.ok == true then
              local moved = tonumber(result.moved or 0) or 0
              if moved > 0 then
                refundTracker.crime = refundTracker.crime + moved
                log("CancelVECrimeTargetSelection: Refunded crime AP chunk "..tostring(i)..": moved="..tostring(moved))
              else
                log("CancelVECrimeTargetSelection: WARNING crime refund chunk "..tostring(i).." succeeded but moved=0")
              end
            else
              log("CancelVECrimeTargetSelection: FAILED crime refund chunk "..tostring(i).." okRefund="..tostring(okRefund).." result="..tostring(result))
            end
            -- Log total and send message after last refund
            if i == crimeAP then
              log("CancelVECrimeTargetSelection: Total crime AP refunded="..tostring(refundTracker.crime).." (requested "..tostring(crimeAP)..")")
              local totalRefunded = refundTracker.slotExtra + refundTracker.crime
              log("CancelVECrimeTargetSelection: Total refunded="..tostring(totalRefunded))
              -- Add small delay to let tokens settle before clearing state
              Wait.time(function()
                -- Clear state after all refunds complete and tokens settle
                veSlotExtraCharged[g] = nil -- Clear after all refunds complete
                pendingVECrime[g] = nil
                pendingChoice[g] = nil
                -- Clear card UI
                local cardObj = data.cardObj
                if cardObj then
                  cardUI_clear(cardObj)
                end
                -- Make card interactable again
                if lockUntil then lockUntil[g] = nil end
                clearDebounce(g)
                -- Notify Events Controller
                pcall(function()
                  local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
                  if ctrl and ctrl.call then
                    ctrl.call("onCardCancelled", { card_guid = g })
                  end
                end)
                -- Broadcast refund message
                if totalRefunded > 0 then
                  safeBroadcastTo(color, "Cancelled crime. Refunded "..tostring(totalRefunded).." AP.", {0.7,1,0.7})
                else
                  safeBroadcastTo(color, "Cancelled crime. (No AP refunded - check logs)", {1,0.6,0.2})
                end
                log("CancelVECrimeTargetSelection: cancelled VE crime for card "..tostring(g)..", refunded "..tostring(totalRefunded).." AP")
              end, 0.2) -- Small delay to let tokens settle
            end
          end
        end, startDelay + 0.4 * i) -- Increased delay to 0.4s per token to ensure full settlement
      end
    else
      log("CancelVECrimeTargetSelection: FAILED no apCtrl for color="..tostring(color))
      -- Clear state immediately if no AP controller
      pendingVECrime[g] = nil
      pendingChoice[g] = nil
      local cardObj = data.cardObj
      if cardObj then cardUI_clear(cardObj) end
      if lockUntil then lockUntil[g] = nil end
      clearDebounce(g)
      pcall(function()
        local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
        if ctrl and ctrl.call then
          ctrl.call("onCardCancelled", { card_guid = g })
        end
      end)
    end
  else
    log("CancelVECrimeTargetSelection: crimeAP is 0, skipping refund")
    -- If no crime AP to refund, send message after slotExtra refunds complete
    if slotExtra > 0 then
      -- Wait for all slotExtra refunds to complete, then add delay for tokens to settle
      Wait.time(function()
        local totalRefunded = refundTracker.slotExtra
        log("CancelVECrimeTargetSelection: Total refunded="..tostring(totalRefunded))
          -- Add small delay to let tokens settle before clearing state
          Wait.time(function()
            -- Clear state after all refunds complete and tokens settle
            veSlotExtraCharged[g] = nil -- Clear after all refunds complete
            pendingVECrime[g] = nil
            pendingChoice[g] = nil
            local cardObj = data.cardObj
            if cardObj then cardUI_clear(cardObj) end
            if lockUntil then lockUntil[g] = nil end
            clearDebounce(g)
            -- Notify Events Controller
            pcall(function()
              local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
              if ctrl and ctrl.call then
                ctrl.call("onCardCancelled", { card_guid = g })
              end
            end)
            -- Broadcast refund message
            if totalRefunded > 0 then
              safeBroadcastTo(color, "Cancelled crime. Refunded "..tostring(totalRefunded).." AP.", {0.7,1,0.7})
            else
              safeBroadcastTo(color, "Cancelled crime. (No AP refunded - check logs)", {1,0.6,0.2})
            end
            log("CancelVECrimeTargetSelection: cancelled VE crime for card "..tostring(g)..", refunded "..tostring(totalRefunded).." AP")
          end, 0.2) -- Small delay to let tokens settle
        end, 0.4 * (slotExtra + 1)) -- Increased delay to match refund timing
    else
      -- No refunds needed, clear state immediately
      pendingVECrime[g] = nil
      pendingChoice[g] = nil
      local cardObj = data.cardObj
      if cardObj then cardUI_clear(cardObj) end
      if lockUntil then lockUntil[g] = nil end
      clearDebounce(g)
      pcall(function()
        local ctrl = getObjectFromGUID(EVENTS_CONTROLLER_GUID)
        if ctrl and ctrl.call then
          ctrl.call("onCardCancelled", { card_guid = g })
        end
      end)
      safeBroadcastTo(color, "Cancelled crime. (No AP to refund)", {0.7,1,0.7})
    end
  end
  
  return true
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

-- True if this event card gives a Good Karma token (KARMA, AD_KARMA). Used by NGO "Take Good Karma (free)" to find a card in the event lane.
function isGoodKarmaCard(args)
  args = args or {}
  local guid = args.card_guid or args.cardGuid
  if not guid or guid == "" then return false end
  local cardObj = getObjectFromGUID(guid)
  if not cardObj or cardObj.tag ~= "Card" then return false end
  local cardId = extractCardId(cardObj)
  if not cardId then return false end
  local typeKey = CARD_TYPE[cardId]
  local def = typeKey and TYPES[typeKey] or nil
  if not def then return false end
  if def.karma == true then return true end
  if def.statusAddTag == STATUS_TAG.GOODKARMA then return true end
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
  -- Save broken hi-tech state and repair costs
  return JSON.encode({ brokenHiTech = brokenHiTech, brokenRepairCost = brokenRepairCost })
end

function onLoad(saved_data)
  print("[WLB EVENT] onLoad OK - engine alive (v1.7.2)")

  -- Load broken hi-tech state and repair costs
  if saved_data and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" then
      if data.brokenHiTech then brokenHiTech = data.brokenHiTech end
      if data.brokenRepairCost then brokenRepairCost = data.brokenRepairCost end
    end
  end
  
  -- Ensure all colors exist in brokenHiTech and brokenRepairCost
  brokenHiTech = brokenHiTech or {}
  brokenRepairCost = brokenRepairCost or {}
  for _, c in ipairs({"Yellow","Blue","Red","Green"}) do
    brokenHiTech[c] = brokenHiTech[c] or {}
    brokenRepairCost[c] = brokenRepairCost[c] or {}
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
