-- =========================================================
-- WLB PLAYER STATUS CONTROLLER v0.4.0
-- GOAL:
--  - receive signals from EventEngine
--  - forward to TokenEngine (WLB_TOKEN_SYSTEM) via object.call wrappers
--  - track child-blocked AP (permanent) vs other-blocked AP (temporary)
-- REQUIREMENT:
--  - TokenEngine must expose *_ARGS wrappers (see patch below)
-- NEW v0.4.0:
--  - Child-blocked AP tracking system
--  - APIs to query/remove specific types of blocked AP
-- =========================================================

local DEBUG = true
local VERSION = "0.4.0"

-- Tags
local TAG_SELF         = "WLB_PLAYER_STATUS_CTRL"
local TAG_TOKEN_ENGINE = "WLB_TOKEN_SYSTEM" -- your snapshot confirms this tag exists
local TAG_SHOP_ENGINE  = "WLB_SHOP_ENGINE"

-- Status tags (must match TokenEngine constants)
-- These are the STRING VALUES used in scripts (PS_Event, HAS_STATUS, etc.).
--
-- PHYSICAL TOKEN IN TTS (Good Karma example):
--   The Good Karma token object in Tabletop Simulator must have exactly these tags:
--     - WLB_STATUS_TOKEN
--     - WLB_STATUS_GOOD_KARMA
--   Nothing else (no WLB_COLOR_*). TokenEngine pools by these tags; logic uses PSC/TokenEngine state, not color on token.
local TAG_STATUS_SICK       = "WLB_STATUS_SICK"
local TAG_STATUS_WOUNDED    = "WLB_STATUS_WOUNDED"
local TAG_STATUS_ADDICTION  = "WLB_STATUS_ADDICTION"
local TAG_STATUS_DATING     = "WLB_STATUS_DATING"
local TAG_STATUS_GOODKARMA  = "WLB_STATUS_GOOD_KARMA"
local TAG_STATUS_EXPERIENCE = "WLB_STATUS_EXPERIENCE"
local TAG_STATUS_VOUCH_C    = "WLB_STATUS_VOUCH_C"
local TAG_STATUS_VOUCH_H    = "WLB_STATUS_VOUCH_H"
local TAG_STATUS_VOUCH_P    = "WLB_STATUS_VOUCH_P"

-- High-level keys from EventEngine -> status tags
-- (EventEngine can send either statusTag directly OR "effect"/"statusKey")
local MAP_KEY_TO_TAG = {
  SICK       = TAG_STATUS_SICK,
  WOUNDED    = TAG_STATUS_WOUNDED,
  ADDICTION  = TAG_STATUS_ADDICTION,
  DATING     = TAG_STATUS_DATING,
  GOODKARMA  = TAG_STATUS_GOODKARMA,
  EXPERIENCE = TAG_STATUS_EXPERIENCE,
  VOUCH_C    = TAG_STATUS_VOUCH_C,
  VOUCH_H    = TAG_STATUS_VOUCH_H,
  VOUCH_P    = TAG_STATUS_VOUCH_P,
}

-- State
local TokenEngine = nil

-- Child-blocked AP tracking: [color] = count of AP permanently blocked by children
-- This is separate from other INACTIVE AP (like addiction) which are temporary
local childBlockedAP = { Yellow=0, Blue=0, Red=0, Green=0 }

-- =========================================================
-- UTILS
-- =========================================================
local function log(msg)  if DEBUG then print("[WLB_STATUS_CTRL] " .. tostring(msg)) end end
local function warn(msg) print("[WLB_STATUS_CTRL][WARN] " .. tostring(msg)) end

local function ensureSelfTag()
  if self and self.addTag and self.hasTag then
    if not self.hasTag(TAG_SELF) then self.addTag(TAG_SELF) end
  end
end

local function findTokenEngine()
  local list = getObjectsWithTag(TAG_TOKEN_ENGINE) or {}
  if #list > 0 then return list[1] end
  -- fallback scan
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_TOKEN_ENGINE) then return o end
  end
  return nil
end

local function safeCall(obj, fnName, argsTable)
  if not obj or not obj.call then return false, "no obj.call" end
  local ok, res = pcall(function() return obj.call(fnName, argsTable or {}) end)
  if not ok then return false, tostring(res) end
  return true, res
end

local function normalizeColor(c)
  c = tostring(c or "")
  if c == "" then return "" end
  -- keep TTS colors: "Yellow","Blue","Red","Green"
  -- if someone sends lower-case
  local u = c:sub(1,1):upper() .. c:sub(2):lower()
  return u
end

local function normalizeKey(k)
  k = tostring(k or "")
  if k == "" then return "" end
  return string.upper(k)
end

local function resolveStatusTag(payload)
  -- 1) explicit statusTag
  local tag = payload.statusTag or payload.tag
  if tag and tag ~= "" then return tostring(tag) end

  -- 2) statusKey/effect in symbolic form
  local key = payload.statusKey or payload.effect or payload.status
  key = normalizeKey(key)
  if key == "" then return "" end

  return MAP_KEY_TO_TAG[key] or ""
end

local function ensureEngine()
  if TokenEngine and TokenEngine.getGUID then return true end
  TokenEngine = findTokenEngine()
  if not TokenEngine then
    warn("TokenEngine not found (tag="..TAG_TOKEN_ENGINE..")")
    return false
  end
  log("TokenEngine OK: "..tostring(TokenEngine.getGUID()).." name="..tostring(TokenEngine.getName()))
  return true
end

-- =========================================================
-- FORWARDERS (require *_ARGS wrappers in TokenEngine)
-- =========================================================
local function TE_AddStatus(color, statusTag)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_AddStatus_ARGS", { color=color, statusTag=statusTag })
end

local function TE_RemoveStatus(color, statusTag)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_RemoveStatus_ARGS", { color=color, statusTag=statusTag })
end

local function TE_ClearStatuses(color)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_ClearStatuses_ARGS", { color=color })
end

local function TE_RefreshStatuses(color)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_RefreshStatuses_ARGS", { color=color })
end

local function TE_AddMarriage(color)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_AddMarriage_ARGS", { color=color })
end

local function TE_AddChild(color, sex)
  if not ensureEngine() then return false end
  return safeCall(TokenEngine, "TE_AddChild_ARGS", { color=color, sex=sex })
end

local function TE_HasStatus(color, statusTag)
  if not ensureEngine() then return false end
  local ok, res = safeCall(TokenEngine, "TE_HasStatus_ARGS", { color=color, statusTag=statusTag })
  return ok and res == true
end

local function TE_GetStatusCount(color, statusTag)
  if not ensureEngine() then return 0 end
  local ok, res = safeCall(TokenEngine, "TE_GetStatusCount_ARGS", { color=color, statusTag=statusTag })
  if ok and type(res) == "number" then return math.max(0, math.floor(res)) end
  return 0
end

local function TE_RemoveStatusCount(color, statusTag, count)
  if not ensureEngine() then return false end
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count == 0 then return true end
  return safeCall(TokenEngine, "TE_RemoveStatusCount_ARGS", { color=color, statusTag=statusTag, count=count })
end

-- =========================================================
-- PUBLIC API for EventEngine
-- =========================================================
-- Recommended payloads from EventEngine:
--   PS_Event({ color="Blue", op="ADD_STATUS", statusKey="SICK" })
--   PS_Event({ color="Blue", op="ADD_STATUS", statusTag="WLB_STATUS_SICK" })
--   PS_Event({ color="Blue", op="REMOVE_STATUS", statusKey="SICK" })
--   PS_Event({ color="Blue", op="HAS_STATUS", statusKey="SICK" })  -- Returns true/false
--   PS_Event({ color="Blue", op="CLEAR_STATUSES" })
--   PS_Event({ color="Blue", op="REFRESH_STATUSES" })
--   PS_Event({ color="Blue", op="ADD_MARRIAGE" })
--   PS_Event({ color="Blue", op="ADD_CHILD", sex="BOY" })  -- BOY/GIRL/"" (random if "")
function PS_Event(payload)
  payload = payload or {}

  local color = normalizeColor(payload.color or payload.player_color or payload.player)
  local op = normalizeKey(payload.op or payload.action)

  if color == "" and op ~= "PING" then
    warn("PS_Event: missing color")
    return false
  end

  if op == "PING" then
    ensureEngine()
    broadcastToAll("PS_Event PING OK (v"..VERSION..")", {0.7,0.9,1})
    return true
  end

  if op == "ADD_STATUS" or op == "REMOVE_STATUS" or op == "HAS_STATUS" or op == "GET_STATUS_COUNT" or op == "REMOVE_STATUS_COUNT" then
    local statusTag = resolveStatusTag(payload)
    if statusTag == "" then
      warn("PS_Event: cannot resolve statusTag (provide statusTag or statusKey/effect)")
      return false
    end

    if op == "ADD_STATUS" then
      local ok, err = TE_AddStatus(color, statusTag)
      if not ok then warn("ADD_STATUS failed: "..tostring(err)) end
      return ok
    elseif op == "REMOVE_STATUS" then
      local ok, err = TE_RemoveStatus(color, statusTag)
      if not ok then warn("REMOVE_STATUS failed: "..tostring(err)) end
      return ok
    elseif op == "HAS_STATUS" then
      return TE_HasStatus(color, statusTag)
    elseif op == "GET_STATUS_COUNT" then
      return TE_GetStatusCount(color, statusTag)
    elseif op == "REMOVE_STATUS_COUNT" then
      local count = math.max(0, math.floor(tonumber(payload.count) or 0))
      local ok, err = TE_RemoveStatusCount(color, statusTag, count)
      if not ok then warn("REMOVE_STATUS_COUNT failed: "..tostring(err)) end
      return ok
    end
  end

  if op == "CLEAR_STATUSES" then
    local ok, err = TE_ClearStatuses(color)
    if not ok then warn("CLEAR_STATUSES failed: "..tostring(err)) end
    return ok
  end

  if op == "REFRESH_STATUSES" then
    local ok, err = TE_RefreshStatuses(color)
    if not ok then warn("REFRESH_STATUSES failed: "..tostring(err)) end
    return ok
  end

  if op == "ADD_MARRIAGE" then
    local ok, err = TE_AddMarriage(color)
    if not ok then warn("ADD_MARRIAGE failed: "..tostring(err)) end
    return ok
  end

  if op == "ADD_CHILD" then
    local sex = normalizeKey(payload.sex or payload.gender)
    if sex ~= "BOY" and sex ~= "GIRL" then sex = nil end -- nil => token engine random
    local ok, err = TE_AddChild(color, sex)
    if not ok then 
      warn("ADD_CHILD failed: "..tostring(err))
      return false
    end
    -- Track child-blocked AP: each child permanently blocks 2 AP
    childBlockedAP[color] = (childBlockedAP[color] or 0) + 2
    log("ADD_CHILD: "..color.." child-blocked AP = "..tostring(childBlockedAP[color]))
    return true
  end

  warn("PS_Event: unknown op="..tostring(op))
  return false
end

-- =========================================================
-- CHILD-BLOCKED AP TRACKING APIs
-- =========================================================
-- These APIs allow other systems to query and manage child-blocked AP
-- Child-blocked AP is permanent (until child is removed)
-- Other INACTIVE AP (addiction, etc.) is temporary

function PS_GetChildBlockedAP(params)
  -- Returns count of AP permanently blocked by children
  -- MARRIAGE reduces this by 1 per child (if married)
  -- BABYMONITOR reduces this by 1 per baby for first 2 babies (max 2 babies)
  -- params: {color="Yellow"} or just "Yellow"
  local color = params
  if type(params) == "table" then
    color = params.color or params.player_color or params[1]
  end
  color = normalizeColor(color)
  if color == "" then return 0 end
  
  local rawBlocked = childBlockedAP[color] or 0
  
  -- Calculate number of babies (each baby blocks 2 AP normally)
  local numBabies = math.floor(rawBlocked / 2)
  
  -- Check for MARRIAGE (reduces by 1 AP per child) — source of truth: TokenEngine state
  local marriageReduction = 0
  if TE_HasStatus(color, "WLB_STATUS_MARRIAGE") then
    marriageReduction = numBabies
  end
  
  -- Check for BABYMONITOR ownership (count how many BABYMONITOR cards player owns, max 2)
  local shopEngine = nil
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_SHOP_ENGINE) then
      shopEngine = o
      break
    end
  end
  
  local babyMonitorReduction = 0
  if shopEngine and shopEngine.call then
    -- Check for BABYMONITOR ownership using kind check (more reliable than name matching)
    local ok, hasMonitor = pcall(function()
      return shopEngine.call("API_ownsHiTech", {color=color, kind="BABYMONITOR"})
    end)
    
    if ok and hasMonitor == true then
      -- IMPORTANT: Only ONE BABYMONITOR works per player
      -- Player can own 2 BABYMONITOR cards, but only ONE provides reduction
      -- Having multiple monitors does NOT increase the reduction - owning 2 monitors gives the same benefit as owning 1
      -- Reduction: 1 AP per baby for first 2 babies (so max 2 AP reduction)
      -- Formula: reduction = min(numBabies, 2) as long as player owns at least 1 BABYMONITOR
      babyMonitorReduction = math.min(numBabies, 2)
      
      if babyMonitorReduction > 0 then
        log("BABYMONITOR: "..color.." reduces child-blocked AP by "..tostring(babyMonitorReduction).." (babies: "..tostring(numBabies)..")")
      end
    end
  end
  
  local effectiveBlocked = math.max(0, rawBlocked - marriageReduction - babyMonitorReduction)
  
  if marriageReduction > 0 then
    log("MARRIAGE: "..color.." reduces child-blocked AP by "..tostring(marriageReduction).." (babies: "..tostring(numBabies)..")")
  end
  
  return effectiveBlocked
end

function PS_RemoveChildBlockedAP(params)
  -- Removes child-blocked AP (for cards that can unblock it)
  -- params: {color="Yellow", amount=2}
  local color = params.color or params.player_color or params[1]
  local amount = tonumber(params.amount or params.amt or 0) or 0
  color = normalizeColor(color)
  if color == "" or amount <= 0 then return false end
  
  local current = childBlockedAP[color] or 0
  local remove = math.min(amount, current)
  childBlockedAP[color] = math.max(0, current - remove)
  log("RemoveChildBlockedAP: "..color.." removed "..remove.." (was "..current..", now "..childBlockedAP[color]..")")
  return remove > 0
end

-- =========================================================
-- STATUS QUERY API (for other engines)
-- =========================================================
function PS_HasStatus(params)
  -- Query if player has a specific status
  -- params: {color="Yellow", statusTag="WLB_STATUS_SICK"} or {color="Yellow", statusKey="SICK"}
  local color = params
  if type(params) == "table" then
    color = params.color or params.player_color or params.player or params[1]
  end
  color = normalizeColor(color)
  if color == "" then return false end
  
  local statusTag = resolveStatusTag(params)
  if statusTag == "" then
    warn("PS_HasStatus: cannot resolve statusTag (provide statusTag or statusKey/effect)")
    return false
  end
  
  return TE_HasStatus(color, statusTag)
end

function PS_GetNonChildBlockedAP(params)
  -- Returns count of INACTIVE AP that is NOT from children (for cards that can unblock other sources)
  -- params: {color="Yellow"}
  -- This requires querying AP Controller for total INACTIVE count, then subtracting child-blocked
  local color = params.color or params.player_color or params[1]
  color = normalizeColor(color)
  if color == "" then return 0 end
  
  -- Find AP Controller for this color
  local TAG_AP_CTRL = "WLB_AP_CTRL"
  local TAG_COLOR_PREFIX = "WLB_COLOR_"
  local colorTag = TAG_COLOR_PREFIX .. color
  
  local apCtrl = nil
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_AP_CTRL) and o.hasTag(colorTag) then
      apCtrl = o
      break
    end
  end
  
  if not apCtrl or not apCtrl.call then
    warn("PS_GetNonChildBlockedAP: AP Controller not found for "..color)
    return 0
  end
  
  -- Get total INACTIVE count
  local ok, inactiveCount = pcall(function() 
    return apCtrl.call("getCount", {field="INACTIVE"}) or apCtrl.call("getCount", {area="INACTIVE"}) or apCtrl.call("getCount", {to="INACTIVE"}) or 0
  end)
  
  if not ok or type(inactiveCount) ~= "number" then
    warn("PS_GetNonChildBlockedAP: failed to get INACTIVE count for "..color)
    return 0
  end
  
  -- Use PS_GetChildBlockedAP to get effective child-blocked AP (includes BABYMONITOR reduction)
  local childBlocked = PS_GetChildBlockedAP({color=color})
  local nonChildBlocked = math.max(0, inactiveCount - childBlocked)
  return nonChildBlocked
end

-- =========================================================
-- MANUAL TEST buttons (testing: Good Karma + vouchers)
-- =========================================================
local function testTargetColor(pc)
  if Turns and Turns.turn_color and Turns.turn_color ~= "" then
    return normalizeColor(Turns.turn_color)
  end
  return normalizeColor(pc or "")
end

function PS_TestAddGoodKarma(_, pc)
  local c = testTargetColor(pc)
  if c == "" then broadcastToAll("No current player (set turn or click as that color)", {1,0.5,0.5}) return end
  PS_Event({color=c, op="ADD_STATUS", statusTag=TAG_STATUS_GOODKARMA})
  broadcastToAll("+ Good Karma ("..c..")", {1,0.9,0.5})
end

function PS_TestAddVouchC(_, pc)
  local c = testTargetColor(pc)
  if c == "" then broadcastToAll("No current player (set turn or click as that color)", {1,0.5,0.5}) return end
  PS_Event({color=c, op="ADD_STATUS", statusTag=TAG_STATUS_VOUCH_C})
  broadcastToAll("+ Consumable voucher ("..c..")", {0.85,0.95,0.9})
end

function PS_TestAddVouchH(_, pc)
  local c = testTargetColor(pc)
  if c == "" then broadcastToAll("No current player (set turn or click as that color)", {1,0.5,0.5}) return end
  PS_Event({color=c, op="ADD_STATUS", statusTag=TAG_STATUS_VOUCH_H})
  broadcastToAll("+ Hi-Tech voucher ("..c..")", {0.85,0.95,0.9})
end

function PS_TestAddVouchP(_, pc)
  local c = testTargetColor(pc)
  if c == "" then broadcastToAll("No current player (set turn or click as that color)", {1,0.5,0.5}) return end
  PS_Event({color=c, op="ADD_STATUS", statusTag=TAG_STATUS_VOUCH_P})
  broadcastToAll("+ Property voucher ("..c..")", {0.85,0.95,0.9})
end

function onSave()
  -- Save child-blocked AP tracking
  return JSON.encode({ childBlockedAP = childBlockedAP })
end

function onLoad(saved)
  ensureSelfTag()
  ensureEngine()
  
  -- Load child-blocked AP tracking
  if saved and saved ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved) end)
    if ok and type(data) == "table" and data.childBlockedAP then
      childBlockedAP = data.childBlockedAP
    end
  end
  
  -- Ensure all colors exist
  childBlockedAP = childBlockedAP or {}
  childBlockedAP.Yellow = childBlockedAP.Yellow or 0
  childBlockedAP.Blue = childBlockedAP.Blue or 0
  childBlockedAP.Red = childBlockedAP.Red or 0
  childBlockedAP.Green = childBlockedAP.Green or 0
  
  print("[WLB_STATUS_CTRL] loaded v"..VERSION)

  -- Test UI: Good Karma + voucher tokens for current player (status preserved via TokenEngine)
  self.clearButtons()
  self.createButton({
    label="+ Good Karma", click_function="PS_TestAddGoodKarma", function_owner=self,
    position={0,0.2,0.45}, width=1200, height=240, font_size=120
  })
  self.createButton({
    label="+ Vouch C", click_function="PS_TestAddVouchC", function_owner=self,
    position={0,0.2,0.15}, width=1000, height=220, font_size=110
  })
  self.createButton({
    label="+ Vouch H", click_function="PS_TestAddVouchH", function_owner=self,
    position={0,0.2,-0.15}, width=1000, height=220, font_size=110
  })
  self.createButton({
    label="+ Vouch P", click_function="PS_TestAddVouchP", function_owner=self,
    position={0,0.2,-0.45}, width=1000, height=220, font_size=110
  })
end
