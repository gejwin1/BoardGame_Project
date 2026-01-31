-- =========================
-- YOUTH BOARD v1.3 (FULL REPLACE)
-- GOAL:
--  - ZAWSZE działa dla AKTYWNEGO gracza z Turns (Turns.turn_color)
--  - Zero "dziwnych kolorów" – tylko: Yellow / Blue / Red / Green
--  - AP zawsze idzie do EVENT
--  - paidTechThisYear / paidUniThisYear per gracz (tabele)
-- =========================

local DEBUG = true

-- =========================================================
-- [SECTION 1] TAGS + YEAR FLAGS (per color)
-- =========================================================
local TAG_AP_CTRL       = "WLB_AP_CTRL"
local TAG_STATS_CTRL    = "WLB_STATS_CTRL"
local TAG_MONEY         = "WLB_MONEY"
local COLOR_TAG_PREFIX  = "WLB_COLOR_"

local VALID_COLORS = { Yellow=true, Blue=true, Red=true, Green=true }

-- yearly flags per player color
local paidTechThisYear = { Yellow=false, Blue=false, Red=false, Green=false }
local paidUniThisYear  = { Yellow=false, Blue=false, Red=false, Green=false }

-- =========================================================
-- [SECTION 2] YEAR FLAGS API (called by TokenYear / TurnStart as needed)
-- =========================================================
function resetYearFlags()
  paidTechThisYear = { Yellow=false, Blue=false, Red=false, Green=false }
  paidUniThisYear  = { Yellow=false, Blue=false, Red=false, Green=false }
  if DEBUG then print("[YOUTH BOARD] resetYearFlags() -> TECH/UNI unlocked for all colors") end
end

function resetNewGameYouth()
  resetYearFlags()
end

-- =========================================================
-- [SECTION 3] HELPERS (log, normalize color, find controllers by tags)
-- =========================================================
local function log(msg) if DEBUG then print("[YOUTH BOARD] " .. tostring(msg)) end end
local function warn(msg) print("[YOUTH BOARD][WARN] " .. tostring(msg)) end

local function normColor(c)
  if not c then return nil end
  local s = tostring(c):gsub("^%s+",""):gsub("%s+$","")
  if s == "" then return nil end
  s = s:sub(1,1):upper() .. s:sub(2):lower()
  return s
end

local function colorTag(color)
  return COLOR_TAG_PREFIX .. tostring(color)
end

local function findByTags(tags)
  for _, o in ipairs(getAllObjects()) do
    local ok = true
    for _, t in ipairs(tags) do
      if not (o and o.hasTag and o.hasTag(t)) then ok = false break end
    end
    if ok then return o end
  end
  return nil
end

local function getAP(color)    return findByTags({ TAG_AP_CTRL,    colorTag(color) }) end
local function getStats(color) return findByTags({ TAG_STATS_CTRL, colorTag(color) }) end
local function getMoney(color) return findByTags({ TAG_MONEY,      colorTag(color) }) end

-- =========================================================
-- [SECTION 4] MONEY (robust read + cannot go below 0)
-- =========================================================
local function moneyGet(moneyObj)
  if not moneyObj or not moneyObj.call then return nil end
  local ok, v

  ok, v = pcall(function() return moneyObj.call("getMoney") end)
  if ok and type(v) == "number" then return v end
  ok, v = pcall(function() return moneyObj.call("getMoney", {}) end)
  if ok and type(v) == "number" then return v end

  ok, v = pcall(function() return moneyObj.call("getValue") end)
  if ok and type(v) == "number" then return v end
  ok, v = pcall(function() return moneyObj.call("getAmount") end)
  if ok and type(v) == "number" then return v end

  ok, v = pcall(function() return moneyObj.call("getState") end)
  if ok and type(v) == "table" and type(v.money) == "number" then return v.money end

  return nil
end

local function canAfford(color, deltaNegative)
  local moneyObj = getMoney(color)
  if not moneyObj then
    warn("Money controller not found (tag "..TAG_MONEY.." + "..colorTag(color)..")")
    return false
  end
  local cur = moneyGet(moneyObj)
  if type(cur) ~= "number" then
    warn("Money controller has no readable getMoney API -> blocking negative spend for safety.")
    return false
  end
  return (cur + (tonumber(deltaNegative) or 0)) >= 0
end

local function moneyAdd(color, delta)
  local m = getMoney(color)
  if not m or not m.call then
    warn("Money controller not found (tag "..TAG_MONEY.." + "..colorTag(color)..")")
    return false
  end

  delta = tonumber(delta) or 0
  if delta < 0 and not canAfford(color, delta) then
    log(color..": MONEY blocked: not enough funds for "..tostring(delta))
    return false
  end

  local ok = pcall(function() m.call("addMoney", { amount = delta }) end)
  if ok then return true end

  ok = pcall(function() m.call("addMoney", { delta = delta }) end)
  return ok
end

-- =========================================================
-- [SECTION 5] AP (always to EVENT)
-- =========================================================
local function canSpendAP(color, amount)
  local ap = getAP(color)
  if not ap or not ap.call then
    warn("AP controller not found (tag "..TAG_AP_CTRL.." + "..colorTag(color)..")")
    return false
  end
  local ok, can = pcall(function()
    return ap.call("canSpendAP", { to = "EVENT", amount = amount })
  end)
  return ok and can == true
end

local function spendAP(color, amount)
  local ap = getAP(color)
  if not ap or not ap.call then
    warn("AP controller not found (tag "..TAG_AP_CTRL.." + "..colorTag(color)..")")
    return false
  end
  local ok, paid = pcall(function()
    return ap.call("spendAP", { to = "EVENT", amount = amount })
  end)
  return ok and paid == true
end

-- =========================================================
-- [SECTION 6] STATS (applyDelta)
-- =========================================================
local function addSkill(color, n)
  local stats = getStats(color)
  if not stats or not stats.call then
    warn("Stats controller not found (tag "..TAG_STATS_CTRL.." + "..colorTag(color)..")")
    return false
  end
  return pcall(function() stats.call("applyDelta", { s = n }) end)
end

local function addKnowledge(color, n)
  local stats = getStats(color)
  if not stats or not stats.call then
    warn("Stats controller not found (tag "..TAG_STATS_CTRL.." + "..colorTag(color)..")")
    return false
  end
  return pcall(function() stats.call("applyDelta", { k = n }) end)
end

-- =========================================================
-- [SECTION 7] ACTOR = ACTIVE TURN COLOR ONLY (Turns.turn_color)
-- =========================================================
local function getActiveTurnColor()
  if not (Turns and Turns.turn_color and Turns.turn_color ~= "") then
    return nil
  end
  local c = normColor(Turns.turn_color)
  if c and VALID_COLORS[c] then return c end
  return nil
end

local function getActorColor()
  local c = getActiveTurnColor()
  if not c then
    warn("No active player from Turns (Turns OFF / invalid turn_color). Action blocked.")
    broadcastToAll("[YOUTH BOARD] ⛔ No active player with Turns.turn_color. Enable Turns and set turn (Yellow/Blue/Red/Green).", {1,0.6,0.2})
    return nil
  end
  return c
end

-- =========================================================
-- [SECTION 8] ACTIONS (ALWAYS ACTIVE PLAYER)
-- =========================================================

-- 2 AP -> +1 SKILL
function actionVocSchool(_, playerColor)
  local c = getActorColor()
  if not c then return end

  if not canSpendAP(c, 2) then log(c..": VOC-SCH blocked: not enough AP"); return end
  if not spendAP(c, 2) then warn(c..": VOC-SCH: spendAP failed"); return end
  addSkill(c, 1)
  log(c..": VOC-SCH: paid 2 AP->EVENT, +1 SKILL")
end

-- 2 AP -> +1 KNOWLEDGE
function actionHighSchool(_, playerColor)
  local c = getActorColor()
  if not c then return end

  if not canSpendAP(c, 2) then log(c..": HI-SCH blocked: not enough AP"); return end
  if not spendAP(c, 2) then warn(c..": HI-SCH: spendAP failed"); return end
  addKnowledge(c, 1)
  log(c..": HI-SCH: paid 2 AP->EVENT, +1 KNOWLEDGE")
end

-- 1 AP -> +50 MONEY
function actionJob(_, playerColor)
  local c = getActorColor()
  if not c then return end

  if not canSpendAP(c, 1) then log(c..": JOB blocked: not enough AP"); return end
  if not spendAP(c, 1) then warn(c..": JOB: spendAP failed"); return end
  moneyAdd(c, 50)
  log(c..": JOB: paid 1 AP->EVENT, +50 MONEY")
end

-- pay 300/year once, then 3 AP -> +2 SKILL
function actionTechAcademy(_, playerColor)
  local c = getActorColor()
  if not c then return end

  if not paidTechThisYear[c] then
    if not moneyAdd(c, -300) then
      log(c..": TECH-ACAD blocked: not enough money to pay 300/year")
      return
    end
    paidTechThisYear[c] = true
    log(c..": TECH-ACAD: paid 300/year (locked for this year)")
  end

  if not canSpendAP(c, 3) then log(c..": TECH-ACAD blocked: not enough AP"); return end
  if not spendAP(c, 3) then warn(c..": TECH-ACAD: spendAP failed"); return end
  addSkill(c, 2)
  log(c..": TECH-ACAD: paid 3 AP->EVENT, +2 SKILL")
end

-- pay 300/year once, then 3 AP -> +2 KNOWLEDGE
function actionUniversity(_, playerColor)
  local c = getActorColor()
  if not c then return end

  if not paidUniThisYear[c] then
    if not moneyAdd(c, -300) then
      log(c..": UNI blocked: not enough money to pay 300/year")
      return
    end
    paidUniThisYear[c] = true
    log(c..": UNI: paid 300/year (locked for this year)")
  end

  if not canSpendAP(c, 3) then log(c..": UNI blocked: not enough AP"); return end
  if not spendAP(c, 3) then warn(c..": UNI: spendAP failed"); return end
  addKnowledge(c, 2)
  log(c..": UNI: paid 3 AP->EVENT, +2 KNOWLEDGE")
end

-- =========================================================
-- [SECTION 9] UI / LIFECYCLE
-- =========================================================
function onLoad()
  self.clearButtons()

  local y = 0.2
  local z = -1.3
  local w = 520
  local h = 180
  local fs = 90

  local buttons = {
    { label="VOC-SCH",   fn="actionVocSchool",   x=-2.2 },
    { label="TECH-ACAD", fn="actionTechAcademy", x=-1.1 },
    { label="JOB",       fn="actionJob",         x=0.0  },
    { label="HI-SCH",    fn="actionHighSchool",  x=1.1  },
    { label="UNI",       fn="actionUniversity",  x=2.2  },
  }

  for _, b in ipairs(buttons) do
    self.createButton({
      label = b.label,
      click_function = b.fn,
      function_owner = self,
      position = { b.x, y, z },
      width = w,
      height = h,
      font_size = fs
    })
  end

  log("Loaded v1.3 (ACTIVE TURN COLOR ONLY via Turns.turn_color)")
end
