-- =========================================
-- WLB PLAYER BOARD CONTROLLER (REST + WORK) v0.1.0
--
-- Goal:
--  - Replace small separate controllers (Rest/Work) with ONE script on the Player Board.
--  - Provide buttons:
--      REST:  [+]  [REST]  [-]
--      WORK:  [+]  [WORK]  [-]
--  - REST uses AP Controller area "REST" and shows a simple forecast (like RestButton_Shared).
--  - WORK uses AP Controller area "W" and adds salary as NEGATIVE cost in CostsCalculator.
--    Player can undo (WORK -) until PAY; after PAY, WORK is locked for the rest of the turn.
--
-- Required tags:
--  - Player board object: `WLB_BOARD` + `WLB_COLOR_<Color>`
--  - AP Controller:       `WLB_AP_CTRL` + `WLB_COLOR_<Color>`
--  - Stats Controller:    `WLB_STATS_CTRL` + `WLB_COLOR_<Color>` (for REST forecast)
--  - Costs Calculator:    `WLB_COSTS_CALC` (single shared object)
--  - Vocations Controller:`WLB_VOCATIONS_CTRL` (single shared object)
--  - Shop Engine:         `WLB_SHOP_ENGINE` (optional, for REST-equivalent bonus)
--
-- Notes:
--  - WORK lock is UI-level: prevents using these +/- after PAY.
--    (If someone uses the AP Controller UI directly, they could still move tokens.)
-- =========================================

local TAG_AP_CTRL      = "WLB_AP_CTRL"
local TAG_STATS_CTRL   = "WLB_STATS_CTRL"
local TAG_SHOP_ENGINE  = "WLB_SHOP_ENGINE"
local TAG_COSTS_CALC   = "WLB_COSTS_CALC"
local TAG_VOCATIONS    = "WLB_VOCATIONS_CTRL"
local TAG_COLOR_PREFIX = "WLB_COLOR_"

-- Round token GUID used as "active player" source (same as CostsCalculator)
local ROUND_TOKEN_GUID = "465776"

-- AP areas
local AREA_WORK = "W"
local AREA_REST = "REST"
local AREA_SCHOOL = "SC"

-- Health bounds (for forecast)
local MIN_HEALTH = 0
local MAX_HEALTH = 9

--
-- You said the board already has REST/WORK labels printed, so we draw ONLY:
--  - REST + / REST -
--  - WORK + / WORK -
--
-- If later you want perfect alignment, you can tweak these numbers in TTS and paste back.
local POS = {
  -- Left pair (closer together): use for REST
  rest_plus  = {x=-3.9, y=0.592, z=3.45},
  rest_minus = {x=-2.3, y=0.592, z=3.45},
  -- Right pair: use for WORK
  work_plus  = {x=-6.9, y=0.592, z=3.45},
  work_minus = {x=-5.3, y=0.657, z=3.45},
  -- SCHOOL / LEARNING (right side of REST, same row)
  school_free = {x= 2.3, y=0.592, z=3.45},
  school_paid = {x= 4.5, y=0.592, z=3.45},
}

-- Money display (LOCAL to player board)
-- Requested:
--  - "MONEY:" at x=-7,   z=-7
--  - value at  x=-7.5, z=-5.5
-- Y not provided; we use 0.592 (board surface height used elsewhere).
local MONEY_POS = {
  label = {x=6.8, y=0.592, z=-7.0},
  value = {x=6.8, y=0.592, z=-6.0},
}

-- Button sizes
local W_BTN  = 450
local H_BTN  = 350
local FS_BTN = 190

-- Money button sizes (narrower; two-line layout uses two separate buttons)
local W_MONEY  = 1100
local H_MONEY  = 420
local FS_MONEY = 250

local COL_PLUS  = {0.15, 0.70, 0.20, 0.98}
local COL_MINUS = {0.85, 0.20, 0.20, 0.98}
local COL_LOCK  = {0.35, 0.35, 0.35, 0.98}
local COL_SCHOOL_FREE = {0.25, 0.55, 0.95, 0.98}
local COL_SCHOOL_PAID = {0.55, 0.25, 0.85, 0.98}
local COL_TXT   = {1,1,1,1}
local COL_MONEY_BG = {0.95, 0.95, 0.95, 0.98}
local COL_MONEY_FG = {0.05, 0.05, 0.05, 1}

-- state (persisted)
local START_MONEY = 200
local S = {
  -- After PAY we "lock" only the already-paid work AP:
  -- player can still add more WORK AP, but cannot remove below paidWorkCount.
  paidWorkCount = 0,
  money = START_MONEY,
  -- transient UI state
  schoolPending = nil, -- "FREE" | "PAID" | nil
}

-- =========================================
-- HELPERS
-- =========================================
local DEBUG = true
local function log(msg) if DEBUG then print("[PB CTRL] "..tostring(msg)) end end

local function clampInt(x)
  x = tonumber(x) or 0
  if x >= 0 then return math.floor(x + 0.00001) end
  return math.ceil(x - 0.00001)
end

local function readAmount(params)
  if type(params) == "table" then
    if params.amount ~= nil then return clampInt(params.amount) end
    if params.delta  ~= nil then return clampInt(params.delta)  end
    return 0
  end
  return clampInt(params)
end

local function clamp(v, a, b)
  v = tonumber(v) or 0
  if v < a then return a end
  if v > b then return b end
  return v
end

local function getRoundToken()
  if not ROUND_TOKEN_GUID or ROUND_TOKEN_GUID == "" then return nil end
  return getObjectFromGUID(ROUND_TOKEN_GUID)
end

-- Current round (1-13). Used to hide school buttons during Youth (rounds 1-5); show from round 6 (Adult) or when game started in Adult.
local function getCurrentRound()
  local rt = getRoundToken()
  if rt and rt.call then
    local ok, r = pcall(function() return rt.call("getRound") end)
    if ok and type(r) == "number" then return math.floor(r) end
  end
  return 1
end

local function isSchoolPeriodActive()
  return getCurrentRound() >= 6
end

local function isPlayableColor(c)
  return c=="Yellow" or c=="Blue" or c=="Red" or c=="Green"
end

local function getActiveColor()
  local rt = getRoundToken()
  if rt and rt.call then
    local ok, c = pcall(function() return rt.call("getColor") end)
    if ok and isPlayableColor(c) then return c end
  end
  local tc = Turns and Turns.turn_color or nil
  if isPlayableColor(tc) then return tc end
  return nil
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

local function colorFromTag(ctag)
  if not ctag then return nil end
  local prefixLen = #TAG_COLOR_PREFIX
  if string.sub(ctag, 1, prefixLen) == TAG_COLOR_PREFIX then
    return string.sub(ctag, prefixLen + 1)
  end
  return nil
end

local function getMyColor()
  return colorFromTag(getColorTagFromSelf())
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
    log("Missing color tag on Player Board (e.g., WLB_COLOR_Yellow).")
    return nil
  end
  local ap = findByTags(TAG_AP_CTRL, ctag)
  if not ap then
    log("AP Controller not found for "..tostring(ctag).." (need tags WLB_AP_CTRL + "..tostring(ctag)..")")
  end
  return ap
end

local function findStatsCtrlForMyColor()
  local ctag = getColorTagFromSelf()
  if not ctag then return nil end
  return findByTags(TAG_STATS_CTRL, ctag)
end

local function findShopEngine()
  local list = getObjectsWithTag(TAG_SHOP_ENGINE) or {}
  if #list > 0 and list[1] and list[1].call then return list[1] end
  return nil
end

local function findCostsCalculator()
  local list = getObjectsWithTag(TAG_COSTS_CALC) or {}
  if #list > 0 and list[1] and list[1].call then return list[1] end
  return nil
end

local function findVocationsController()
  local list = getObjectsWithTag(TAG_VOCATIONS) or {}
  if #list > 0 and list[1] and list[1].call then return list[1] end
  return nil
end

local function apGetCount(ap, area)
  if not ap or not ap.call then return 0 end
  local candidates = {
    function() return ap.call("getCount", {area=area}) end,
    function() return ap.call("getCount", {field=area}) end,
    function() return ap.call("getCount", {to=area}) end,
    function() return ap.call("countArea", {area=area}) end,
  }
  for _, fn in ipairs(candidates) do
    local ok, res = pcall(fn)
    if ok and type(res) == "number" then
      return math.max(0, math.floor(res))
    end
  end
  return 0
end

local function apCanSpend(ap, toArea, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  if not ap or not ap.call then return false end
  local ok, can = pcall(function()
    return ap.call("canSpendAP", {to=toArea, amount=amount})
  end)
  return ok and can == true
end

local function apMove(ap, toArea, amount)
  if not ap or not ap.call then return {ok=false, moved=0, requested=amount, reason="no_ap_ctrl"} end
  local ok, ret = pcall(function()
    return ap.call("moveAP", {to=toArea, amount=amount})
  end)
  if not ok or type(ret) ~= "table" then
    return {ok=false, moved=0, requested=amount, reason="move_failed"}
  end
  return ret
end

local function statsApplyDelta(delta)
  local st = findStatsCtrlForMyColor()
  if not st or not st.call then return false end
  local ok = pcall(function() st.call("applyDelta", delta) end)
  return ok == true
end

local function statsGetHealthNow()
  local st = findStatsCtrlForMyColor()
  if not st or not st.call then return MAX_HEALTH end
  local ok, res = pcall(function() return st.call("getState") end)
  if ok and type(res) == "table" then
    if type(res.h) == "number" then return math.floor(res.h) end
    if type(res.health) == "number" then return math.floor(res.health) end
  end
  local ok2, v = pcall(function() return st.call("getHealth") end)
  if ok2 and type(v) == "number" then return math.floor(v) end
  return MAX_HEALTH
end

local function getRestEquivalentBonus(color)
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

local function getSalaryPerAP(color)
  local voc = findVocationsController()
  if not voc then return 0 end
  local ok, sal = pcall(function()
    return voc.call("VOC_GetSalary", {color=color})
  end)
  if ok and type(sal) == "number" then
    return math.max(0, math.floor(sal))
  end
  return 0
end

local function costsAdd(color, delta, bucket)
  local calc = findCostsCalculator()
  if not calc then
    log("CostsCalculator not found (need tag WLB_COSTS_CALC).")
    broadcastToAll("⛔ CostsCalculator not found (missing tag WLB_COSTS_CALC). Salary/costs won't update.", {1,0.4,0.4})
    return false
  end
  local ok, err = pcall(function()
    local payload = {color=color, amount=delta}
    if bucket ~= nil then payload.bucket = bucket end
    return calc.call("addCost", payload)
  end)
  if not ok then
    log("CostsCalculator.addCost failed: "..tostring(err))
    broadcastToAll("⛔ CostsCalculator.addCost failed (see console).", {1,0.4,0.4})
    return false
  end
  -- Force UI refresh (defensive: ensures label updates immediately even if something else is off)
  pcall(function() calc.call("rebuildUI") end)
  return ok
end

-- =========================================
-- REST
-- =========================================
local function showRestForecast(ap, restCountOverride)
  local color = getMyColor() or ""
  local rest = restCountOverride
  if rest == nil then
    rest = apGetCount(ap, AREA_REST)
  end
  local restBonus = getRestEquivalentBonus(color)
  local effectiveRest = rest + restBonus
  local hNow = statsGetHealthNow()
  local deltaH = effectiveRest - 4
  local hAfter = clamp(hNow + deltaH, MIN_HEALTH, MAX_HEALTH)
  local sign = (deltaH >= 0) and ("+"..deltaH) or tostring(deltaH)

  local bonusText = ""
  if restBonus > 0 then
    bonusText = " | bonus +"..tostring(restBonus).." (eff "..tostring(effectiveRest)..")"
  end
  broadcastToAll("🛏️ "..tostring(color)..": REST="..tostring(rest)..bonusText.." | ΔH="..sign.." | H "..tostring(hNow).."→"..tostring(hAfter), {0.85, 0.95, 1})
end

local function doRestMove(amount)
  local ap = findApCtrlForMyColor()
  if not ap then return end
  local before = apGetCount(ap, AREA_REST)
  local ok, ret = pcall(function()
    return ap.call("moveAP", {to=AREA_REST, amount=amount})
  end)
  if not ok or type(ret) ~= "table" or ret.ok ~= true then
    showRestForecast(ap)
    return
  end
  local moved = tonumber(ret.moved or 0) or 0
  if moved ~= 1 then
    showRestForecast(ap, before)
    return
  end
  local after = before + amount
  if after < 0 then after = 0 end
  showRestForecast(ap, after)
end

-- =========================================
-- WORK
-- =========================================
local function doWorkMove(amount)
  local color = getMyColor()
  if not color then
    log("Cannot resolve color (missing WLB_COLOR_* tag).")
    return
  end

  local salary = getSalaryPerAP(color)
  if salary <= 0 then
    broadcastToAll("⚠️ "..color..": Salary not available (choose a vocation first).", {1,0.8,0.2})
    return
  end

  local ap = findApCtrlForMyColor()
  if not ap then return end

  local before = apGetCount(ap, AREA_WORK)

  -- If removing, allow only "unpaid" work AP (above paidWorkCount)
  local paid = math.max(0, math.floor(tonumber(S.paidWorkCount or 0) or 0))
  if amount < 0 and before <= paid then
    broadcastToAll("⛔ "..color..": This WORK AP is already paid/locked. You can only remove unpaid WORK.", {1,0.6,0.2})
    redraw()
    return
  end

  local ok, ret = pcall(function()
    return ap.call("moveAP", {to=AREA_WORK, amount=amount})
  end)
  if not ok or type(ret) ~= "table" or ret.ok ~= true then
    redraw()
    return
  end
  local moved = tonumber(ret.moved or 0) or 0
  if moved ~= 1 then
    redraw()
    return
  end

  -- Salary goes to CostsCalculator as negative cost (earnings)
  -- IMPORTANT: Undo should undo earnings (not create costs).
  -- So we adjust the earnings bucket directly: +salary on add, -salary on undo.
  local deltaE = (amount > 0) and (salary) or (-salary)
  costsAdd(color, deltaE, "earnings")

  local after = before + amount
  if after < 0 then after = 0 end
  if amount > 0 then
    broadcastToAll("💼 "..color..": +1 WORK ("..tostring(after)..") → +"..tostring(salary).." WIN (pending)", {0.7,0.95,1})
  else
    broadcastToAll("💼 "..color..": -1 WORK ("..tostring(after)..") → -"..tostring(salary).." WIN (undo)", {0.9,0.9,0.95})
  end

  redraw()
end

-- =========================================
-- SCHOOL / LEARNING (FREE / PAID)
-- =========================================
local SCHOOL_AP_COST = 3
local SCHOOL_PAID_COST = 400

local function doSchoolBegin(mode)
  if mode ~= "FREE" and mode ~= "PAID" then return end
  S.schoolPending = mode
  redraw()
end

local function doSchoolCancel()
  S.schoolPending = nil
  redraw()
end

local function doSchoolResolve(choice)
  local color = getMyColor()
  if not color then return end

  local ap = findApCtrlForMyColor()
  if not ap then return end

  local mode = S.schoolPending
  if mode ~= "FREE" and mode ~= "PAID" then
    -- No pending selection; ignore.
    return
  end

  local paid = (mode == "PAID")
  local moneyCost = paid and SCHOOL_PAID_COST or 0

  -- Choice mapping:
  -- FREE: +1 Knowledge OR +1 Skill
  -- PAID: +2 Knowledge OR +2 Skill
  local dk, ds = 0, 0
  if choice == "K" then
    dk = paid and 2 or 1
  elseif choice == "S" then
    ds = paid and 2 or 1
  else
    return
  end

  -- Pre-check money
  if moneyCost > 0 and getMoney() < moneyCost then
    broadcastToAll("⛔ "..color..": Not enough money for PAID school ("..tostring(moneyCost).." WIN).", {1,0.6,0.2})
    return
  end

  -- Pre-check AP
  if not apCanSpend(ap, AREA_SCHOOL, SCHOOL_AP_COST) then
    broadcastToAll("⛔ "..color..": Not enough free AP for school ("..tostring(SCHOOL_AP_COST).." AP).", {1,0.6,0.2})
    return
  end

  -- Move AP to SCHOOL
  local ret = apMove(ap, AREA_SCHOOL, SCHOOL_AP_COST)
  local moved = tonumber(ret.moved or 0) or 0
  if ret.ok ~= true or moved ~= SCHOOL_AP_COST then
    -- Best-effort rollback if partial move happened
    if moved > 0 then
      pcall(function() ap.call("moveAP", {to=AREA_SCHOOL, amount=-moved}) end)
    end
    broadcastToAll("⛔ "..color..": Failed to place AP on SCHOOL (moved "..tostring(moved).."/"..tostring(SCHOOL_AP_COST)..").", {1,0.6,0.2})
    return
  end

  -- Pay money (PAID)
  if moneyCost > 0 then
    addMoney({delta = -moneyCost})
  end

  -- Apply stats
  local okStats = statsApplyDelta({k=dk, s=ds})
  if not okStats then
    broadcastToAll("⚠️ "..color..": School completed, but failed to apply stats (check STATS CTRL).", {1,0.8,0.3})
  end

  local rewardText = (dk > 0) and ("+"..tostring(dk).." KNOWLEDGE") or ("+"..tostring(ds).." SKILL")
  if paid then
    broadcastToAll("🎓 "..color..": PAID school (-"..tostring(moneyCost).." WIN, -"..tostring(SCHOOL_AP_COST).." AP) → "..rewardText, {0.75,0.9,1})
  else
    broadcastToAll("🎓 "..color..": FREE school (-"..tostring(SCHOOL_AP_COST).." AP) → "..rewardText, {0.75,0.9,1})
  end

  S.schoolPending = nil
  redraw()
end

-- Called by CostsCalculator after PAY resolves for a color (locks WORK for rest of turn)
function WORK_OnPaid(params)
  local my = getMyColor()
  local c = params and (params.color or params.playerColor) or nil
  if not my or not c or my ~= c then return end

  local ap = findApCtrlForMyColor()
  local wCount = apGetCount(ap, AREA_WORK)
  -- After PAY: everything currently on WORK is considered paid/locked.
  S.paidWorkCount = math.max(0, math.floor(tonumber(wCount) or 0))
  if S.paidWorkCount > 0 then
    broadcastToAll("🔒 "..my..": Locked "..tostring(S.paidWorkCount).." paid WORK AP. You can still add more WORK.", {0.7,1,0.7})
  end
  redraw()
end

-- =========================================
-- UI
-- =========================================
function noop() end

function redraw()
  self.clearButtons()

  -- REST buttons
  self.createButton({
    click_function = "rest_plus",
    function_owner = self,
    label          = "+",
    position       = {POS.rest_plus.x, POS.rest_plus.y, POS.rest_plus.z},
    width          = W_BTN,
    height         = H_BTN,
    font_size      = FS_BTN,
    color          = COL_PLUS,
    font_color     = COL_TXT,
    tooltip        = "REST +1"
  })
  self.createButton({
    click_function = "rest_minus",
    function_owner = self,
    label          = "−",
    position       = {POS.rest_minus.x, POS.rest_minus.y, POS.rest_minus.z},
    width          = W_BTN,
    height         = H_BTN,
    font_size      = FS_BTN,
    color          = COL_MINUS,
    font_color     = COL_TXT,
    tooltip        = "REST -1"
  })

  -- WORK buttons:
  --  - PLUS is always allowed (if AP controller allows it)
  --  - MINUS is allowed only if there is unpaid WORK AP above paidWorkCount
  local ap = findApCtrlForMyColor()
  local workNow = apGetCount(ap, AREA_WORK)
  local paid = math.max(0, math.floor(tonumber(S.paidWorkCount or 0) or 0))
  local canRemoveUnpaid = (workNow > paid)

  local workPlusCol = COL_PLUS
  local workMinusCol = canRemoveUnpaid and COL_MINUS or COL_LOCK
  local workPlusTip = "WORK +1"
  local workMinusTip = canRemoveUnpaid and "WORK -1 (undo unpaid)" or "LOCKED (paid WORK)"

  self.createButton({
    click_function = "work_plus",
    function_owner = self,
    label          = "+",
    position       = {POS.work_plus.x, POS.work_plus.y, POS.work_plus.z},
    width          = W_BTN,
    height         = H_BTN,
    font_size      = FS_BTN,
    color          = workPlusCol,
    font_color     = COL_TXT,
    tooltip        = workPlusTip
  })
  self.createButton({
    click_function = "work_minus",
    function_owner = self,
    label          = "−",
    position       = {POS.work_minus.x, POS.work_minus.y, POS.work_minus.z},
    width          = W_BTN,
    height         = H_BTN,
    font_size      = FS_BTN,
    color          = workMinusCol,
    font_color     = COL_TXT,
    tooltip        = workMinusTip
  })

  -- SCHOOL buttons (FREE / PAID) + follow-up choice menu — only in Adult period (round 6+); hidden during Youth (rounds 1-5)
  if isSchoolPeriodActive() then
    if S.schoolPending == "FREE" or S.schoolPending == "PAID" then
      local paid = (S.schoolPending == "PAID")
      local hdr = paid and "PAID: choose reward" or "FREE: choose reward"
      local costLine = paid and ("-400 WIN, -3 AP") or ("-3 AP")

      -- small header label (non-clickable)
      self.createButton({
        click_function = "noop",
        function_owner = self,
        label          = "SCHOOL\n"..hdr.."\n"..costLine,
        position       = {((POS.school_free.x + POS.school_paid.x) / 2), POS.school_free.y, (POS.school_free.z - 1.05)},
        width          = 1800,
        height         = 520,
        font_size      = 130,
        color          = {0.95, 0.95, 0.95, 0.95},
        font_color     = {0.05, 0.05, 0.05, 1},
        tooltip        = ""
      })

      self.createButton({
        click_function = "school_choose_k",
        function_owner = self,
        label          = "KNOWLEDGE",
        position       = {POS.school_free.x, POS.school_free.y, POS.school_free.z},
        width          = 1100,
        height         = H_BTN,
        font_size      = 150,
        color          = COL_SCHOOL_FREE,
        font_color     = COL_TXT,
        tooltip        = paid and "+2 KNOWLEDGE" or "+1 KNOWLEDGE"
      })

      self.createButton({
        click_function = "school_choose_s",
        function_owner = self,
        label          = "SKILL",
        position       = {POS.school_paid.x, POS.school_paid.y, POS.school_paid.z},
        width          = 1100,
        height         = H_BTN,
        font_size      = 170,
        color          = COL_SCHOOL_PAID,
        font_color     = COL_TXT,
        tooltip        = paid and "+2 SKILL" or "+1 SKILL"
      })

      self.createButton({
        click_function = "school_cancel",
        function_owner = self,
        label          = "CANCEL",
        position       = {((POS.school_free.x + POS.school_paid.x) / 2), POS.school_free.y, (POS.school_free.z - 2.05)},
        width          = 1400,
        height         = 320,
        font_size      = 140,
        color          = COL_LOCK,
        font_color     = COL_TXT,
        tooltip        = "Back"
      })
    else
      self.createButton({
        click_function = "school_free",
        function_owner = self,
        label          = "FREE",
        position       = {POS.school_free.x, POS.school_free.y, POS.school_free.z},
        width          = 500,
        height         = H_BTN,
        font_size      = 170,
        color          = COL_SCHOOL_FREE,
        font_color     = COL_TXT,
        tooltip        = "SCHOOL (FREE)\nUses 3 AP\nThen choose: Knowledge or Skill"
      })
      self.createButton({
        click_function = "school_paid",
        function_owner = self,
        label          = "PAID",
        position       = {POS.school_paid.x, POS.school_paid.y, POS.school_paid.z},
        width          = 500,
        height         = H_BTN,
        font_size      = 170,
        color          = COL_SCHOOL_PAID,
        font_color     = COL_TXT,
        tooltip        = "SCHOOL (PAID)\nUses 3 AP + 400 WIN\nThen choose: +2 Knowledge or +2 Skill"
      })
    end
  end

  -- MONEY display (2 lines, separate buttons; non-clickable)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = "MONEY:",
    position       = {MONEY_POS.label.x, MONEY_POS.label.y, MONEY_POS.label.z},
    width          = W_MONEY,
    height         = H_MONEY,
    font_size      = FS_MONEY,
    color          = COL_MONEY_BG,
    font_color     = COL_MONEY_FG,
    tooltip        = ""
  })

  self.createButton({
    click_function = "noop",
    function_owner = self,
    label          = tostring(S.money or 0),
    position       = {MONEY_POS.value.x, MONEY_POS.value.y, MONEY_POS.value.z},
    width          = W_MONEY,
    height         = H_MONEY,
    font_size      = FS_MONEY,
    color          = COL_MONEY_BG,
    font_color     = COL_MONEY_FG,
    tooltip        = ""
  })
end

function rest_plus(_, player_color, alt_click) doRestMove(1); redraw() end
function rest_minus(_, player_color, alt_click) doRestMove(-1); redraw() end

function work_plus(_, player_color, alt_click) doWorkMove(1) end
function work_minus(_, player_color, alt_click) doWorkMove(-1) end

function school_free(_, player_color, alt_click) doSchoolBegin("FREE") end
function school_paid(_, player_color, alt_click) doSchoolBegin("PAID") end

function school_choose_k(_, player_color, alt_click) doSchoolResolve("K") end
function school_choose_s(_, player_color, alt_click) doSchoolResolve("S") end
function school_cancel(_, player_color, alt_click) doSchoolCancel() end

-- Unlock WORK when it's not our turn anymore (simple per-turn lock behavior)
-- School buttons at round 6: TurnController notifies boards via rebuildUI() when round changes (event-driven).
local function tick()
  local my = getMyColor()
  local active = getActiveColor()
  -- When it's no longer our turn, clear paid-work lock for next time.
  if my and active and my ~= active and (tonumber(S.paidWorkCount or 0) or 0) ~= 0 then
    S.paidWorkCount = 0
    redraw()
  end
  Wait.time(tick, 0.5)
end

function onSave()
  return JSON.encode(S)
end

-- =========================================
-- MONEY API (replaces separate MoneyController tile)
-- Compatible with MoneyController_Shared public API
-- =========================================
function getMoney()
  return clampInt(S.money or 0)
end

function setMoney(params)
  local v = readAmount(params)
  S.money = clampInt(v)
  redraw()
  return S.money
end

function addMoney(params)
  local delta = readAmount(params)
  S.money = clampInt((S.money or 0) + delta)
  redraw()
  return S.money
end

function resetNewGame()
  -- Reset money and board-local locks for a new game
  S.money = START_MONEY
  S.paidWorkCount = 0
  S.schoolPending = nil
  redraw()
  return S.money
end

function rebuildUI()
  redraw()
end

-- SAFE spend API (for ShopEngine etc.)
function API_spend(params)
  local amount = 0
  if type(params) == "table" then
    amount = params.amount or params.delta or 0
  else
    amount = params or 0
  end
  amount = clampInt(amount)
  if amount <= 0 then
    return {ok=true, spent=0, requested=amount, money=getMoney()}
  end
  if getMoney() < amount then
    return {ok=false, spent=0, requested=amount, reason="insufficient_funds", money=getMoney()}
  end
  addMoney({delta = -amount})
  return {ok=true, spent=amount, requested=amount, money=getMoney()}
end

function onLoad(saved)
  -- Always draw immediately (if this doesn't run, you will see no buttons at all)
  -- so this is the best first debug step.
  local okLoad, errLoad = pcall(function()
    if saved and saved ~= "" then
      local ok, data = pcall(function() return JSON.decode(saved) end)
      if ok and type(data) == "table" then
        S.paidWorkCount = tonumber(data.paidWorkCount or 0) or 0
        if data.money ~= nil then
          S.money = clampInt(data.money)
        else
          S.money = START_MONEY
        end
        -- Do not persist transient menus across reload
        S.schoolPending = nil
      end
    end
    if S.money == nil then S.money = START_MONEY end

    redraw()

    -- Start the watcher if Wait exists
    if Wait and Wait.time then
      Wait.time(tick, 0.5)
    end

    log("Loaded on "..tostring(self.getName and self.getName() or "board").." GUID="..tostring(self.getGUID and self.getGUID() or "?").." colorTag="..tostring(getColorTagFromSelf()))
  end)

  if not okLoad then
    print("[PB CTRL][ERR] onLoad failed: "..tostring(errLoad))
    -- As a last resort: try to show a single big button so user sees *something*.
    pcall(function()
      self.clearButtons()
      self.createButton({
        click_function = "noop",
        function_owner = self,
        label          = "PB CTRL ERROR\n(check console)",
        position       = {0, 0.25, 0},
        width          = 3200,
        height         = 900,
        font_size      = 260,
        color          = {0.9, 0.2, 0.2, 0.95},
        font_color     = {1,1,1,1},
      })
    end)
  end
end

