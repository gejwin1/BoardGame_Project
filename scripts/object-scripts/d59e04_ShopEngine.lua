-- =========================================================
-- WLB SHOP ENGINE v1.4.0 (FULL REWRITE)
-- =========================================================

-- =========================================================
-- API CONTRACTS (External Dependencies)
-- =========================================================
-- ShopEngine REQUIRES from other systems:
--   MoneyCtrl: addMoney({delta=...}), getMoney() or getValue() or getState().money
--   TurnController: getActiveTurnColor() or Turns.turn_color (active player)
--   CostsCalc: addCost({color=..., amount=...}) [UNIFIED: always use addCost, never setCost]
--   MarketCtrl: API_deliverEstateInvest({color=..., level=...}) [if implemented]
--   PlayerStatusController: PS_Event({color=..., op="ADD_STATUS"/"REMOVE_STATUS", ...})
--   StatsController: statsApply({color=..., k=..., s=..., h=...})
--   APController: canSpendAP({amount=..., to=...}), spendAP({amount=..., to=...})
--
-- ShopEngine EXPORTS (Public API):
--   API_reset(), API_refill(), API_randomize()
--   API_getRestEquivalent(color), API_clearRestEquivalent(color)
--   API_ownsHiTech({color=..., kind=...}), API_getOwnedHiTech({color=...})
--   API_processInvestmentPayments({color=...})
--   API_processEndOfGameLoans({color=...})
-- =========================================================

-- NEW v1.4.0:
--  - Hi-Tech cards (HSHOP) fully implemented: purchase, ownership tracking, state persistence
--  - COFFEE: Permanent rest-equivalent bonus (+1 per card, tracked separately from consumable bonus)
--  - CAR: Shop entry free (Estate entry free + Event cards -1 AP: TODO - needs Event/Estate Engine integration)
--  - Hi-Tech card placement: Cards placed near player boards using LOCAL coordinates (needs calibration via Scanner tool)
--    Cards stack vertically as more are purchased to keep table organized
-- NEW v1.3.6:
--  - Manual die rolling: dice-requiring cards (PILLS, CURE, FAMILY, NATURE_TRIP) show "ROLL DICE" button
--  - Player manually rolls physical die, then clicks button to read result
-- NEW v1.3.5:
--  - rest-equivalent bonus tracking (PILLS/NATURE_TRIP cards add +3 bonus)
--  - API_getRestEquivalent(color) for REST Button and Turn Controller
--
-- TODO - Effects needing integration with other systems:
--  - COMPUTER/DEVICE/TV: Interactive cards (need click handlers on card objects)
--  - BABYMONITOR: Reduce child AP blocking (needs PlayerStatusController integration)
--  - HMONITOR: SICK protection (needs Event/PlayerStatusController integration)
--  - ALARM: Theft protection (needs Event Engine integration)
--  - SMARTWATCH: Start-of-turn -1 INACTIVE AP (needs Turn Controller integration)
--  - SMARTPHONE: End-of-turn Work/Learning check (needs Turn Controller integration)
--  - CAR: Estate entry free + Event cards -1 AP (needs Estate/Event Engine integration)
-- =========================================================

local DEBUG   = true
local VERSION = "1.4.0"

-- =========================
-- [S1] TAGS / CONFIG
-- =========================
local TAG_SHOPS_BOARD = "WLB_SHOP_BOARD"
local TAG_SHOP_CARD   = "WLB_SHOP_CARD"

local TAG_SHOP_DECK   = "WLB_SHOP_DECK"
local TAG_DECK_C      = "WLB_DECK_CSHOP"
local TAG_DECK_H      = "WLB_DECK_HSHOP"
local TAG_DECK_I      = "WLB_DECK_ISHOP"

-- controllers
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"
local TAG_STATS              = "WLB_STATS_CTRL"
local TAG_MONEY              = "WLB_MONEY"
local TAG_AP_CTRL            = "WLB_AP_CTRL"
local TAG_PLAYER_BOARD       = "WLB_BOARD"
local TAG_COSTS_CALC         = "WLB_COSTS_CALC"
local TAG_VOCATIONS_CTRL     = "WLB_VOCATIONS_CTRL"

local TAG_COLOR_PREFIX = "WLB_COLOR_"

-- statuses
local TAG_STATUS_SICK       = "WLB_STATUS_SICK"
local TAG_STATUS_WOUNDED    = "WLB_STATUS_WOUNDED"
local TAG_STATUS_GOOD_KARMA = "WLB_STATUS_GOOD_KARMA"
local TAG_STATUS_ADDICTION  = "WLB_STATUS_ADDICTION"
local TAG_STATUS_VOUCH_C    = "WLB_STATUS_VOUCH_C"
local TAG_STATUS_VOUCH_H    = "WLB_STATUS_VOUCH_H"
-- Consumables / Hi-Tech: up to 100% discount (4 tokens × 25%). Hi-Tech rarely exceeds 50% in practice (few vouchers in game).
-- Estate/properties: max 40% (only 2 property vouchers exist) — capped in EstateEngine.

-- Name prefixes (authoritative)
local PAT_C = "^CSHOP_%d%d_"
local PAT_H = "^HSHOP_%d%d_"
local PAT_I = "^ISHOP_%d%d_"

-- Timing
local STEP_DELAY  = 1.50
local SHORT_DELAY = 0.20
local DEAL_Y      = 0.35
local LOCK_TIME   = 0.25

-- Geometry eps
local EPS_SLOT    = 1.05
local EPS_COLLECT = 2.20

-- Expected totals (debug only)
local EXPECT_C = 28
local EXPECT_H = 14
local EXPECT_I = 14

-- Die
local DIE_GUID = "14d4a4"

-- =========================
-- [S1B] SLOT MATRIX (LOCAL@SHOPS_BOARD)
-- =========================
local SLOTS_LOCAL = {
  C = {
    closed = {x=6.389, y=0.592, z=-4.988},
    open   = {
      {x=4.221, y=0.592, z=-4.831},
      {x=2.186, y=0.592, z=-4.796},
      {x=0.196, y=0.592, z=-4.840},
    }
  },
  H = {
    closed = {x=6.389, y=0.592, z= 0.039},
    open   = {
      {x=4.221, y=0.592, z= 0.196},
      {x=2.186, y=0.592, z= 0.231},
      {x=0.196, y=0.592, z= 0.187},
    }
  },
  I = {
    closed = {x=6.367, y=0.592, z= 5.065},
    open   = {
      {x=4.221, y=0.592, z= 5.222},
      {x=2.186, y=0.592, z= 5.257},
      {x=0.196, y=0.592, z= 5.213},
    }
  }
}

-- =========================
-- [S1C] USED CARDS STORAGE (LOCAL@SHOPS_BOARD)
-- =========================
-- Used CONSUMABLES (C) and one-off INVESTMENTS (I) should NOT go back on top of the deck.
-- Instead, we place them in a "used row" outside the shop board area.
--
-- User request: local X = 10.5 and "one row".
-- Interpretation: we start at x=10.5 and extend along +X.
local TAG_SHOP_USED   = "WLB_SHOP_USED"
local TAG_SHOP_USED_C = "WLB_SHOP_USED_C"
local TAG_SHOP_USED_I = "WLB_SHOP_USED_I"

-- Keep used cards in the SAME Z-row as their shop row:
--  - Consumables row (C) is around z≈-4.83
--  - Investments row (I) is around z≈ 5.22
-- (High-Tech row is around z≈0.20, so we avoid mixing by z.)
local USED_ROW_LOCAL_BY_ROW = {
  C = { x=10.5, y=0.592, z=-4.83 },
  I = { x=10.5, y=0.592, z= 5.22 },
}
local USED_ROW_DX = 1.40
local USED_ROW_Y_LIFT = 0.20

-- =========================
-- [S2] STATE
-- =========================
local S = {
  board      = nil,
  desiredYaw = nil,
  jobId      = 0,
  busy       = false,

  lastTurnColor = "",
  boughtThisTurn = {}, -- [Color]=true if already paid 1AP entry this turn
  restEquivalent = { Yellow=0, Blue=0, Red=0, Green=0 }, -- [Color]=bonus (rest-equivalent from PILLS/NATURE_TRIP, resets each turn)
  pillsUseCount = { Yellow=0, Blue=0, Red=0, Green=0 }, -- [Color]=number of PILLS used (for addiction risk calculation)
  
  -- Hi-Tech ownership: [Color] = {cardName1, cardName2, ...} - permanent items owned by player
  ownedHiTech = { Yellow={}, Blue={}, Red={}, Green={} },
  
  -- Permanent rest-equivalent (from COFFEE, doesn't reset)
  permanentRestEquivalent = { Yellow=0, Blue=0, Red=0, Green=0 },
  
  -- Investment tracking: [Color] = { debentures={...}, loan={...}, endowment={...}, estateInvest={...}, stock={...} }
  investments = { Yellow={}, Blue={}, Red={}, Green={} },
  -- NGO Take Trip (free): while set, "Take this Trip (free)" buttons are on visible Trip cards; cleared when player picks one
  pendingNGOTakeTripColor = nil,
}

-- =========================
-- [S3] LOG / SAFE BROADCAST
-- =========================
local function log(msg)  if DEBUG then print("[WLB SHOP] "..tostring(msg)) end end

-- Normalize color: capitalize first letter, lowercase rest (e.g., "red" -> "Red")
local function normalizeColor(color)
  if type(color) ~= "string" or color == "" then return color end
  return color:sub(1,1):upper() .. color:sub(2):lower()
end
local function warn(msg) print("[WLB SHOP][WARN] "..tostring(msg)) end

local function safeBroadcastAll(msg, rgb)
  pcall(function() broadcastToAll(tostring(msg), rgb or {1,1,1}) end)
end

local function canBroadcastToColor(color)
  if type(color) ~= "string" or color == "" then return false end
  local ok, pl = pcall(function() return Player[color] end)
  if not ok or not pl then return false end
  local seated = false
  pcall(function() seated = pl.seated end)
  return seated == true
end

local function safeBroadcastToColor(msg, color, rgb)
  msg = tostring(msg)
  if canBroadcastToColor(color) then
    local ok = pcall(function() broadcastToColor(msg, color, rgb or {1,1,1}) end)
    if ok then return end
  end
  safeBroadcastAll("["..tostring(color).."] "..msg, rgb or {1,1,1})
end

-- =========================
-- [S3A] BASIC HELPERS
-- =========================
local function safeGetObjectsWithTag(tag)
  local ok, list = pcall(function() return getObjectsWithTag(tag) end)
  if ok and type(list) == "table" then return list end
  return {}
end

local function firstWithTag(tag)
  local list = safeGetObjectsWithTag(tag)
  for _,o in ipairs(list) do
    if o and o.getGUID then return o end
  end
  return nil
end

local function isCard(o) return o and o.tag=="Card" end
local function isDeck(o) return o and o.tag=="Deck" end
local function isCardOrDeck(o) return o and (o.tag=="Card" or o.tag=="Deck") end

local function dist2XZ(a, b)
  local dx = (a.x - b.x)
  local dz = (a.z - b.z)
  return dx*dx + dz*dz
end

local function ensureTag(obj, tag)
  if not obj or not obj.addTag or not obj.hasTag then return end
  if not obj.hasTag(tag) then pcall(function() obj.addTag(tag) end) end
end

local function colorTag(c) return TAG_COLOR_PREFIX .. tostring(c) end

local function safeCall(obj, fn, params)
  if not obj or not obj.call then return false, nil end
  local ok, ret = pcall(function() return obj.call(fn, params) end)
  return ok, ret
end

-- Busy-gate: reject UI actions during pipeline operations
local function checkBusyGate(player_color)
  if S.busy then
    safeBroadcastToColor("⛔ Shop is busy (reset/refill in progress). Please wait.", player_color or "White", {1,0.6,0.2})
    return true
  end
  return false
end

-- Unified CostsCalc wrapper: always use addCost (never setCost)
-- This ensures consistent cost management across all investment types
local function Costs_add(color, amount)
  if not color or color == "" or color == "White" then return false end
  local costsCalc = firstWithTag(TAG_COSTS_CALC)
  if not costsCalc or not costsCalc.call then
    warn("CostsCalc not found for addCost")
    return false
  end
  local ok = safeCall(costsCalc, "addCost", {color=color, amount=amount})
  if ok then
    log("CostsCalc: Added "..tostring(amount).." WIN to "..color)
  else
    warn("CostsCalc.addCost failed for "..color..": "..tostring(amount))
  end
  return ok
end

-- Clear costs by adding negative amount (if supported) or use clearCost
local function Costs_clear(color)
  if not color or color == "" or color == "White" then return false end
  local costsCalc = firstWithTag(TAG_COSTS_CALC)
  if not costsCalc or not costsCalc.call then
    warn("CostsCalc not found for clearCost")
    return false
  end
  -- Try clearCost first (if it exists), otherwise try addCost with negative current amount
  local ok = safeCall(costsCalc, "clearCost", {color=color})
  if not ok then
    -- Fallback: get current cost and subtract it
    local ok2, current = safeCall(costsCalc, "getCost", {color=color})
    if ok2 and current and current > 0 then
      ok = safeCall(costsCalc, "addCost", {color=color, amount=-current})
    end
  end
  if ok then
    log("CostsCalc: Cleared costs for "..color)
  else
    warn("CostsCalc.clearCost failed for "..color)
  end
  return ok
end

local function normalizeBoolResult(okCall, ret)
  if not okCall then return false end
  if type(ret) == "boolean" then return ret end
  if type(ret) == "table" and type(ret.ok) == "boolean" then return ret.ok end
  if ret == nil then return true end
  return true
end

-- PSC/status helpers early so they are in scope for all voucher/status flows (avoids TTS chunk/scope issue)
local function resolvePSC()
  return firstWithTag(TAG_PLAYER_STATUS_CTRL)
end
local function pscHasStatus(color, statusTag)
  local psc = resolvePSC()
  if not psc or not psc.call then
    warn("pscHasStatus: PlayerStatusController not found")
    return false
  end
  local ok, hasStatus = safeCall(psc, "PS_Event", {color=color, op="HAS_STATUS", statusTag=statusTag})
  if ok and type(hasStatus) == "boolean" then
    return hasStatus
  end
  warn("pscHasStatus: PS_Event HAS_STATUS returned invalid result")
  return false
end
local function pscRemoveStatus(color, statusTag)
  local psc = resolvePSC()
  if not psc then return false end
  local ok, ret = safeCall(psc, "PS_Event", {color=color, op="REMOVE_STATUS", statusTag=statusTag})
  return normalizeBoolResult(ok, ret)
end
local function pscAddStatus(color, statusTag)
  local psc = resolvePSC()
  if not psc then return false end
  local ok, ret = safeCall(psc, "PS_Event", {color=color, op="ADD_STATUS", statusTag=statusTag})
  return normalizeBoolResult(ok, ret)
end
local function pscAddChild(color, sex)
  local psc = resolvePSC()
  if not psc then return false end
  local ok, ret = safeCall(psc, "PS_Event", {color=color, op="ADD_CHILD", sex=sex})
  return normalizeBoolResult(ok, ret)
end
local function pscGetStatusCount(color, statusTag)
  local psc = resolvePSC()
  if not psc then return 0 end
  local ok, ret = safeCall(psc, "PS_Event", {color=color, op="GET_STATUS_COUNT", statusTag=statusTag})
  if ok and type(ret)=="number" then return math.max(0, math.floor(ret)) end
  return 0
end
local function pscRemoveStatusCount(color, statusTag, count)
  local psc = resolvePSC()
  if not psc then return false end
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count == 0 then return true end
  local ok, ret = safeCall(psc, "PS_Event", {color=color, op="REMOVE_STATUS_COUNT", statusTag=statusTag, count=count})
  return normalizeBoolResult(ok, ret)
end

-- =========================
-- [S3B] BOARD RESOLVE
-- =========================
local function ensureBoard()
  if S.board and S.board.getGUID then return true end
  local list = safeGetObjectsWithTag(TAG_SHOPS_BOARD)
  for _,o in ipairs(list) do
    if o and o.positionToWorld and o.getRotation then
      S.board = o
      local r = o.getRotation()
      S.desiredYaw = (r and r.y) or nil
      log("Board resolved: "..tostring((o.getName and o.getName()) or o.getGUID()))
      return true
    end
  end
  S.board = nil
  warn("Missing ShopsBoard tag: "..TAG_SHOPS_BOARD)
  safeBroadcastAll("⛔ ShopEngine: ShopsBoard not found (tag "..TAG_SHOPS_BOARD..")", {1,0.4,0.4})
  return false
end

local function worldFromLocal(localPos)
  if not ensureBoard() then return nil end
  local ok, wp = pcall(function()
    return S.board.positionToWorld({x=localPos.x, y=localPos.y, z=localPos.z})
  end)
  if ok and type(wp)=="table" then
    return {x=wp.x, y=wp.y, z=wp.z}
  end
  return nil
end

local function slotWorlds(row)
  local t = SLOTS_LOCAL[row]
  if not t then return nil end
  local out = { closed=nil, open={} }
  out.closed = worldFromLocal(t.closed)
  for i=1,3 do out.open[i] = worldFromLocal(t.open[i]) end
  return out
end

-- =========================
-- [S3C] CARD ORIENTATION / LOCK
-- =========================
local function forceFaceDown(obj)
  if not obj or (obj.tag~="Card" and obj.tag~="Deck") then return end
  if obj.is_face_down == false then pcall(function() obj.flip() end) end
  Wait.time(function()
    if obj and (obj.tag=="Card" or obj.tag=="Deck") and obj.is_face_down == false then
      pcall(function() obj.flip() end)
    end
  end, 0.35)
end

local function forceFaceUp(card)
  if not isCard(card) then return end
  if card.is_face_down then pcall(function() card.flip() end) end
  Wait.time(function()
    if card and card.tag=="Card" and card.is_face_down then
      pcall(function() card.flip() end)
    end
  end, 0.25)
end

-- Force face-up for Card OR Deck (used piles should stay visible)
local function forceFaceUpAny(obj)
  if not obj or (obj.tag ~= "Card" and obj.tag ~= "Deck") then return end
  if obj.tag == "Card" then
    forceFaceUp(obj)
    return
  end
  -- Deck
  local isDown = nil
  pcall(function() isDown = obj.is_face_down end)
  if isDown == true then
    pcall(function() obj.flip() end)
    Wait.time(function()
      local isDown2 = nil
      pcall(function() isDown2 = obj.is_face_down end)
      if obj and obj.tag=="Deck" and isDown2 == true then
        pcall(function() obj.flip() end)
      end
    end, 0.25)
  end
end

local function lockBrief(obj)
  if not obj or not obj.setLock then return end
  pcall(function() obj.setLock(true) end)
  Wait.time(function()
    if obj and obj.setLock then pcall(function() obj.setLock(false) end) end
  end, LOCK_TIME)
end

local function objectsNearPos(pos, eps)
  local out = {}
  if not pos then return out end
  local e2 = (eps or 1.0); e2 = e2*e2
  for _,o in ipairs(getAllObjects()) do
    if isCardOrDeck(o) and o.getPosition then
      local p = o.getPosition()
      if p and dist2XZ({x=p.x,z=p.z},{x=pos.x,z=pos.z}) <= e2 then
        table.insert(out, o)
      end
    end
  end
  return out
end

local function slotHasCard(pos)
  local near = objectsNearPos(pos, EPS_SLOT)
  for _,o in ipairs(near) do
    if isCard(o) then return true end
  end
  return false
end

-- =========================
-- [S4] DECK RESOLUTION
-- =========================
local function deckQty(deck)
  if not deck or deck.tag~="Deck" then return 0 end
  local q = 0
  pcall(function() q = deck.getQuantity() end)
  return tonumber(q) or 0
end

local function pickBestDeckByTag(deckTag)
  local list = safeGetObjectsWithTag(deckTag)
  local best, bestQty = nil, -1
  for _,o in ipairs(list) do
    if isDeck(o) then
      local q = deckQty(o)
      if q > bestQty then bestQty=q; best=o end
    end
  end
  return best
end

local function deckForRow(row)
  if row=="C" then return pickBestDeckByTag(TAG_DECK_C) end
  if row=="H" then return pickBestDeckByTag(TAG_DECK_H) end
  if row=="I" then return pickBestDeckByTag(TAG_DECK_I) end
  return nil
end

-- =========================
-- [S5] CARD CLASSIFICATION (NAME IS KING)
-- =========================
local function getNameSafe(obj)
  local n = ""
  if obj and obj.getName then pcall(function() n = obj.getName() end) end
  return tostring(n or "")
end

local function classifyRowByName(obj)
  if not isCard(obj) then return nil end
  local n = getNameSafe(obj)
  if string.match(n, PAT_C) then return "C" end
  if string.match(n, PAT_H) then return "H" end
  if string.match(n, PAT_I) then return "I" end
  return nil
end

local function classifyRowByNameStr(name)
  local n = tostring(name or "")
  if string.match(n, PAT_C) then return "C" end
  if string.match(n, PAT_H) then return "H" end
  if string.match(n, PAT_I) then return "I" end
  return nil
end

local function isShopCardByName(obj)
  return classifyRowByName(obj) ~= nil
end

-- =========================
-- [S6] SHOP CARD UI (IDLE + MODAL)
-- =========================
local UI_TOOLTIP_TEXT = "Do you want to buy this card?"
local UI_LIFT_Y = 2.0

local UI_BTN_W    = 1150
local UI_BTN_H    = 560
local UI_BTN_FONT = 240

local UI_POS_YES = { -0.55, 0.85, 0.95 }
local UI_POS_NO  = {  0.55, 0.85, 0.95 }

-- IDLE overlay (3x taller, still inside card)
local OVERLAY_W   = 950
local OVERLAY_H   = 950
local OVERLAY_Y   = 0.22
local OVERLAY_Z   = 0.65

local UI = {
  modalOpen = {}, -- [guid]=true
  homePos   = {}, -- [guid]={x,y,z}
}

-- Pending dice state (for cards requiring manual die roll)
local pendingDice = {} -- [guid] = { color, def, card, kind, ... }
local diceInitialValue = {} -- [guid] = initial die value when button shown (to detect if player rolled)

-- Pending investment input state (for interactive investment cards)
local pendingInvestment = {} -- [guid] = { color, def, card, kind, counterValue, ... }

-- Pending voucher choice (C/H): after YES on buy, ask "Use discount? (S)" then optionally "How many?"
local pendingVoucherChoice = {} -- [guid] = { buyer, row, card, def, voucherCount, voucherTag, step }

-- Die reading helper (must be defined early, used in UI functions)
local function tryReadDieValue(die)
  if not die then return nil end
  local ok, v = pcall(function() return die.getValue() end)
  if ok and type(v) == "number" and v >= 1 and v <= 6 then
    return v
  end
  return nil
end

function ui_noop() end

local function uiClearButtons(card)
  if not isCard(card) then return end
  pcall(function() card.clearButtons() end)
end

local function uiSetDescription(card, text)
  if not isCard(card) then return end
  local desc = text or UI_TOOLTIP_TEXT
  pcall(function() card.setDescription(desc) end)
end

local function uiClearDescription(card)
  if not isCard(card) then return end
  pcall(function() card.setDescription("") end)
end

local function uiRememberHome(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  if not UI.homePos[g] then
    local p = card.getPosition()
    UI.homePos[g] = {x=p.x, y=p.y, z=p.z}
  end
end

local function uiReturnHome(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  local p = UI.homePos[g]
  if p then
    pcall(function() card.setPositionSmooth({p.x,p.y,p.z}, false, true) end)
  end
  pcall(function() card.setLock(false) end)
end

local function uiLift(card)
  if not isCard(card) then return end
  uiRememberHome(card)
  local g = card.getGUID()
  local p = UI.homePos[g]
  if p then
    pcall(function() card.setPositionSmooth({p.x, p.y + UI_LIFT_Y, p.z}, false, true) end)
  end
  pcall(function() card.setLock(true) end)
end

local function uiAttachClickCatcher_IDLE(card)
  if not isCard(card) then return end
  card.createButton({
    click_function = "shop_onCardClicked",
    function_owner = self,
    label          = "",
    position       = {0, OVERLAY_Y, OVERLAY_Z},
    rotation       = {0,0,0},
    width          = OVERLAY_W,
    height         = OVERLAY_H,
    font_size      = 1,
    color          = {0,0,0,0},
    font_color     = {0,0,0,0},
    tooltip        = UI_TOOLTIP_TEXT,
  })
end

local function uiAttachQuestionLabel_MODAL(card)
  if not isCard(card) then return end
  card.createButton({
    click_function = "ui_noop",
    function_owner = self,
    label          = UI_TOOLTIP_TEXT,
    position       = {0, 0.95, 0},
    rotation       = {0, 0, 0},
    width          = 3000,
    height         = 340,
    font_size      = 160,
    color          = {0, 0, 0, 0.70},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
end

local function uiAttachYesNo_MODAL(card)
  if not isCard(card) then return end
  uiAttachQuestionLabel_MODAL(card)

  card.createButton({
    click_function = "shop_onYes",
    function_owner = self,
    label          = "YES",
    position       = UI_POS_YES,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.2, 0.7, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })

  card.createButton({
    click_function = "shop_onNo",
    function_owner = self,
    label          = "NO",
    position       = UI_POS_NO,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.8, 0.2, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
end

-- Voucher: "Use discount? (S)" Yes/No (S = voucher count)
local function uiAttachVoucherUseModal(card, voucherCount)
  if not isCard(card) then return end
  uiClearButtons(card)
  local label = "Use discount? ("..tostring(voucherCount)..")"
  card.createButton({
    click_function = "ui_noop",
    function_owner = self,
    label          = label,
    position       = {0, 0.95, 0},
    rotation       = {0, 0, 0},
    width          = 3000,
    height         = 340,
    font_size      = 160,
    color          = {0, 0, 0, 0.70},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
  card.createButton({
    click_function = "shop_voucherYes",
    function_owner = self,
    label          = "YES",
    position       = UI_POS_YES,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.2, 0.7, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
  card.createButton({
    click_function = "shop_voucherNo",
    function_owner = self,
    label          = "NO",
    position       = UI_POS_NO,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.8, 0.2, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
end

-- Voucher: "How many? 1..S" (buttons 1, 2, ..., min(S,4))
local function uiAttachVoucherCountModal(card, voucherCount)
  if not isCard(card) then return end
  uiClearButtons(card)
  local n = math.min(4, math.max(1, math.floor(tonumber(voucherCount) or 1)))
  card.createButton({
    click_function = "ui_noop",
    function_owner = self,
    label          = "How many tokens? (1.."..tostring(n)..")",
    position       = {0, 0.95, 0},
    rotation       = {0, 0, 0},
    width          = 3200,
    height         = 340,
    font_size      = 140,
    color          = {0, 0, 0, 0.70},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
  local zOff = -0.55
  for i = 1, n do
    card.createButton({
      click_function = (i == 1 and "shop_voucherUse1") or (i == 2 and "shop_voucherUse2") or (i == 3 and "shop_voucherUse3") or "shop_voucherUse4",
      function_owner = self,
      label          = tostring(i),
      position       = { -1.2 + (i-1) * 0.8, 0.65, zOff },
      rotation       = {0, 0, 0},
      width          = 500,
      height         = UI_BTN_H,
      font_size      = UI_BTN_FONT,
      color          = {0.25, 0.5, 0.8, 0.95},
      font_color     = {1, 1, 1, 1},
      tooltip        = "Use "..tostring(i).." discount token(s)",
    })
  end
end

local function isNearPosObj(obj, pos, eps)
  if not obj or not pos or not obj.getPosition then return false end
  local p = obj.getPosition()
  if not p then return false end
  return dist2XZ({x=p.x,z=p.z},{x=pos.x,z=pos.z}) <= ((eps or 1.0)^2)
end

local function isShopOpenSlotCard(card)
  if not isCard(card) then return false end
  if not ensureBoard() then return false end
  if not isShopCardByName(card) then return false end

  for _,row in ipairs({"C","H","I"}) do
    local sw = slotWorlds(row)
    if sw and sw.open then
      for i=1,3 do
        local pos = sw.open[i]
        if pos and isNearPosObj(card, pos, EPS_SLOT) then
          return true
        end
      end
    end
  end
  return false
end

local function uiEnsureIdle(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  if UI.modalOpen[g] then return end

  if not isShopOpenSlotCard(card) then
    uiClearButtons(card)
    uiClearDescription(card)
    UI.homePos[g] = nil
    return
  end

  uiClearButtons(card)
  uiSetDescription(card)
  uiAttachClickCatcher_IDLE(card)
end

local function uiOpenModal(card)
  if not isCard(card) then return end
  if not isShopOpenSlotCard(card) then return end

  local g = card.getGUID()
  if UI.modalOpen[g] then return end
  UI.modalOpen[g] = true

  uiSetDescription(card)
  uiLift(card)
  uiClearButtons(card)
  uiAttachYesNo_MODAL(card)
end

local function uiCloseModal(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  UI.modalOpen[g] = nil
  uiReturnHome(card)
  uiEnsureIdle(card)
end

local function uiCloseModalSoft(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  UI.modalOpen[g] = nil
  uiReturnHome(card)
end

local function uiAttachRollDiceButton(card)
  if not isCard(card) then return end
  uiClearButtons(card)
  
  -- Just shuffle faces when showing button (roll happens when button is clicked)
  local die = getObjectFromGUID(DIE_GUID)
  if die then
    pcall(function() die.randomize() end)  -- Shuffle faces only
  end
  
  card.createButton({
    click_function = "shop_onRollDice",
    function_owner = self,
    label          = "ROLL DICE",
    position       = {0, 0.85, 0},
    rotation       = {0, 0, 0},
    width          = UI_BTN_W * 1.2,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.8, 0.6, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "Click to roll the die",
  })
  
  uiSetDescription(card, "Click ROLL DICE to roll")
end

-- Counter UI for investment amount selection (+50, -50, OK buttons)
local function uiAttachCounter(card, currentAmount, minAmount, increment)
  if not isCard(card) then return end
  uiClearButtons(card)
  
  -- Ensure card stays lifted when showing counter UI
  local g = card.getGUID()
  local homePos = UI.homePos[g]
  if homePos then
    pcall(function()
      card.setLock(false)  -- Unlock for button interaction
      -- Keep card at lifted position
      local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
      card.setPositionSmooth(liftPos, false, true)
    end)
  end
  
  currentAmount = tonumber(currentAmount) or 0
  minAmount = tonumber(minAmount) or 0
  increment = tonumber(increment) or 50
  
  -- Button positioning: In TTS, "below" is achieved by Z coordinate, not Y
  -- Y = height above card surface (3D), X and Z = position on card (2D)
  local ROW1_Z = 0.35   -- Row with -50 / +50 (top row)
  local ROW2_Z = -0.35  -- Row with OK (bottom row, below +/-)
  local BTN_Y = 0.16    -- Y position for +/- buttons
  local OK_Y = 0.17     -- Y position for OK button (slightly higher to avoid z-fighting)
  
  -- Decrement button (-50)
  card.createButton({
    click_function = "inv_onCounterDecrement",
    function_owner = self,
    label = "-"..tostring(increment),
    position = {-0.55, BTN_Y, ROW1_Z},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.5,
    height = UI_BTN_H,
    font_size = UI_BTN_FONT * 0.8,
    color = {0.85, 0.25, 0.25, 0.95},
    font_color = {1, 1, 1, 1},
    tooltip = "Decrease by "..tostring(increment),
  })
  
  -- Increment button (+50)
  card.createButton({
    click_function = "inv_onCounterIncrement",
    function_owner = self,
    label = "+"..tostring(increment),
    position = {0.55, BTN_Y, ROW1_Z},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.5,
    height = UI_BTN_H,
    font_size = UI_BTN_FONT * 0.8,
    color = {0.25, 0.65, 0.30, 0.95},
    font_color = {1, 1, 1, 1},
    tooltip = "Increase by "..tostring(increment),
  })
  
  -- OK button (below +/- buttons in second row)
  card.createButton({
    click_function = "inv_onCounterOK",
    function_owner = self,
    label = "OK\n("..tostring(currentAmount).." WIN)",
    position = {0, OK_Y, ROW2_Z},  -- Different Z places it below +/- buttons
    rotation = {0, 0, 0},
    width = math.floor(UI_BTN_W * 1.35),
    height = math.floor(UI_BTN_H * 0.85),
    font_size = math.floor(UI_BTN_FONT * 0.75),
    color = {0.95, 0.95, 0.95, 0.95},  -- High contrast background
    font_color = {0.05, 0.15, 0.2, 1},
    tooltip = "Confirm investment of "..tostring(currentAmount).." WIN",
  })
  
  uiSetDescription(card, "Amount: "..tostring(currentAmount).." WIN (min: "..tostring(minAmount)..")")
end

local function refreshShopOpenUI()
  if not ensureBoard() then return end
  for _,o in ipairs(getAllObjects()) do
    if isCard(o) and isShopOpenSlotCard(o) then
      uiEnsureIdle(o)
    end
  end
end

local function refreshShopOpenUI_later(delaySec)
  Wait.time(function() refreshShopOpenUI() end, delaySec or 0.25)
end

-- =========================
-- [S7] TURN / BUYER RESOLUTION
-- =========================
local function getActiveTurnColor()
  local c = (Turns and Turns.turn_color) or ""
  if type(c) ~= "string" then c = "" end
  return c
end

-- Unified buyer color resolution: always use active turn color, reject "White" and invalid colors
local function resolveBuyerColor(clicking_color)
  -- Priority 1: Active turn color (source of truth)
  local active = getActiveTurnColor()
  if type(active) == "string" and active ~= "" and active ~= "White" then
    return active
  end
  
  -- Priority 2: Clicking color (only if valid and not White)
  if type(clicking_color) == "string" and clicking_color ~= "" and clicking_color ~= "White" then
    local normalized = normalizeColor(clicking_color)
    if normalized ~= "" and normalized ~= "White" then
      return normalized
    end
  end
  
  -- Fallback: reject (don't default to Yellow - this should be caught by caller)
  return nil
end

-- Track Hi-Tech card usage per turn (e.g., TV max 4 AP per turn)
-- Defined early so it can be used in onTurnChanged
local hitechUsageThisTurn = { Yellow={}, Blue={}, Red={}, Green={} }
local pendingTVUse = {}

local function resetHiTechUsage(color)
  if not hitechUsageThisTurn[color] then return end
  hitechUsageThisTurn[color] = {}
end

local function onTurnChanged(prevColor, newColor)
  if prevColor and prevColor ~= "" then
    S.boughtThisTurn[prevColor] = nil
    -- Reset Hi-Tech usage for previous player (TV max 4 AP per turn)
    resetHiTechUsage(prevColor)
  end
  if newColor and newColor ~= "" then
    -- Reset Hi-Tech usage for new player's turn
    resetHiTechUsage(newColor)
  end
end

function onUpdate()
  local c = getActiveTurnColor()
  if c ~= S.lastTurnColor then
    local prev = S.lastTurnColor
    S.lastTurnColor = c
    onTurnChanged(prev, c)
    if DEBUG then log("Turn changed: "..tostring(prev).." -> "..tostring(c)) end
  end
end

-- =========================
-- [S8] CONTROLLER RESOLUTION
-- =========================
local function findOne(tagA, tagB)
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(tagA) and o.hasTag(tagB) then return o end
  end
  return nil
end

local function resolveMoney(color)
  -- IMPORTANT:
  -- If both exist (legacy money tile + new money-on-board), we must prefer the board
  -- to avoid using the old tile by accident.

  -- 1) Player board with embedded money API (PlayerBoardController_Shared)
  local b = findOne(TAG_PLAYER_BOARD, colorTag(color))
  if b and b.call then
    local ok = pcall(function() return b.call("getMoney") end)
    if ok then return b end
  end

  -- 2) Legacy money tile
  local m = findOne(TAG_MONEY, colorTag(color))
  if m then return m end

  return nil
end

local function resolveAP(color)
  return findOne(TAG_AP_CTRL, colorTag(color))
end

local function resolveStats(color)
  return findOne(TAG_STATS, colorTag(color))
end

-- =========================
-- [S8B] DIE (Physical Die - Player Must Roll Manually)
-- =========================
-- Note: tryReadDieValue is defined earlier (near line 370) for use in UI functions
local DICE_ROLL_TIMEOUT  = 6.0  -- seconds to wait for roll
local DICE_STABLE_READS  = 4     -- number of consecutive stable reads needed
local DICE_POLL          = 0.12  -- seconds between polls

local function rollD6(cb)
  local die = getObjectFromGUID(DIE_GUID)
  if not die then 
    cb(nil, "no die")
    return 
  end
  
  -- Randomize (shuffle) the die, but DON'T automatically roll it
  pcall(function() die.randomize() end)
  
  -- Tell player to roll manually
  safeBroadcastAll("🎲 Roll the physical die now!", {1,1,0.6})
  
  -- Poll for stable die value (player rolls manually)
  local startT = Time.time
  local last, stable = nil, 0
  
  local function poll()
    -- Timeout check
    if (Time.time - startT) > DICE_ROLL_TIMEOUT then
      cb(nil, "timeout - please roll faster")
      return
    end
    
    -- Try to read die value
    local v = tryReadDieValue(die)
    
    -- Check if value is stable (same value read multiple times)
    if v and v == last then
      stable = stable + 1
    elseif v then
      last = v
      stable = 1
    else
      stable = 0
    end
    
    -- If stable for enough reads, we have the result
    if stable >= DICE_STABLE_READS then
      cb(last, nil)
      return
    end
    
    -- Continue polling
    Wait.time(poll, DICE_POLL)
  end
  
  -- Start polling after a short delay (give die time to randomize)
  Wait.time(poll, 0.18)
end

-- =========================
-- [S8C] MONEY / AP / STATS
-- =========================
local function moneyAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount == 0 then return true end

  local m = resolveMoney(color)
  if not m then
    warn("No MONEY ctrl for "..tostring(color))
    safeBroadcastToColor("⚠️ No MoneyCtrl — cannot add "..amount.." WIN.", color, {1,0.7,0.2})
    return false
  end

  local ok, ret = safeCall(m, "addMoney", amount)
  if normalizeBoolResult(ok, ret) then return true end
  ok, ret = safeCall(m, "addMoney", {amount=amount})
  if normalizeBoolResult(ok, ret) then return true end
  ok, ret = safeCall(m, "addMoney", {delta=amount})
  if normalizeBoolResult(ok, ret) then return true end

  warn("Money add failed for "..tostring(color).." amount="..tostring(amount))
  return false
end

local function moneySpend(color, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end

  local m = resolveMoney(color)
  if not m then
    warn("No MONEY ctrl for "..tostring(color))
    safeBroadcastToColor("⚠️ No MoneyCtrl — cannot deduct "..amount.." WIN.", color, {1,0.7,0.2})
    return false
  end

  local ok, ret = safeCall(m, "API_spend", {amount=amount})
  if ok and type(ret)=="table" and type(ret.ok)=="boolean" then return ret.ok == true end
  if ok and type(ret)=="boolean" then return ret == true end

  ok, ret = safeCall(m, "addMoney", -amount)
  if normalizeBoolResult(ok, ret) then return true end
  ok, ret = safeCall(m, "addMoney", {amount=-amount})
  if normalizeBoolResult(ok, ret) then return true end

  warn("Money spend failed for "..tostring(color).." amount="..tostring(amount))
  return false
end

-- IMPORTANT: PB AP CTRL v2.8 requires `to` (area). We use Events area: "E".
local function apSpend(color, amount, reason)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end

  local ap = resolveAP(color)
  if not ap then
    warn("No AP ctrl for "..tostring(color))
    safeBroadcastToColor("⚠️ No APCtrl — cannot deduct "..amount.." AP ("..tostring(reason)..").", color, {1,0.7,0.2})
    return false
  end

  local payload = {to="E", amount=amount, duration=0}
  local ok, ret = safeCall(ap, "spendAP", payload)
  if ok then
    if type(ret)=="boolean" then return ret end
    if type(ret)=="table" and type(ret.ok)=="boolean" then return ret.ok end
    if ret == nil then return true end
  end

  -- fallback
  ok, ret = safeCall(ap, "spendAP", {to="EVENT", amount=amount, duration=0})
  if ok then
    if type(ret)=="boolean" then return ret end
    if type(ret)=="table" and type(ret.ok)=="boolean" then return ret.ok end
    if ret == nil then return true end
  end

  warn("AP spend failed for "..tostring(color).." amount="..tostring(amount))
  return false
end

local function statsApply(color, deltas)
  local st = resolveStats(color)
  if not st then
    warn("No STATS ctrl for "..tostring(color))
    return false
  end
  local ok, ret = safeCall(st, "applyDelta", deltas)
  return normalizeBoolResult(ok, ret)
end

-- Satisfaction Token GUIDs (same as Event Engine)
local SAT_TOKEN_GUIDS = {
  Yellow = "d33a15",
  Red    = "6fe69b",
  Blue   = "b2b5e3",
  Green  = "e8834c",
}

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

local function satAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount == 0 then return true end

  local satObj = getSatToken(color)
  if not satObj then
    safeBroadcastAll("⚠️ SAT +"..amount.." for "..color.." (SAT token not found)", {1,0.7,0.2})
    return false
  end

  -- Unlock token before calling (same as Event Engine)
  pcall(function() satObj.setLock(false) end)

  -- Try addSat() method first (same as Event Engine)
  local ok = false
  if satObj.call then
    ok = pcall(function() satObj.call("addSat", { delta = amount }) end)
  end

  -- Fallback: call p1/m1 repeatedly if addSat() doesn't work
  if not ok and satObj.call then
    local stepFn = (amount >= 0) and "p1" or "m1"
    local n = math.abs(amount)
    for _=1,n do
      local ok2 = pcall(function() satObj.call(stepFn) end)
      if not ok2 then
        warn("SAT CALL FAILED: "..tostring(stepFn))
        safeBroadcastAll("⚠️ SAT +"..amount.." for "..color.." (SAT API call failed)", {1,0.7,0.2})
        return false
      end
    end
    ok = true
  end

  if ok then
    if DEBUG then
      log("SAT +"..amount.." for "..color.." OK")
    end
  else
    safeBroadcastAll("⚠️ SAT +"..amount.." for "..color.." (SAT API not working)", {1,0.7,0.2})
  end

  return ok
end

-- =========================
-- [S8B] HI-TECH HELPERS
-- =========================

-- Hi-Tech card zone LOCAL@PLAYER_BOARD (measured positions - needs calibration)
-- These are LOCAL coordinates relative to each player board where Hi-Tech cards are placed
-- Cards stack vertically as more are purchased
-- 
-- CALIBRATION INSTRUCTIONS:
-- 1. Use ScannerEstates tool (or similar scanner) to measure positions
-- 2. Place scanner token where you want Hi-Tech cards to appear (near player board, off to the side)
-- 3. Select player color (Y/B/R/G) and click PRINT LOCAL
-- 4. Copy the LOCAL@BOARD coordinates into this table
-- 5. Cards will stack vertically from this base position
-- 
-- RECOMMENDED PLACEMENT:
-- - Place cards off to the side of the player board (not on the board itself)
-- - Use X or Z offset to position cards next to the board (e.g., x=-1.5 or z=-0.5)
-- - Ensure Y is at board surface level (0.592) - stacking happens automatically
-- Hi-Tech card zone LOCAL@PLAYER_BOARD (local coordinates relative to each player board)
-- These are LOCAL coordinates - will be converted to world using board.positionToWorld()
-- Base position: x=6.6, z=0, y=1.2 (LOCAL coordinates, not world!)
local HITECH_ZONE_LOCAL = {
  Yellow = {x=6.6, y=1.2, z=0},  -- Calibrated position
  Blue   = {x=6.6, y=1.2, z=0},  -- TODO: Calibrate for each player using ScannerEstates tool
  Red    = {x=6.6, y=1.2, z=0},  -- TODO: Calibrate for each player using ScannerEstates tool
  Green  = {x=6.6, y=1.2, z=0},  -- TODO: Calibrate for each player using ScannerEstates tool
}

-- Stacking parameters
local HITECH_STACK_Y_STEP = 0.35  -- Vertical spacing between stacked cards
local HITECH_STACK_Y_BASE = 0.65  -- Base Y offset above board surface

-- =========================
-- [S9B] HI-TECH DEFINITIONS (defined early so functions can use it)
-- =========================
local HI_TECH_DEF = {
  HSHOP_01_COFFEE = {cost=1200, extraAP=0, kind="COFFEE"},
  HSHOP_02_COFFEE = {cost=1200, extraAP=0, kind="COFFEE"},
  
  HSHOP_03_COMPUTER = {cost=1100, extraAP=0, kind="COMPUTER"},
  HSHOP_04_DEVICE = {cost=1100, extraAP=0, kind="DEVICE"},
  HSHOP_05_TV = {cost=1400, extraAP=0, kind="TV"},
  
  HSHOP_06_BABYMONITOR = {cost=1200, extraAP=0, kind="BABYMONITOR"},
  HSHOP_07_BABYMONITOR = {cost=1200, extraAP=0, kind="BABYMONITOR"},
  HSHOP_08_HMONITOR = {cost=300, extraAP=0, kind="HMONITOR"},
  
  HSHOP_09_CAR = {cost=1200, extraAP=0, kind="CAR"},
  HSHOP_10_CAR = {cost=1200, extraAP=0, kind="CAR"},
  
  HSHOP_11_ALARM = {cost=700, extraAP=0, kind="ALARM"},
  
  HSHOP_12_SMARTPHONE = {cost=1000, extraAP=0, kind="SMARTPHONE"},
  
  HSHOP_13_SMARTWATCH = {cost=700, extraAP=0, kind="SMARTWATCH"},
  HSHOP_14_SMARTWATCH = {cost=700, extraAP=0, kind="SMARTWATCH"},
}

local function findPlayerBoard(color)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_PLAYER_BOARD) and o.hasTag(colorTag(color)) then
      return o
    end
  end
  return nil
end

local function countOwnedHiTechCards(color)
  -- Count physical Hi-Tech cards on table for this player (for stacking)
  local count = 0
  for _, o in ipairs(getAllObjects()) do
    if o and o.tag == "Card" and o.hasTag then
      if o.hasTag("WLB_HI_TECH") and o.hasTag(colorTag(color)) then
        count = count + 1
      end
    end
  end
  return count
end

-- Attach interactive button to Hi-Tech card when purchased
-- Defined early so it can be called from giveCardToPlayer
local function attachHiTechInteractiveButton(card, color)
  if not card or card.tag ~= "Card" then return end
  local cardName = getNameSafe(card)
  if not cardName then return end
  local def = HI_TECH_DEF[cardName]
  if not def then
    log("attachHiTechInteractiveButton: No def for card "..tostring(cardName))
    return
  end
  
  local kind = def.kind or ""
  
  -- Only attach buttons for interactive cards
  if kind == "TV" then
    -- TV: Show button to use it (will show modal with 1-4 AP options)
    pcall(function()
      card.createButton({
        click_function = "hitech_onTVUse",
        function_owner = self,
        label = "USE TV",
        position = {0, 0.33, 1.0},
        rotation = {0, 0, 0},
        width = 800,
        height = 300,
        font_size = 150,
        color = {0.2, 0.6, 0.9},
        font_color = {1, 1, 1},
        tooltip = "Spend 1-4 AP to gain +1 SAT per AP"
      })
    end)
    
  elseif kind == "COMPUTER" then
    -- COMPUTER: Button to spend 1 AP for +1 Knowledge
    pcall(function()
      card.createButton({
        click_function = "hitech_onComputerUse",
        function_owner = self,
        label = "USE\n(1 AP → +1 Know)",
        position = {0, 0.33, 1.0},
        rotation = {0, 0, 0},
        width = 800,
        height = 300,
        font_size = 130,
        color = {0.2, 0.7, 0.4},
        font_color = {1, 1, 1},
        tooltip = "Spend 1 AP to gain +1 Knowledge (unlimited uses)"
      })
    end)
    
  elseif kind == "DEVICE" then
    -- DEVICE: Button to spend 1 AP for +1 Skill
    pcall(function()
      card.createButton({
        click_function = "hitech_onDeviceUse",
        function_owner = self,
        label = "USE\n(1 AP → +1 Skill)",
        position = {0, 0.33, 1.0},
        rotation = {0, 0, 0},
        width = 800,
        height = 300,
        font_size = 130,
        color = {0.7, 0.4, 0.2},
        font_color = {1, 1, 1},
        tooltip = "Spend 1 AP to gain +1 Skill (unlimited uses)"
      })
    end)
    
  elseif kind == "HMONITOR" then
    -- HMONITOR: Button to check SICK status and roll die if sick
    pcall(function()
      card.createButton({
        click_function = "hitech_onHMonitorUse",
        function_owner = self,
        label = "CHECK\nHEALTH",
        position = {0, 0.33, 1.0},
        rotation = {0, 0, 0},
        width = 800,
        height = 300,
        font_size = 130,
        color = {0.8, 0.2, 0.2},
        font_color = {1, 1, 1},
        tooltip = "Click to check if sick (rolls die if sick, once per turn)"
      })
    end)
  end
end

local function giveCardToPlayer(card, color)
  -- Place Hi-Tech card at LOCAL coordinates relative to player board
  -- Base LOCAL position: x=6.6, z=0, y=1.2 (relative to board, not world!)
  -- Cards stack vertically as more are purchased
  if not card then return end
  
  -- Always tag the card
  pcall(function()
    card.addTag(colorTag(color))
    card.addTag("WLB_HI_TECH")
  end)
  
  -- Clear UI and unlock the card (it was locked when modal opened via uiLift)
  pcall(function()
    uiClearButtons(card)
    uiClearDescription(card)
    card.setLock(false)
    card.setHoldable(true)
  end)
  
  -- Find player board for this color
  local board = findPlayerBoard(color)
  if not board then
    log("No player board found for: "..tostring(color).." - cannot place Hi-Tech card")
    -- Make it holdable as fallback
    pcall(function() card.setHoldable(true) end)
    return
  end
  
  -- Get LOCAL position for this player's Hi-Tech zone
  local localBase = HITECH_ZONE_LOCAL[color]
  if not localBase then
    log("No Hi-Tech zone defined for: "..tostring(color))
    pcall(function() card.setHoldable(true) end)
    return
  end
  
  -- Count existing cards for this player to stack them vertically
  local existingCount = countOwnedHiTechCards(color)
  
  -- Calculate LOCAL position with stacking (Y increases with each card)
  local localPos = {
    x = localBase.x,
    y = localBase.y + (existingCount * HITECH_STACK_Y_STEP),
    z = localBase.z
  }
  
  -- Convert LOCAL to WORLD coordinates using player board
  local worldPos = nil
  if board and board.positionToWorld then
    local ok, wp = pcall(function()
      local result = board.positionToWorld({localPos.x, localPos.y, localPos.z})
      -- Handle Vector object (TTS returns Vector which can be indexed or has .x/.y/.z)
      if result then
        if type(result) == "table" then
          if result.x then
            return {x=result.x, y=result.y, z=result.z}
          elseif result[1] then
            return {x=result[1], y=result[2], z=result[3]}
          end
        end
      end
      return nil
    end)
    if ok and wp then
      worldPos = wp
    end
  end
  
  -- Fallback: use board position + local offset if conversion fails
  if not worldPos then
    local boardPos = board.getPosition()
    if boardPos then
      worldPos = {
        x = boardPos.x + localPos.x,
        y = boardPos.y + localPos.y,
        z = boardPos.z + localPos.z
      }
    end
  end
  
  if worldPos then
    pcall(function()
      card.setPositionSmooth(worldPos, false, true)
    end)
    log("Placed Hi-Tech card for "..tostring(color).." at LOCAL("..tostring(localPos.x)..","..tostring(localPos.y)..","..tostring(localPos.z)..") -> WORLD("..tostring(worldPos.x)..","..tostring(worldPos.y)..","..tostring(worldPos.z)..")")
    
    -- Attach interactive button after card is placed (delay to ensure card is ready)
    Wait.time(function()
      if card and card.tag == "Card" and attachHiTechInteractiveButton then
        attachHiTechInteractiveButton(card, color)
      end
    end, 0.5)
  else
    log("Failed to place Hi-Tech card for: "..tostring(color))
    -- Make it holdable as fallback
    pcall(function() card.setHoldable(true) end)
  end
end

local function applyHiTechEffect(color, cardName, def)
  local kind = def.kind or ""
  
  if kind == "COFFEE" then
    -- Permanent rest-equivalent +1 (stacks with PILLS/NATURE_TRIP)
    -- This is tracked separately from consumable rest-equivalent (doesn't reset each turn)
    S.permanentRestEquivalent[color] = (S.permanentRestEquivalent[color] or 0) + 1
    safeBroadcastToColor("☕ Coffee purchased: +1 permanent rest bonus (total: "..S.permanentRestEquivalent[color]..")", color, {0.8,0.6,0.3})
    
  elseif kind == "COMPUTER" or kind == "DEVICE" or kind == "TV" then
    -- Interactive cards - no immediate effect, player clicks card to use
    -- Card will have buttons added in card interaction handler
    safeBroadcastToColor("✅ "..tostring(cardName).." purchased (click card to use)", color, {0.8,0.9,1})
    
  elseif kind == "BABYMONITOR" then
    -- Reduces child AP blocking by 1 per baby (max 2 babies)
    -- Implementation: PlayerStatusController's PS_GetChildBlockedAP() checks for BABYMONITOR ownership
    -- Immediately unblock AP if player has children
    
    -- Get PlayerStatusController to check child-blocked AP before and after
    local psc = firstWithTag(TAG_PLAYER_STATUS_CTRL)
    if psc and psc.call then
      -- First, temporarily remove the card from owned list to get raw blocked AP
      local hadMonitor = ownsHiTechKind(color, "BABYMONITOR")
      if hadMonitor and S.ownedHiTech[color] then
        -- Remove this card temporarily (it was just added)
        for i, name in ipairs(S.ownedHiTech[color]) do
          if name == cardName then
            table.remove(S.ownedHiTech[color], i)
            break
          end
        end
      end
      
      -- Get raw blocked AP (before BABYMONITOR reduction)
      local ok, rawBlocked = pcall(function()
        return psc.call("PS_GetChildBlockedAP", {color=color})
      end)
      
      -- Restore the card to owned list
      if hadMonitor and not ownsHiTechKind(color, "BABYMONITOR") then
        if not S.ownedHiTech[color] then S.ownedHiTech[color] = {} end
        table.insert(S.ownedHiTech[color], cardName)
      end
      
      -- Get effective blocked AP (after BABYMONITOR reduction)
      local ok2, effectiveBlocked = pcall(function()
        return psc.call("PS_GetChildBlockedAP", {color=color})
      end)
      
      if ok and ok2 and type(rawBlocked) == "number" and type(effectiveBlocked) == "number" then
        -- Calculate reduction: difference between raw and effective blocked AP
        local reduction = rawBlocked - effectiveBlocked
        
        if reduction > 0 then
          -- Unblock AP: move from INACTIVE to START
          local ap = resolveAP(color)
          if ap and ap.call then
            -- Move negative amount from INACTIVE (moves back to START)
            local unblockOk, unblockResult = pcall(function()
              return ap.call("moveAP", {to="INACTIVE", amount=-reduction})
            end)
            
            if unblockOk then
              safeBroadcastToColor("👶 Baby Monitor purchased: unblocked "..tostring(reduction).." AP (reduces child AP blocking by 1 per baby, max 2 babies)", color, {0.7,0.9,1})
              log("BABYMONITOR: "..color.." purchased - rawBlocked="..tostring(rawBlocked).." effectiveBlocked="..tostring(effectiveBlocked).." unblocked="..tostring(reduction))
            else
              safeBroadcastToColor("👶 Baby Monitor purchased: reduces child AP blocking by 1 per baby (max 2 babies)", color, {0.7,0.9,1})
              warn("BABYMONITOR: Failed to unblock AP for "..color.." - "..tostring(unblockResult))
            end
          else
            safeBroadcastToColor("👶 Baby Monitor purchased: reduces child AP blocking by 1 per baby (max 2 babies)", color, {0.7,0.9,1})
            warn("BABYMONITOR: AP Controller not found for "..color.." - cannot unblock AP")
          end
        else
          safeBroadcastToColor("👶 Baby Monitor purchased: reduces child AP blocking by 1 per baby (max 2 babies) - will take effect when you have children", color, {0.7,0.9,1})
        end
      else
        safeBroadcastToColor("👶 Baby Monitor purchased: reduces child AP blocking by 1 per baby (max 2 babies)", color, {0.7,0.9,1})
        if not ok then
          warn("BABYMONITOR: Failed to get raw child-blocked AP for "..color.." - "..tostring(rawBlocked))
        elseif not ok2 then
          warn("BABYMONITOR: Failed to get effective child-blocked AP for "..color.." - "..tostring(effectiveBlocked))
        end
      end
    else
      safeBroadcastToColor("👶 Baby Monitor purchased: reduces child AP blocking by 1 per baby (max 2 babies)", color, {0.7,0.9,1})
      warn("BABYMONITOR: PlayerStatusController not found - cannot check/unblock AP")
    end
    
  elseif kind == "HMONITOR" then
    -- SICK protection (will be checked when SICK status is applied)
    safeBroadcastToColor("🏥 Health Monitor purchased: SICK protection active", color, {0.7,1,0.7})
    
  elseif kind == "CAR" then
    -- Shop/Estate entry free; Event cards -1 AP
    safeBroadcastToColor("🚗 Car purchased: free shop/estate entry; Event cards -1 AP", color, {0.8,0.8,1})
    
  elseif kind == "ALARM" then
    -- Theft protection (will be checked during theft events)
    safeBroadcastToColor("🔔 Alarm purchased: theft protection active", color, {0.9,0.9,0.7})
    
  elseif kind == "SMARTPHONE" then
    -- End-of-turn check (handled in Turn Controller)
    safeBroadcastToColor("📱 Smartphone purchased: end-of-turn Work/Learning bonus active", color, {0.8,0.9,1})
    
  elseif kind == "SMARTWATCH" then
    -- Start-of-turn -1 INACTIVE AP (except child-blocked, handled in Turn Controller)
    safeBroadcastToColor("⌚ Smartwatch purchased: -1 INACTIVE AP per turn (except child-blocked)", color, {0.8,0.9,1})
    
  else
    safeBroadcastToColor("ℹ️ "..tostring(cardName).." purchased (effect type: "..tostring(kind)..")", color, {0.9,0.9,1})
  end
end

-- Check if player owns a specific Hi-Tech card
local function ownsHiTech(color, cardName)
  color = normalizeColor(color)
  if not S.ownedHiTech[color] then return false end
  for _, name in ipairs(S.ownedHiTech[color]) do
    if name == cardName then return true end
  end
  return false
end

-- Check if player owns any card of a specific kind
local function ownsHiTechKind(color, kind)
  color = normalizeColor(color)
  if not S.ownedHiTech[color] then return false end
  for _, name in ipairs(S.ownedHiTech[color]) do
    local def = HI_TECH_DEF[name]
    if def and def.kind == kind then return true end
  end
  return false
end

-- =========================
-- [S8C] HI-TECH INTERACTIVE BUTTONS
-- =========================
-- Note: hitechUsageThisTurn and resetHiTechUsage are defined earlier (before onTurnChanged)

local function getHiTechUsage(cardName, color)
  if not hitechUsageThisTurn[color] then hitechUsageThisTurn[color] = {} end
  return hitechUsageThisTurn[color][cardName] or 0
end

local function incrementHiTechUsage(cardName, color, amount)
  if not hitechUsageThisTurn[color] then hitechUsageThisTurn[color] = {} end
  hitechUsageThisTurn[color][cardName] = (hitechUsageThisTurn[color][cardName] or 0) + amount
end

-- Click handler for TV: show modal with 1-4 AP options
function hitech_onTVUse(card, player_color, alt_click)
  if not card or card.tag ~= "Card" then return end
  local cardName = getNameSafe(card)
  local color = resolveBuyerColor(player_color)
  
  -- Check ownership
  if not ownsHiTech(color, cardName) then
    safeBroadcastToColor("⛔ You don't own this card.", color, {1,0.6,0.2})
    return
  end
  
  -- Check active turn
  local active = getActiveTurnColor()
  if color ~= active then
    safeBroadcastToColor("⛔ Only the active player can use Hi-Tech cards.", color, {1,0.6,0.2})
    return
  end
  
  -- Clear existing buttons and show AP choice buttons
  pcall(function() card.clearButtons() end)
  
  -- Show buttons for 1, 2, 3, 4 AP
  local usedAP = getHiTechUsage(cardName, color)
  local maxAP = 4 - usedAP
  
  if maxAP <= 0 then
    safeBroadcastToColor("⛔ TV already used maximum 4 AP this turn.", color, {1,0.6,0.2})
    attachHiTechInteractiveButton(card, color)  -- Restore button
    return
  end
  
  -- Store pending state
  local cardGuid = card.getGUID()
  pendingTVUse[cardGuid] = { color=color, cardName=cardName }
  
  -- Create buttons for available amounts (each with its own function)
  for apAmount = 1, math.min(4, maxAP) do
    local btnLabel = tostring(apAmount).." AP\n(+"..tostring(apAmount).." SAT)"
    local btnZ = -1.0 + (apAmount - 1) * 0.5
    local fnName = "hitech_onTV_"..tostring(apAmount).."AP"
    
    -- Store AP amount in pending state (keyed by function name)
    if not pendingTVUse[cardGuid].amounts then
      pendingTVUse[cardGuid].amounts = {}
    end
    pendingTVUse[cardGuid].amounts[fnName] = apAmount
    
    pcall(function()
      card.createButton({
        click_function = fnName,
        function_owner = self,
        label = btnLabel,
        position = {0, 0.33, btnZ},
        rotation = {0, 0, 0},
        width = 700,
        height = 280,
        font_size = 120,
        color = {0.2, 0.6, 0.9},
        font_color = {1, 1, 1},
        tooltip = "Spend "..tostring(apAmount).." AP to gain +"..tostring(apAmount).." Satisfaction"
      })
    end)
  end
  
  -- Cancel button
  pcall(function()
    card.createButton({
      click_function = "hitech_onCancel",
      function_owner = self,
      label = "CANCEL",
      position = {0, 0.33, 1.5},
      rotation = {0, 0, 0},
      width = 600,
      height = 250,
      font_size = 140,
      color = {0.5, 0.5, 0.5},
      font_color = {1, 1, 1},
      tooltip = "Cancel"
    })
  end)
end

-- TV button handlers (created dynamically for each AP amount)
function hitech_onTV_1AP(card, player_color, alt_click) hitech_onTVConfirm(card, player_color, 1) end
function hitech_onTV_2AP(card, player_color, alt_click) hitech_onTVConfirm(card, player_color, 2) end
function hitech_onTV_3AP(card, player_color, alt_click) hitech_onTVConfirm(card, player_color, 3) end
function hitech_onTV_4AP(card, player_color, alt_click) hitech_onTVConfirm(card, player_color, 4) end

-- Confirm TV usage with specific AP amount
function hitech_onTVConfirm(card, player_color, apAmount)
  if not card or card.tag ~= "Card" then return end
  local cardGuid = card.getGUID()
  local pending = pendingTVUse[cardGuid]
  
  if not pending then
    safeBroadcastToColor("⛔ TV use cancelled (invalid state).", player_color or "White", {1,0.6,0.2})
    return
  end
  
  local cardName = pending.cardName
  local color = pending.color
  apAmount = tonumber(apAmount) or 1
  
  if apAmount <= 0 or apAmount > 4 then
    safeBroadcastToColor("⛔ Invalid AP amount (must be 1-4).", color, {1,0.6,0.2})
    hitech_onCancel(card, player_color, false)
    return
  end
  
  -- Try to spend AP
  local ok = apSpend(color, apAmount, "HI_TECH_TV")
  if not ok then
    safeBroadcastToColor("⛔ Not enough AP (need "..tostring(apAmount).." AP).", color, {1,0.6,0.2})
    hitech_onCancel(card, player_color, false)
    return
  end
  
  -- Add satisfaction
  satAdd(color, apAmount)
  
  -- Track usage
  incrementHiTechUsage(cardName, color, apAmount)
  
  -- Clear buttons and restore main button
  pendingTVUse[cardGuid] = nil  -- Clear pending state
  pcall(function() card.clearButtons() end)
  attachHiTechInteractiveButton(card, color)
  
  safeBroadcastToColor("✅ TV used: -"..tostring(apAmount).." AP, +"..tostring(apAmount).." SAT", color, {0.7,1,0.7})
end

-- Cancel Hi-Tech interaction
function hitech_onCancel(card, player_color, alt_click)
  if not card or card.tag ~= "Card" then return end
  local cardGuid = card.getGUID()
  
  -- Clear pending state
  pendingTVUse[cardGuid] = nil
  
  -- Find owner by checking tags
  local color = nil
  for _, c in ipairs({"Yellow", "Blue", "Red", "Green"}) do
    if card.hasTag and card.hasTag(colorTag(c)) then
      color = c
      break
    end
  end
  
  if color then
    pcall(function() card.clearButtons() end)
    attachHiTechInteractiveButton(card, color)
  end
end

-- Click handler for COMPUTER
function hitech_onComputerUse(card, player_color, alt_click)
  if not card or card.tag ~= "Card" then return end
  local cardName = getNameSafe(card)
  local color = resolveBuyerColor(player_color)
  
  -- Check ownership
  if not ownsHiTech(color, cardName) then
    safeBroadcastToColor("⛔ You don't own this card.", color, {1,0.6,0.2})
    return
  end
  
  -- Check active turn
  local active = getActiveTurnColor()
  if color ~= active then
    safeBroadcastToColor("⛔ Only the active player can use Hi-Tech cards.", color, {1,0.6,0.2})
    return
  end
  
  -- Try to spend 1 AP
  local ok = apSpend(color, 1, "HI_TECH_COMPUTER")
  if not ok then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP).", color, {1,0.6,0.2})
    return
  end
  
  -- Add Knowledge
  statsApply(color, {k=1})
  
  safeBroadcastToColor("✅ Computer used: -1 AP, +1 Knowledge", color, {0.7,1,0.7})
end

-- Click handler for DEVICE
function hitech_onDeviceUse(card, player_color, alt_click)
  if not card or card.tag ~= "Card" then return end
  local cardName = getNameSafe(card)
  local color = resolveBuyerColor(player_color)
  
  -- Check ownership
  if not ownsHiTech(color, cardName) then
    safeBroadcastToColor("⛔ You don't own this card.", color, {1,0.6,0.2})
    return
  end
  
  -- Check active turn
  local active = getActiveTurnColor()
  if color ~= active then
    safeBroadcastToColor("⛔ Only the active player can use Hi-Tech cards.", color, {1,0.6,0.2})
    return
  end
  
  -- Try to spend 1 AP
  local ok = apSpend(color, 1, "HI_TECH_DEVICE")
  if not ok then
    safeBroadcastToColor("⛔ Not enough AP (need 1 AP).", color, {1,0.6,0.2})
    return
  end
  
  -- Add Skill
  statsApply(color, {s=1})
  
  safeBroadcastToColor("✅ Device used: -1 AP, +1 Skill", color, {0.7,1,0.7})
end

function hitech_onHMonitorUse(card, player_color, alt_click)
  if not card or card.tag ~= "Card" then return end
  local cardName = getNameSafe(card)
  local color = resolveBuyerColor(player_color)
  
  -- Check ownership
  if not ownsHiTech(color, cardName) then
    safeBroadcastToColor("⛔ You don't own this card.", color, {1,0.6,0.2})
    return
  end
  
  -- Check active turn
  local active = getActiveTurnColor()
  if color ~= active then
    safeBroadcastToColor("⛔ Only the active player can use Hi-Tech cards.", color, {1,0.6,0.2})
    return
  end
  
  -- Check if already used this turn
  local used = getHiTechUsage(cardName, color)
  if used > 0 then
    safeBroadcastToColor("⛔ Health Monitor already used this turn (once per turn).", color, {1,0.6,0.2})
    return
  end
  
  -- Check if player is sick
  local isSick = pscHasStatus(color, TAG_STATUS_SICK)
  
  if not isSick then
    safeBroadcastToColor("🩺 You are not sick, there is no effect.", color, {0.9,0.9,0.9})
    return
  end
  
  -- Player is sick - roll die
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", color, {1,0.6,0.2})
    return
  end
  
  -- Mark as used (before rolling, so player can't click multiple times)
  incrementHiTechUsage(cardName, color, 1)
  
  -- Randomize and roll the die
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  safeBroadcastToColor("🎲 Rolling die...", color, {0.8,0.9,1})
  
  -- Wait for die to settle
  local timeout = os.time() + 6
  Wait.condition(
    function()
      -- Die has settled, read the value
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", color, {1,0.7,0.3})
        return
      end
      
      -- Apply effect based on roll
      if v >= 3 and v <= 6 then
        -- Roll 3-6: Cured (remove SICK status)
        pscRemoveStatus(color, TAG_STATUS_SICK)
        safeBroadcastToColor("✅ Health Monitor cured SICK! (roll="..v..")", color, {0.7,1,0.7})
      else
        -- Roll 1-2: Still sick (status remains)
        safeBroadcastToColor("🩺 Health Monitor failed to cure (roll="..v.."). SICK status remains.", color, {1,0.7,0.3})
      end
    end,
    function()
      -- Condition: wait for die to be resting or timeout
      local resting = false
      pcall(function() resting = die.resting end)
      if resting then return true end
      if os.time() >= timeout then return true end
      return false
    end
  )
end

-- =========================
-- [S9] CONSUMABLES DEFINITIONS
-- =========================
local CONSUMABLE_DEF = {
  CSHOP_01_CURE = {cost=200, extraAP=0, kind="CURE"},
  CSHOP_02_CURE = {cost=200, extraAP=0, kind="CURE"},
  CSHOP_03_CURE = {cost=200, extraAP=0, kind="CURE"},
  CSHOP_04_CURE = {cost=200, extraAP=0, kind="CURE"},
  CSHOP_05_CURE = {cost=200, extraAP=0, kind="CURE"},
  CSHOP_06_CURE = {cost=200, extraAP=0, kind="CURE"},

  CSHOP_07_KARMA = {cost=200, extraAP=0, kind="KARMA"},
  CSHOP_08_KARMA = {cost=200, extraAP=0, kind="KARMA"},

  CSHOP_09_BOOK  = {cost=200, extraAP=0, kind="BOOK"},
  CSHOP_10_BOOK  = {cost=200, extraAP=0, kind="BOOK"},

  CSHOP_11_MENTORSHIP = {cost=200, extraAP=0, kind="MENTORSHIP"},
  CSHOP_12_MENTORSHIP = {cost=200, extraAP=0, kind="MENTORSHIP"},

  CSHOP_13_SUPPLEMENTS = {cost=300, extraAP=0, kind="SUPPLEMENTS"},
  CSHOP_14_SUPPLEMENTS = {cost=300, extraAP=0, kind="SUPPLEMENTS"},
  CSHOP_15_SUPPLEMENTS = {cost=300, extraAP=0, kind="SUPPLEMENTS"},

  CSHOP_16_PILLS = {cost=200, extraAP=0, kind="PILLS"},
  CSHOP_17_PILLS = {cost=200, extraAP=0, kind="PILLS"},
  CSHOP_18_PILLS = {cost=200, extraAP=0, kind="PILLS"},
  CSHOP_19_PILLS = {cost=200, extraAP=0, kind="PILLS"},
  CSHOP_20_PILLS = {cost=200, extraAP=0, kind="PILLS"},

  -- Trip/experience cards (NGO "Take Trip (free)" perk): Nature Trip, Family visit, Zero Gravity, Parachute, Bungee, Balloon
  CSHOP_21_TRIP = {cost=1000, extraAP=2, kind="NATURE_TRIP", countsAsTrip=true},
  CSHOP_22_TRIP = {cost=1000, extraAP=2, kind="NATURE_TRIP", countsAsTrip=true},

  CSHOP_23_FAMILY = {cost=1000, extraAP=0, kind="FAMILY", countsAsTrip=true},   -- Family Planning Centre visit
  CSHOP_24_FAMILY = {cost=1000, extraAP=0, kind="FAMILY", countsAsTrip=true},

  CSHOP_25_BALLOON   = {cost=1000, extraAP=1, kind="SAT", sat=4, countsAsTrip=true},
  CSHOP_25_BALOON    = {cost=1000, extraAP=1, kind="SAT", sat=4, countsAsTrip=true}, -- Alias: actual card name has typo (single L)
  CSHOP_26_GRAVITY   = {cost=3000, extraAP=1, kind="SAT", sat=12, countsAsTrip=true}, -- Zero Gravity Flight
  CSHOP_27_BUNGEE    = {cost=1500, extraAP=1, kind="SAT", sat=6, countsAsTrip=true},
  CSHOP_28_PARACHUTE = {cost=2000, extraAP=1, kind="SAT", sat=8, countsAsTrip=true},
}

-- =========================
-- [S9B] HI-TECH DEFINITIONS (moved earlier - see definition above)
-- =========================
-- Note: HI_TECH_DEF is now defined earlier in the file (before attachHiTechInteractiveButton)

-- =========================
-- [S9C] INVESTMENT DEFINITIONS
-- =========================
local INVESTMENT_DEF = {
  -- Lottery 1 (50 WIN)
  ISHOP_01_LOTTERY1 = {cost=50, extraAP=0, kind="LOTTERY1"},
  ISHOP_02_LOTTERY1 = {cost=50, extraAP=0, kind="LOTTERY1"},
  
  -- Lottery 2 (200 WIN)
  ISHOP_03_LOTTERY2 = {cost=200, extraAP=0, kind="LOTTERY2"},
  ISHOP_04_LOTTERY2 = {cost=200, extraAP=0, kind="LOTTERY2"},
  
  -- Property Insurance (NOT IMPLEMENTED YET)
  ISHOP_05_PROPINSURANCE = {cost=500, extraAP=0, kind="PROPINSURANCE"},
  
  -- Real Estate Investment (interactive, will implement later)
  ISHOP_06_ESTATEINVEST = {cost=0, extraAP=0, kind="ESTATEINVEST"}, -- cost determined interactively
  ISHOP_07_ESTATEINVEST = {cost=0, extraAP=0, kind="ESTATEINVEST"},
  
  -- Debentures (interactive, will implement later)
  ISHOP_08_DEBENTURES = {cost=0, extraAP=0, kind="DEBENTURES"}, -- cost determined interactively
  
  -- Health Insurance (NOT IMPLEMENTED YET)
  ISHOP_09_HEALTHINSURANCE = {cost=400, extraAP=0, kind="HEALTHINSURANCE"},
  
  -- Loan (interactive, will implement later)
  ISHOP_10_LOAN = {cost=0, extraAP=0, kind="LOAN"}, -- cost determined interactively
  ISHOP_11_LOAN = {cost=0, extraAP=0, kind="LOAN"},
  
  -- Endowment (interactive, will implement later)
  ISHOP_12_ENDOWMENT = {cost=0, extraAP=0, kind="ENDOWMENT"}, -- cost determined interactively
  
  -- Stock (interactive, will implement later)
  ISHOP_13_STOCK = {cost=0, extraAP=0, kind="STOCK"}, -- cost determined interactively
  ISHOP_14_STOCK = {cost=0, extraAP=0, kind="STOCK"},
}

-- =========================
-- [S10] BUY FLOW (no destruct!)
-- =========================
local function payEntryAPIfNeeded(color)
  -- Normalize color to ensure consistent checking
  color = normalizeColor(color)
  
  -- CAR: If player owns a CAR, shop entry is free
  if ownsHiTechKind(color, "CAR") then
    log("CAR: Shop entry free for "..tostring(color))
    S.boughtThisTurn[color] = true  -- Mark as entered (free)
    return true
  end
  
  if S.boughtThisTurn[color] then return true end
  local ok = apSpend(color, 1, "SHOP_ENTRY")
  if not ok then
    safeBroadcastToColor("⛔ You don't have AP for the first shop purchase (entry cost 1 AP).", color, {1,0.6,0.2})
    return false
  end
  S.boughtThisTurn[color] = true
  return true
end

-- Return purchased card back to deck (or closed slot fallback)
local function stashPurchasedCard(card)
  if not (card and card.tag=="Card") then return end

  local row = classifyRowByName(card)
  if not row then
    local p = card.getPosition()
    pcall(function() card.setPositionSmooth({p.x, p.y + 5, p.z}, false, true) end)
    return
  end

  -- Safety: Hi-Tech should never be stashed here (it is owned/placed near player boards),
  -- but if it happens, fall back to putting it back in the deck.
  if row == "H" then
    local dH = deckForRow("H")
    if dH and dH.tag == "Deck" then
      pcall(function() dH.putObject(card) end)
    end
    return
  end

  -- New behavior (requested):
  -- Used CONSUMABLES/INVESTMENTS go to USED piles (stacked into mini-decks), not back into the deck.
  local g = card.getGUID()
  uiClearButtons(card)
  uiClearDescription(card)
  -- Keep used cards face-up (requested)
  forceFaceUp(card)
  ensureTag(card, TAG_SHOP_USED)
  UI.modalOpen[g] = nil
  UI.homePos[g] = nil
  pendingDice[g] = nil
  diceInitialValue[g] = nil

  -- Separate rows: C next to C, I next to I
  local usedTag = nil
  if row == "C" then usedTag = TAG_SHOP_USED_C end
  if row == "I" then usedTag = TAG_SHOP_USED_I end
  if usedTag then ensureTag(card, usedTag) end

  -- Prefer putting into an existing USED pile deck for this row.
  local usedDeck = nil
  if usedTag then
    for _,o in ipairs(getAllObjects()) do
      if isDeck(o) and o.hasTag and o.hasTag(usedTag) then
        usedDeck = o
        break
      end
    end
  end

  -- Base used pile position (fixed; cards stack into a deck automatically)
  local base = USED_ROW_LOCAL_BY_ROW[row] or { x=10.5, y=0.592, z=0.0 }
  local wp = worldFromLocal(base)
  if not wp then
    local p = card.getPosition()
    pcall(function() card.setPositionSmooth({p.x, p.y + 5, p.z}, false, true) end)
    return
  end

  if usedDeck and usedDeck.tag=="Deck" then
    -- Keep used pile visible and merge card into it.
    forceFaceUpAny(usedDeck)
    pcall(function() usedDeck.putObject(card) end)
    return
  end

  pcall(function()
    card.setPositionSmooth({wp.x, wp.y + USED_ROW_Y_LIFT, wp.z}, false, true)
    if S.desiredYaw then card.setRotationSmooth({0, S.desiredYaw, 0}, false, true) end
    lockBrief(card)
  end)
end

local function applyConsumableEffect(color, card, def, rollValue)
  -- rollValue: optional, if nil and dice needed, show ROLL DICE button instead of auto-rolling
  if def.kind == "SAT" then
    satAdd(color, def.sat or 0)
    return true

  elseif def.kind == "BOOK" then
    statsApply(color, {k=2})
    return true

  elseif def.kind == "MENTORSHIP" then
    statsApply(color, {s=2})
    return true

  elseif def.kind == "SUPPLEMENTS" then
    statsApply(color, {h=2})
    return true

  elseif def.kind == "KARMA" then
    local ok = pscAddStatus(color, TAG_STATUS_GOOD_KARMA)
    if not ok then
      safeBroadcastToColor("⚠️ Failed to add Good Karma (no PSC or error).", color, {1,0.7,0.2})
    end
    return true

  elseif def.kind == "PILLS" then
    -- Check if player is already addicted (treatment attempt)
    local isAlreadyAddicted = pscHasStatus(color, TAG_STATUS_ADDICTION)
    
    -- If rollValue not provided, show ROLL DICE button (don't increment count yet)
    if rollValue == nil then
      -- Calculate threshold based on CURRENT count (before increment)
      local currentCount = S.pillsUseCount[color] or 0
      local nextCount = currentCount + 1  -- What it will be after this use
      local riskThreshold = math.min(nextCount, 6)  -- Threshold for this roll
      
      -- Debug: log the count to verify it's being read correctly
      if DEBUG then
        log("PILLS: "..color.." showing button - currentCount="..currentCount..", nextCount="..nextCount..", threshold="..riskThreshold)
      end
      
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="PILLS", isAlreadyAddicted=isAlreadyAddicted, riskThreshold=riskThreshold }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("💊 Roll the physical die, then click ROLL DICE (risk threshold: 1-"..riskThreshold..")", color, {1,1,0.6})
      return "WAIT_DICE"
    end
    
    -- rollValue provided, process the result (NOW increment count)
    local currentCount = S.pillsUseCount[color] or 0
    S.pillsUseCount[color] = currentCount + 1
    local useCount = S.pillsUseCount[color]
    local riskThreshold = math.min(useCount, 6)
    
    -- Debug: log the count to verify it's incrementing
    if DEBUG then
      log("PILLS: "..color.." useCount="..currentCount.." -> "..useCount.." (threshold="..riskThreshold..")")
    end
    
    -- Add +3 rest-equivalent bonus
    S.restEquivalent[color] = (S.restEquivalent[color] or 0) + 3
    
    local v = rollValue
    if type(v) ~= "number" or v < 1 or v > 6 then
      safeBroadcastToColor("⚠️ PILLS: invalid die value", color, {1,0.7,0.2})
      return false
    end
    
    if isAlreadyAddicted then
      -- Treatment attempt: check if cured
      if v > riskThreshold then
        -- Success: cured! Remove ALL addiction tokens (could be 1, 2, or 3)
        local removed = 0
        for i=1,10 do  -- Remove up to 10 tokens (safety limit)
          local hadToken = pscHasStatus(color, TAG_STATUS_ADDICTION)
          if hadToken then
            pscRemoveStatus(color, TAG_STATUS_ADDICTION)
            removed = removed + 1
          else
            break
          end
        end
        S.pillsUseCount[color] = 0  -- Reset use count on cure
        safeBroadcastAll("✅ "..color.." cured addiction! (removed "..removed.." tokens) (roll="..v..", threshold="..riskThreshold..")", {0.7,1,0.7})
      else
        -- Failed: still addicted (use count continues)
        safeBroadcastAll("❌ "..color.." failed to cure addiction (roll="..v..", threshold="..riskThreshold..")", {1,0.6,0.2})
      end
    else
      -- Normal use: check addiction risk
      if v <= riskThreshold then
        -- Addicted! Add 3 ADDICTION tokens (each token = 1 AP loss per turn)
        -- Token Engine now supports multiple ADDICTION tokens (array storage)
        for i=1,3 do
          pscAddStatus(color, TAG_STATUS_ADDICTION)
        end
        
        safeBroadcastAll("⚠️ "..color.." became ADDICTED to Anti-Sleeping Pills! (added 3 ADDICTION tokens - loses 3/2/1 AP consecutively) (roll="..v..", threshold="..riskThreshold..")", {1,0.5,0.2})
      else
        -- Safe (no addiction)
        safeBroadcastAll("✅ "..color.." safely used PILLS (roll="..v..", threshold="..riskThreshold..")", {0.7,1,0.7})
      end
    end
    
    return true

  elseif def.kind == "NATURE_TRIP" then
    -- Add +3 rest-equivalent bonus
    S.restEquivalent[color] = (S.restEquivalent[color] or 0) + 3
    
    -- If rollValue not provided, show ROLL DICE button
    if rollValue == nil then
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="NATURE_TRIP" }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("🌿 Roll the physical die, then click ROLL DICE", color, {0.7,1,0.7})
      return "WAIT_DICE"
    end
    
    -- rollValue provided, process the result
    local v = rollValue
    if type(v) == "number" and v >= 1 and v <= 6 then
      satAdd(color, v)
      safeBroadcastAll("🎲 Nature Trip: "..color.." +SAT "..v, {0.8,0.9,1})
    else
      safeBroadcastAll("⚠️ Nature Trip: invalid die value", {1,0.7,0.2})
    end
    return true

  elseif def.kind == "FAMILY" then
    -- If rollValue not provided, show ROLL DICE button
    if rollValue == nil then
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="FAMILY" }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("👶 Roll the physical die, then click ROLL DICE", color, {0.9,0.9,0.9})
      return "WAIT_DICE"
    end
    
    -- rollValue provided, process the result
    local v = rollValue
    if type(v) ~= "number" or v < 1 or v > 6 then
      safeBroadcastAll("⚠️ Family Center: invalid die value", {1,0.7,0.2})
      return false
    end
    
    if v <= 2 then
      safeBroadcastAll("👶 "..color..": not this time.", {0.9,0.9,0.9})
    elseif v <= 4 then
      pscAddChild(color, "BOY")
      -- Block 2 AP: move 2 free AP to INACTIVE when child is born
      local ap = resolveAP(color)
      if ap and ap.call then
        pcall(function() ap.call("moveAP", {to="INACTIVE", amount=2}) end)
      end
      safeBroadcastAll("👶 "..color..": It's a BOY! (2 AP blocked to INACTIVE)", {0.7,0.9,1})
    else
      pscAddChild(color, "GIRL")
      -- Block 2 AP: move 2 free AP to INACTIVE when child is born
      local ap = resolveAP(color)
      if ap and ap.call then
        pcall(function() ap.call("moveAP", {to="INACTIVE", amount=2}) end)
      end
      safeBroadcastAll("👶 "..color..": It's a GIRL! (2 AP blocked to INACTIVE)", {1,0.7,0.9})
    end
    
    -- Add baby cost to cost calculator (Family Planning Center: 150 per turn)
    Costs_add(color, 150)
    log("Baby cost (Family Planning): "..color.." added 150 WIN per turn for baby")
    
    return true

  elseif def.kind == "CURE" then
    local hasS = pscHasStatus(color, TAG_STATUS_SICK)
    local hasW = pscHasStatus(color, TAG_STATUS_WOUNDED)

    if not (hasS or hasW) then
      safeBroadcastToColor("🩺 Cure: you don't have SICK/WOUNDED → no effect.", color, {0.9,0.9,0.9})
      return true
    end

    -- If rollValue not provided, show ROLL DICE button
    if rollValue == nil then
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="CURE", hasS=hasS, hasW=hasW }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("🩺 Roll the physical die, then click ROLL DICE", color, {0.7,1,0.7})
      return "WAIT_DICE"
    end

    -- rollValue provided, process the result
    local v = rollValue
    if type(v) ~= "number" or v < 1 or v > 6 then
      safeBroadcastToColor("⚠️ Cure: invalid die value", color, {1,0.7,0.2})
      return false
    end

    if v == 1 then
      safeBroadcastToColor("🩺 Cure failed (roll=1).", color, {1,0.6,0.2})
      return true
    end

    if v <= 4 then
      local okAP = apSpend(color, 1, "CURE_DELAY")
      if not okAP then
        safeBroadcastToColor("⛔ Cure (roll="..v..") requires 1 AP, but failed to deduct → no healing.", color, {1,0.6,0.2})
        return false
      end
    end

    if hasS then
      pscRemoveStatus(color, TAG_STATUS_SICK)
      safeBroadcastToColor("✅ "..color.." cured SICK (roll="..v..")", color, {0.7,1,0.7})
    else
      pscRemoveStatus(color, TAG_STATUS_WOUNDED)
      safeBroadcastToColor("✅ "..color.." cured WOUNDED (roll="..v..")", color, {0.7,1,0.7})
    end

    statsApply(color, {h=3})
    return true
  end

  safeBroadcastToColor("ℹ️ (WIP) No effect for: "..tostring(getNameSafe(card)), color, {0.9,0.9,1})
  return true
end

-- =========================
-- [S9D] INVESTMENT EFFECTS
-- =========================
local function applyInvestmentEffect(color, card, def, rollValue)
  -- rollValue: optional, if nil and dice needed, show ROLL DICE button instead of auto-rolling
  
  if def.kind == "LOTTERY1" then
    -- Lottery 1: Roll D6, 1-4 = lose, 5 = win 100, 6 = win 500
    if rollValue == nil then
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="LOTTERY1", cardType="INVESTMENT" }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("🎲 Lottery Ticket 1: Roll the physical die, then click ROLL DICE", color, {0.9,0.8,0.6})
      return "WAIT_DICE"
    end
    
    -- rollValue provided, process the result
    local v = rollValue
    if type(v) ~= "number" or v < 1 or v > 6 then
      safeBroadcastAll("⚠️ Lottery 1: invalid die value", {1,0.7,0.2})
      return false
    end
    
    if v >= 1 and v <= 4 then
      -- Lose (no reward)
      safeBroadcastAll("❌ "..color.." Lottery 1: No win! (roll="..v..")", {0.9,0.7,0.7})
    elseif v == 5 then
      -- Win 100 WIN
      local ok = moneyAdd(color, 100)
      if ok then
        safeBroadcastAll("🎉 "..color.." Lottery 1: Won 100 WIN! (roll="..v..")", {0.9,1,0.6})
      else
        safeBroadcastAll("⚠️ Lottery 1: Failed to add 100 WIN", {1,0.7,0.2})
      end
    elseif v == 6 then
      -- Win 500 WIN
      local ok = moneyAdd(color, 500)
      if ok then
        safeBroadcastAll("🎉🎉 "..color.." Lottery 1: Won 500 WIN! (roll="..v..")", {0.9,1,0.6})
      else
        safeBroadcastAll("⚠️ Lottery 1: Failed to add 500 WIN", {1,0.7,0.2})
      end
    end
    return true

  elseif def.kind == "LOTTERY2" then
    -- Lottery 2: Roll D6, 1-3 = lose, 4 = win 300, 5 = win 500, 6 = win 1000
    if rollValue == nil then
      local g = card.getGUID()
      pendingDice[g] = { color=color, def=def, card=card, kind="LOTTERY2", cardType="INVESTMENT" }
      uiAttachRollDiceButton(card)
      safeBroadcastToColor("🎲 Lottery Ticket 2: Roll the physical die, then click ROLL DICE", color, {0.9,0.8,0.6})
      return "WAIT_DICE"
    end
    
    -- rollValue provided, process the result
    local v = rollValue
    if type(v) ~= "number" or v < 1 or v > 6 then
      safeBroadcastAll("⚠️ Lottery 2: invalid die value", {1,0.7,0.2})
      return false
    end
    
    if v >= 1 and v <= 3 then
      -- Lose (no reward)
      safeBroadcastAll("❌ "..color.." Lottery 2: No win! (roll="..v..")", {0.9,0.7,0.7})
    elseif v == 4 then
      -- Win 300 WIN
      local ok = moneyAdd(color, 300)
      if ok then
        safeBroadcastAll("🎉 "..color.." Lottery 2: Won 300 WIN! (roll="..v..")", {0.9,1,0.6})
      else
        safeBroadcastAll("⚠️ Lottery 2: Failed to add 300 WIN", {1,0.7,0.2})
      end
    elseif v == 5 then
      -- Win 500 WIN
      local ok = moneyAdd(color, 500)
      if ok then
        safeBroadcastAll("🎉 "..color.." Lottery 2: Won 500 WIN! (roll="..v..")", {0.9,1,0.6})
      else
        safeBroadcastAll("⚠️ Lottery 2: Failed to add 500 WIN", {1,0.7,0.2})
      end
    elseif v == 6 then
      -- Win 1000 WIN
      local ok = moneyAdd(color, 1000)
      if ok then
        safeBroadcastAll("🎉🎉 "..color.." Lottery 2: Won 1,000 WIN! (roll="..v..")", {0.9,1,0.6})
      else
        safeBroadcastAll("⚠️ Lottery 2: Failed to add 1,000 WIN", {1,0.7,0.2})
      end
    end
    return true

  elseif def.kind == "PROPINSURANCE" or def.kind == "HEALTHINSURANCE" then
    -- NOT IMPLEMENTED YET
    safeBroadcastToColor("⛔ "..def.kind.." is not yet implemented", color, {1,0.6,0.2})
    return false

  elseif def.kind == "DEBENTURES" or def.kind == "LOAN" or def.kind == "ENDOWMENT" or def.kind == "ESTATEINVEST" or def.kind == "STOCK" then
    -- Interactive cards: need player input before purchase
    -- Return special status to trigger interactive UI
    return "NEED_INPUT"
  else
    safeBroadcastToColor("ℹ️ (WIP) Investment card type "..tostring(def.kind).." not yet implemented", color, {0.9,0.9,1})
    return false
  end
end

-- =========================
-- [S9E] INVESTMENT PROCESSING FUNCTIONS
-- =========================
local function processDebenturesPurchase(color, card, amount, amountToCharge)
  -- DEBENTURES: Pay same amount for 3 turns, get 200% back (100% profit) after 3 turns
  -- amountToCharge: optional (NGO perk); if provided, charge this instead of amount for first payment
  color = normalizeColor(color)
  local charge = amount
  if type(amountToCharge) == "number" and amountToCharge >= 0 then charge = amountToCharge end
  
  -- Charge initial payment (may be 0 with NGO subsidy)
  local okMoney = moneySpend(color, charge)
  if not okMoney then
    safeBroadcastToColor("⛔ Not enough funds (WIN) for Debentures investment of "..tostring(amount).." WIN", color, {1,0.6,0.2})
    return false
  end
  
  -- Add first payment to cost calculator
  Costs_add(color, amount)
  log("Debentures: "..color.." added "..amount.." WIN to cost calculator (payment 1/3)")
  
  -- Store investment state
  if not S.investments[color] then S.investments[color] = {} end
  local cardGUID = card.getGUID()
  S.investments[color].debentures = {
    cardGUID = cardGUID,
    investedPerTurn = amount,
    paidCount = 1,  -- First payment already made
    totalInvested = amount,
  }
  
  -- Ensure card stays lifted when showing buttons
  local homePos = UI.homePos[cardGUID]
  if homePos then
    pcall(function()
      card.setLock(false)
      local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
      card.setPositionSmooth(liftPos, false, true)
    end)
  end
  
  -- Give card to player with buttons
  pcall(function()
    card.addTag(colorTag(color))
    card.addTag("WLB_INVESTMENT")
  end)
  
  -- Attach cash out button
  pcall(function()
    card.createButton({
      click_function = "inv_debentures_cashOut",
      function_owner = self,
      label = "TAKE OUT\nCASH NOW",
      position = {0, 0.33, 1.0},
      rotation = {0, 0, 0},
      width = 800,
      height = 300,
      font_size = 130,
      color = {0.7, 0.5, 0.2, 0.95},
      font_color = {1, 1, 1, 1},
      tooltip = "Take out invested amount (no profit)",
    })
  end)
  
  giveCardToPlayer(card, color)
  safeBroadcastToColor("💰 Debentures: Invested "..tostring(amount).." WIN (will pay "..tostring(amount).." WIN for 2 more turns, then receive "..tostring(amount * 6).." WIN total)", color, {0.8,0.9,1})
  return true
end

local function processLoanPurchase(color, card, amount)
  -- LOAN: Borrow amount, pay 4 instalments of 33% each
  color = normalizeColor(color)
  
  -- Loan doesn't charge money (player receives it)
  local okMoney = moneyAdd(color, amount)
  if not okMoney then
    safeBroadcastToColor("⚠️ Failed to add loan amount to account", color, {1,0.7,0.2})
    return false
  end
  
  -- Calculate instalment (33% of borrowed amount)
  local instalmentAmount = math.floor(amount * 0.33)
  
  -- Store loan state (payments start next turn)
  if not S.investments[color] then S.investments[color] = {} end
  S.investments[color].loan = {
    amountBorrowed = amount,
    instalmentAmount = instalmentAmount,
    paidInstalments = 0,  -- Payments start next turn
  }
  
  -- Card is not kept (loan is just a transaction)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.05)
  
  safeBroadcastToColor("💰 Loan: Borrowed "..tostring(amount).." WIN. Will pay "..tostring(instalmentAmount).." WIN per turn for 4 turns (starting next turn)", color, {0.8,0.9,1})
  return true
end

local function processStockPurchase(color, card, amount, amountToCharge)
  -- STOCK: Pay investment, then automatically roll first die. amountToCharge: optional (NGO perk)
  color = normalizeColor(color)
  local charge = amount
  if type(amountToCharge) == "number" and amountToCharge >= 0 then charge = amountToCharge end
  
  -- Charge investment (may be 0 with NGO subsidy)
  local okMoney = moneySpend(color, charge)
  if not okMoney then
    safeBroadcastToColor("⛔ Not enough funds (WIN) for Stock investment of "..tostring(amount).." WIN", color, {1,0.6,0.2})
    return false
  end
  
  -- Store stock state
  if not S.investments[color] then S.investments[color] = {} end
  local cardGUID = card.getGUID()
  S.investments[color].stock = {
    cardGUID = cardGUID,
    investmentAmount = amount,
    firstRoll = nil,
    secondRoll = nil,
    resolved = false,
  }
  
  -- Ensure card stays lifted
  local homePos = UI.homePos[cardGUID]
  if homePos then
    pcall(function()
      card.setLock(false)
      local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
      card.setPositionSmooth(liftPos, false, true)
    end)
  end
  
  -- Give card to player
  pcall(function()
    card.addTag(colorTag(color))
    card.addTag("WLB_INVESTMENT")
  end)
  
  -- Clear buttons and show "Rolling..." message
  uiClearButtons(card)
  uiSetDescription(card, "Rolling first die...")
  safeBroadcastToColor("💰 Stock: Invested "..tostring(amount).." WIN. Rolling first die...", color, {0.8,0.9,1})
  
  -- Automatically roll first die
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", color, {1,0.6,0.2})
    -- Return money if die not found
    moneyAdd(color, amount)
    return false
  end
  
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  -- Wait for die to settle
  local timeout = os.time() + 6
  Wait.condition(
    function()
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", color, {1,0.7,0.3})
        -- Return money if can't read die
        moneyAdd(color, amount)
        return
      end
      
      -- Store first roll
      S.investments[color].stock.firstRoll = v
      safeBroadcastAll("🎲 "..color.." Stock: First roll = "..v, {0.8,0.9,1})
      
      -- Show result and Yes/No buttons
      uiSetDescription(card, "First die: "..v.."\nDo you want to continue?")
      pcall(function()
        card.clearButtons()
        card.createButton({
          click_function = "inv_stock_continueYes",
          function_owner = self,
          label = "YES\n(Roll Second)",
          position = {-0.4, 0.33, 1.0},
          rotation = {0, 0, 0},
          width = 700,
          height = 300,
          font_size = 120,
          color = {0.2, 0.8, 0.2, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "Continue and roll second die",
        })
        card.createButton({
          click_function = "inv_stock_continueNo",
          function_owner = self,
          label = "NO\n(Return Money)",
          position = {0.4, 0.33, 1.0},
          rotation = {0, 0, 0},
          width = 700,
          height = 300,
          font_size = 120,
          color = {0.8, 0.2, 0.2, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "Cancel and get investment back",
        })
      end)
    end,
    function()
      local resting = false
      pcall(function() resting = die.resting end)
      if resting then return true end
      if os.time() >= timeout then return true end
      return false
    end
  )
  
  return true
end

local function processEndowmentPurchase(color, card, amount, duration, amountToCharge)
  -- ENDOWMENT: Pay same amount per year for chosen duration, get profit after duration
  -- amountToCharge: optional (NGO perk); if provided, charge this instead of amount for first payment
  color = normalizeColor(color)
  local charge = amount
  if type(amountToCharge) == "number" and amountToCharge >= 0 then charge = amountToCharge end
  
  -- Charge first payment (same turn; may be 0 with NGO subsidy)
  local okMoney = moneySpend(color, charge)
  if not okMoney then
    safeBroadcastToColor("⛔ Not enough funds (WIN) for Endowment investment of "..tostring(amount).." WIN", color, {1,0.6,0.2})
    return false
  end
  
  -- Add first payment to cost calculator
  Costs_add(color, amount)
  log("Endowment: "..color.." added "..amount.." WIN to cost calculator (payment 1/"..duration..")")
  
  -- Store investment state
  if not S.investments[color] then S.investments[color] = {} end
  local cardGUID = card.getGUID()
  S.investments[color].endowment = {
    cardGUID = cardGUID,
    duration = duration,
    amountPerYear = amount,
    paidCount = 1,  -- First payment already made
    totalInvested = amount,
  }
  
  -- Ensure card stays lifted when giving to player
  local homePos = UI.homePos[cardGUID]
  if homePos then
    pcall(function()
      card.setLock(false)
      local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
      card.setPositionSmooth(liftPos, false, true)
    end)
  end
  
  -- Give card to player (button will appear after duration complete)
  pcall(function()
    card.addTag(colorTag(color))
    card.addTag("WLB_INVESTMENT")
  end)
  
  giveCardToPlayer(card, color)
  
  local profitPct = (duration == 2 and 50) or (duration == 3 and 125) or 200
  safeBroadcastToColor("💰 Endowment: Invested "..tostring(amount).." WIN per year for "..duration.." years ("..profitPct.."% profit). Will pay "..tostring(amount).." WIN for "..(duration-1).." more turns", color, {0.8,0.9,1})
  return true
end

local function processEstateInvestPurchase(color, card, level, totalPrice, paymentMethod, subsidy)
  -- ESTATEINVEST: Real estate investment with payment options. subsidy: optional (NGO perk, up to 1000 VIN)
  color = normalizeColor(color)
  subsidy = (type(subsidy) == "number" and subsidy > 0) and subsidy or 0
  
  local costsCalc = firstWithTag(TAG_COSTS_CALC)
  
  if paymentMethod == "60pct" then
    -- Pay 60% now
    local payment60pct = math.floor(totalPrice * 0.6)
    local effectivePayment = math.max(0, payment60pct - subsidy)
    local okMoney = moneySpend(color, effectivePayment)
    if not okMoney then
      safeBroadcastToColor("⛔ Not enough funds (WIN) for 60% payment: "..tostring(payment60pct).." WIN", color, {1,0.6,0.2})
      return false
    end
    
    -- Store investment state (apartment delivered next turn)
    if not S.investments[color] then S.investments[color] = {} end
    S.investments[color].estateInvest = {
      level = level,
      totalValue = totalPrice,
      method = "60pct",
      paidCount = 1,  -- 1 payment made (60%)
      paidAmount = payment60pct,
      deliveryPending = true,  -- Deliver on next turn
    }
    
    safeBroadcastToColor("🏠 Estate Investment: Paid 60% ("..tostring(payment60pct).." WIN) for "..level..". Apartment will be delivered next turn.", color, {0.8,0.9,1})
    
  elseif paymentMethod == "3x30pct" then
    -- Pay 30% now, 30% next turn, 30% third turn
    local payment30pct = math.floor(totalPrice * 0.3)
    local effectivePayment = math.max(0, payment30pct - subsidy)
    local okMoney = moneySpend(color, effectivePayment)
    if not okMoney then
      safeBroadcastToColor("⛔ Not enough funds (WIN) for first 30% payment: "..tostring(payment30pct).." WIN", color, {1,0.6,0.2})
      return false
    end
    
    -- Store investment state (apartment delivered next turn, payments continue)
    -- NOTE: Remaining payments (2/3 and 3/3) will be added by API_processInvestmentPayments
    -- one payment per turn, NOT all at once
    if not S.investments[color] then S.investments[color] = {} end
    S.investments[color].estateInvest = {
      level = level,
      totalValue = totalPrice,
      method = "3x30pct",
      paidCount = 1,  -- 1 payment made (30%) - first payment already paid
      paidAmount = payment30pct,
      paymentAmount = payment30pct,  -- Amount per payment
      deliveryPending = true,  -- Deliver on next turn
    }
    
    safeBroadcastToColor("🏠 Estate Investment: Paid 30% ("..tostring(payment30pct).." WIN) for "..level..". Will pay "..tostring(payment30pct).." WIN for 2 more turns (one per turn). Apartment will be delivered next turn.", color, {0.8,0.9,1})
  else
    safeBroadcastToColor("⛔ Invalid payment method", color, {1,0.6,0.2})
    return false
  end
  
  -- Stash the investment card (it's not kept by player)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.3)
  
  return true
end

-- ENDOWMENT duration choice handlers (separate for each duration)
function inv_endowment_2years(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ENDOWMENT" then return end
  pending.duration = 2
  uiAttachCounter(card, 0, 50, 50)
  safeBroadcastToColor("💰 Endowment: 2 years chosen (50% profit). Choose investment amount per year", player_color, {0.8,0.9,1})
end

function inv_endowment_3years(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ENDOWMENT" then return end
  pending.duration = 3
  uiAttachCounter(card, 0, 50, 50)
  safeBroadcastToColor("💰 Endowment: 3 years chosen (125% profit). Choose investment amount per year", player_color, {0.8,0.9,1})
end

function inv_endowment_4years(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ENDOWMENT" then return end
  pending.duration = 4
  uiAttachCounter(card, 0, 50, 50)
  safeBroadcastToColor("💰 Endowment: 4 years chosen (200% profit). Choose investment amount per year", player_color, {0.8,0.9,1})
end

-- ESTATEINVEST apartment level choice handlers
function inv_estateinvest_L1(card, player_color, alt_click)
  inv_estateinvest_chooseLevel(card, player_color, "L1", 2000)
end

function inv_estateinvest_L2(card, player_color, alt_click)
  inv_estateinvest_chooseLevel(card, player_color, "L2", 3500)
end

function inv_estateinvest_L3(card, player_color, alt_click)
  inv_estateinvest_chooseLevel(card, player_color, "L3", 5500)
end

function inv_estateinvest_L4(card, player_color, alt_click)
  inv_estateinvest_chooseLevel(card, player_color, "L4", 10000)
end

function inv_estateinvest_chooseLevel(card, player_color, level, price)
  if not (card and card.tag=="Card") then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ESTATEINVEST" then return end
  
  pending.apartmentLevel = level
  pending.apartmentPrice = price
  
  -- Ensure card stays lifted when showing payment method choice
  local homePos = UI.homePos[g]
  if homePos then
    pcall(function()
      card.setLock(false)
      local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
      card.setPositionSmooth(liftPos, false, true)
    end)
  end
  
  -- Show payment method choice (vertical layout using Z coordinates)
  -- In TTS, "below" is achieved by Z coordinate, not Y
  uiClearButtons(card)
  local price60pct = math.floor(price * 0.6)
  local price30pct = math.floor(price * 0.3)
  
  local PAYMENT_BTN_Y = 0.16  -- Y position for all payment buttons
  local PAYMENT_BTN_Z_START = 0.75  -- Top button Z position (same as level buttons)
  local PAYMENT_BTN_Z_SPACING = -0.53  -- Spacing between buttons (same as level buttons)
  
  card.createButton({
    click_function = "inv_estateinvest_60pct",
    function_owner = self,
    label = "PAY 60% NOW\n("..tostring(price60pct).." WIN)",
    position = {0, PAYMENT_BTN_Y, PAYMENT_BTN_Z_START},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.8,
    height = UI_BTN_H * 0.8,
    font_size = UI_BTN_FONT * 0.6,
    color = {0.2, 0.85, 0.25, 1.0},
    font_color = {1, 1, 1, 1},
    tooltip = "Pay 60% now, get apartment next turn",
  })
  card.createButton({
    click_function = "inv_estateinvest_3x30pct",
    function_owner = self,
    label = "3× PAYMENTS\n(30% each = "..tostring(price30pct).." WIN)",
    position = {0, PAYMENT_BTN_Y, PAYMENT_BTN_Z_START + PAYMENT_BTN_Z_SPACING},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.8,
    height = UI_BTN_H * 0.8,
    font_size = UI_BTN_FONT * 0.6,
    color = {0.3, 0.6, 0.9, 1.0},
    font_color = {1, 1, 1, 1},
    tooltip = "Pay 30% now, 30% next turn, 30% third turn. Get apartment next turn.",
  })
  uiSetDescription(card, level.." ("..tostring(price).." WIN): Choose payment method")
  safeBroadcastToColor("🏠 ESTATEINVEST: "..level.." chosen ("..tostring(price).." WIN). Choose payment method", player_color, {0.8,0.9,1})
end

function inv_estateinvest_60pct(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ESTATEINVEST" then return end
  pending.paymentMethod = "60pct"
  local subsidy = (pending.ngoSubsidy and type(pending.ngoSubsidy) == "number" and pending.ngoSubsidy > 0) and pending.ngoSubsidy or 0
  if subsidy > 0 then
    local voc = firstWithTag(TAG_VOCATIONS_CTRL)
    if voc and voc.call then pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = pending.color }) end) end
  end
  local success = processEstateInvestPurchase(pending.color, card, pending.apartmentLevel, pending.apartmentPrice, "60pct", subsidy)
  if success then
    -- Purchase succeeded: clear state and buttons
    pendingInvestment[g] = nil
    uiClearButtons(card)
  else
    -- Purchase failed (insufficient funds): show Resign button
    showEstateInvestResignButton(card, pending)
  end
end

function inv_estateinvest_3x30pct(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ESTATEINVEST" then return end
  pending.paymentMethod = "3x30pct"
  local subsidy = (pending.ngoSubsidy and type(pending.ngoSubsidy) == "number" and pending.ngoSubsidy > 0) and pending.ngoSubsidy or 0
  if subsidy > 0 then
    local voc = firstWithTag(TAG_VOCATIONS_CTRL)
    if voc and voc.call then pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = pending.color }) end) end
  end
  local success = processEstateInvestPurchase(pending.color, card, pending.apartmentLevel, pending.apartmentPrice, "3x30pct", subsidy)
  if success then
    -- Purchase succeeded: clear state and buttons
    pendingInvestment[g] = nil
    uiClearButtons(card)
  else
    -- Purchase failed (insufficient funds): show Resign button
    showEstateInvestResignButton(card, pending)
  end
end

-- Show Resign button when estate investment payment fails
local function showEstateInvestResignButton(card, pending)
  if not (card and card.tag=="Card") then return end
  local g = card.getGUID()
  
  -- Clear existing buttons
  uiClearButtons(card)
  
  -- Show Resign button
  local PAYMENT_BTN_Y = 0.16
  local RESIGN_BTN_Z = 0.75 - (0.53 * 2)  -- Below both payment buttons
  
  card.createButton({
    click_function = "inv_estateinvest_resign",
    function_owner = self,
    label = "RESIGN",
    position = {0, PAYMENT_BTN_Y, RESIGN_BTN_Z},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.8,
    height = UI_BTN_H * 0.8,
    font_size = UI_BTN_FONT * 0.6,
    color = {0.85, 0.2, 0.2, 1.0},  -- Red color
    font_color = {1, 1, 1, 1},
    tooltip = "Cancel this investment and return card to shop",
  })
  
  -- Keep payment buttons visible (player might add funds and retry)
  local price60pct = math.floor(pending.apartmentPrice * 0.6)
  local price30pct = math.floor(pending.apartmentPrice * 0.3)
  local PAYMENT_BTN_Z_START = 0.75
  local PAYMENT_BTN_Z_SPACING = -0.53
  
  card.createButton({
    click_function = "inv_estateinvest_60pct",
    function_owner = self,
    label = "PAY 60% NOW\n("..tostring(price60pct).." WIN)",
    position = {0, PAYMENT_BTN_Y, PAYMENT_BTN_Z_START},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.8,
    height = UI_BTN_H * 0.8,
    font_size = UI_BTN_FONT * 0.6,
    color = {0.2, 0.85, 0.25, 1.0},
    font_color = {1, 1, 1, 1},
    tooltip = "Pay 60% now, get apartment next turn",
  })
  card.createButton({
    click_function = "inv_estateinvest_3x30pct",
    function_owner = self,
    label = "3× PAYMENTS\n(30% each = "..tostring(price30pct).." WIN)",
    position = {0, PAYMENT_BTN_Y, PAYMENT_BTN_Z_START + PAYMENT_BTN_Z_SPACING},
    rotation = {0, 0, 0},
    width = UI_BTN_W * 0.8,
    height = UI_BTN_H * 0.8,
    font_size = UI_BTN_FONT * 0.6,
    color = {0.3, 0.6, 0.9, 1.0},
    font_color = {1, 1, 1, 1},
    tooltip = "Pay 30% now, 30% next turn, 30% third turn. Get apartment next turn.",
  })
  
  uiSetDescription(card, pending.apartmentLevel.." ("..tostring(pending.apartmentPrice).." WIN): Insufficient funds. Add money and try again, or click RESIGN to cancel.")
end

-- Resign from estate investment (cancel and reset card)
function inv_estateinvest_resign(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending or pending.kind ~= "ESTATEINVEST" then return end
  
  local color = normalizeColor(pending.color)
  safeBroadcastToColor("🏠 Estate Investment cancelled for "..tostring(pending.apartmentLevel).." apartment.", color, {0.8,0.8,0.8})
  
  -- Clear pending state
  pendingInvestment[g] = nil
  
  -- Clear buttons
  uiClearButtons(card)
  
  -- Reset card description
  uiSetDescription(card, "")
  
  -- Return card to its original position (lower it back)
  local homePos = UI.homePos[g]
  if homePos then
    pcall(function()
      card.setLock(false)
      card.setPositionSmooth(homePos, false, true)
    end)
  end
end

local function attemptBuyCard(card, buyerColor, options)
  options = options or {}
  if not isCard(card) then return false end
  if not isShopOpenSlotCard(card) then
    safeBroadcastToColor("⛔ This card is no longer in an OPEN shop slot.", buyerColor, {1,0.6,0.2})
    return false
  end

  local name = getNameSafe(card)
  local row = classifyRowByName(card)

  local def = nil
  if row == "C" then
    def = CONSUMABLE_DEF[name]
    if not def then
      safeBroadcastToColor("⛔ Unknown CONSUMABLE card: "..tostring(name), buyerColor, {1,0.6,0.2})
      return false
    end
  elseif row == "H" then
    def = HI_TECH_DEF[name]
    if not def then
      safeBroadcastToColor("⛔ Unknown HI-TECH card: "..tostring(name), buyerColor, {1,0.6,0.2})
      return false
    end
  elseif row == "I" then
    def = INVESTMENT_DEF[name]
    if not def then
      safeBroadcastToColor("⛔ Unknown INVESTMENT card: "..tostring(name), buyerColor, {1,0.6,0.2})
      return false
    end
  else
    safeBroadcastToColor("⛔ Unknown card type (not C/H/I).", buyerColor, {1,0.6,0.2})
    return false
  end

  if not payEntryAPIfNeeded(buyerColor) then return false end

  if (def.extraAP or 0) > 0 then
    local okAP = apSpend(buyerColor, def.extraAP, "SHOP_CARD_EXTRA")
    if not okAP then
      safeBroadcastToColor("⛔ Not enough AP for card cost ("..def.extraAP.." AP).", buyerColor, {1,0.6,0.2})
      return false
    end
  end

  -- Voucher discount: 25% per token for C/H (options.discountTokens, options.voucherTag)
  local cost = def.cost or 0
  local discountTokens = (row == "C" or row == "H") and options.discountTokens and options.voucherTag and math.max(0, math.min(4, math.floor(tonumber(options.discountTokens) or 0))) or 0
  if discountTokens > 0 then
    cost = math.max(0, math.floor(cost * (1 - 0.25 * discountTokens)))
  end

  -- NGO Crowdfunding: if buying Hi-Tech, apply crowdfund pool (same turn only); player pays only the difference if cost > pool.
  if row == "H" then
    local voc = firstWithTag(TAG_VOCATIONS_CTRL)
    if voc and voc.call then
      local ok, result = pcall(function() return voc.call("VOC_ApplyCrowdfundPoolForPurchase", { color = buyerColor, cost = cost }) end)
      if ok and result and type(result) == "table" and result.playerPays ~= nil then
        cost = tonumber(result.playerPays) or cost
      end
    end
  end

  -- NGO Worker L3: Use Investment (free, up to 1000 VIN) – apply subsidy to initial cost before charging (for row I).
  local costBeforeSubsidy = cost
  if row == "I" then
    local voc = firstWithTag(TAG_VOCATIONS_CTRL)
    if voc and voc.call then
      local ok, subsidy = pcall(function() return voc.call("VOC_GetNGOInvestmentSubsidy", { color = buyerColor }) end)
      if ok and subsidy ~= nil then
        subsidy = tonumber(subsidy) or 0
        if subsidy > 0 and cost > 0 then
          cost = math.max(0, cost - subsidy)
        end
      end
    end
  end

  local okMoney = moneySpend(buyerColor, cost)
  if not okMoney then
    safeBroadcastToColor("⛔ Not enough funds (WIN) to purchase this card.", buyerColor, {1,0.6,0.2})
    return false
  end

  -- NGO Worker L3: if we applied subsidy to the initial charge (row I), consume the perk now.
  if row == "I" and cost < costBeforeSubsidy and costBeforeSubsidy > 0 then
    local voc = firstWithTag(TAG_VOCATIONS_CTRL)
    if voc and voc.call then
      pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = buyerColor }) end)
    end
  end

  -- Handle Hi-Tech cards (permanent items)
  if row == "H" then
    -- Normalize buyerColor to ensure consistent storage (e.g., "Red", "red", "RED" -> "Red")
    buyerColor = normalizeColor(buyerColor)
    -- Add to ownership tracking
    if not S.ownedHiTech[buyerColor] then S.ownedHiTech[buyerColor] = {} end
    table.insert(S.ownedHiTech[buyerColor], name)
    
    -- Apply immediate effects (COFFEE, etc.)
    applyHiTechEffect(buyerColor, name, def)
    
    -- Give card to player - place at fixed position near player board
    giveCardToPlayer(card, buyerColor)
    
    if options.discountTokens and options.voucherTag and options.discountTokens > 0 then
      pscRemoveStatusCount(buyerColor, options.voucherTag, options.discountTokens)
      safeBroadcastToColor("🛒 Purchased: "..tostring(name).." (Hi-Tech) with "..tostring(options.discountTokens).."× discount", buyerColor, {0.8,0.9,1})
    else
      safeBroadcastToColor("🛒 Purchased: "..tostring(name).." (Hi-Tech)", buyerColor, {0.8,0.9,1})
    end
    return true
  end

  -- Handle Investment cards
  if row == "I" then
    -- Check if card needs interactive input (counter/choice)
    local effectResult = applyInvestmentEffect(buyerColor, card, def)
    
    -- If dice needed, card will be stashed after dice roll (don't stash yet)
    if effectResult == "WAIT_DICE" then
      safeBroadcastToColor("🛒 Purchased: "..tostring(name).." - Roll the die, then click ROLL DICE", buyerColor, {0.8,0.9,1})
      return true
    end
    
    -- If interactive input needed, show counter/choice UI (don't charge money yet)
    if effectResult == "NEED_INPUT" then
      local g = card.getGUID()
      buyerColor = normalizeColor(buyerColor)
      -- NGO Worker L3: Use Investment (free, up to 1000 VIN) – subsidy applied when they confirm amount
      local ngoSubsidy = 0
      local voc = firstWithTag(TAG_VOCATIONS_CTRL)
      if voc and voc.call then
        local ok, result = pcall(function() return voc.call("VOC_GetNGOInvestmentSubsidy", { color = buyerColor }) end)
        if ok and result ~= nil then
          local num = tonumber(result)
          if num and num > 0 then ngoSubsidy = num end
        end
      end
      
      -- Keep card lifted (don't return to slot yet)
      -- Clear YES/NO buttons but keep card in lifted position
      uiClearButtons(card)
      -- Ensure card stays lifted for interactive UI
      local homePos = UI.homePos[g]
      if homePos then
        pcall(function()
          card.setLock(false)  -- Unlock for button interaction
          -- Keep card at lifted position
          local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
          card.setPositionSmooth(liftPos, false, true)
        end)
      end
      
      -- Initialize pending investment state
      pendingInvestment[g] = {
        color = buyerColor,
        def = def,
        card = card,
        kind = def.kind,
        counterValue = 0,  -- For DEBENTURES, LOAN, STOCK
        minAmount = 50,    -- Minimum investment
        increment = 50,    -- Increment per click
        ngoSubsidy = ngoSubsidy,
      }
      
      -- Show counter UI (for DEBENTURES, LOAN, STOCK)
      if def.kind == "DEBENTURES" or def.kind == "LOAN" or def.kind == "STOCK" then
        uiAttachCounter(card, 0, 50, 50)
        safeBroadcastToColor("💰 "..def.kind..": Choose investment amount (min 50 WIN, increments of 50)", buyerColor, {0.8,0.9,1})
      elseif def.kind == "ENDOWMENT" then
        -- ENDOWMENT: First choose duration (2/3/4 years), then amount
        local g = card.getGUID()
        buyerColor = normalizeColor(buyerColor)
        local ngoSubsidyEndow = 0
        local vocE = firstWithTag(TAG_VOCATIONS_CTRL)
        if vocE and vocE.call then
          local okE, resE = pcall(function() return vocE.call("VOC_GetNGOInvestmentSubsidy", { color = buyerColor }) end)
          if okE and resE ~= nil then ngoSubsidyEndow = tonumber(resE) or 0 end
        end
        pendingInvestment[g] = {
          color = buyerColor,
          def = def,
          card = card,
          kind = def.kind,
          duration = nil,  -- Will be set when player chooses
          counterValue = 0,
          minAmount = 50,
          increment = 50,
          ngoSubsidy = ngoSubsidyEndow,
        }
        
        -- Keep card lifted for duration choice
        uiClearButtons(card)
        local homePos = UI.homePos[g]
        if homePos then
          pcall(function()
            card.setLock(false)
            local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
            card.setPositionSmooth(liftPos, false, true)
          end)
        end
        
        -- Show duration choice buttons (vertical layout, one after the other)
        card.createButton({
          click_function = "inv_endowment_2years",
          function_owner = self,
          label = "2 YEARS\n(50% profit)",
          position = {0, 0.85, 0},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.6,
          color = {0.3, 0.7, 0.9, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "2 years: 50% profit (receive 150% of investment)",
        })
        card.createButton({
          click_function = "inv_endowment_3years",
          function_owner = self,
          label = "3 YEARS\n(125% profit)",
          position = {0, 0.5, 0},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.6,
          color = {0.3, 0.8, 0.5, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "3 years: 125% profit (receive 225% of investment)",
        })
        card.createButton({
          click_function = "inv_endowment_4years",
          function_owner = self,
          label = "4 YEARS\n(200% profit)",
          position = {0, 0.15, 0},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.6,
          color = {0.9, 0.7, 0.3, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "4 years: 200% profit (receive 300% of investment)",
        })
        uiSetDescription(card, "Choose investment duration (2, 3, or 4 years)")
        safeBroadcastToColor("💰 ENDOWMENT: Choose duration (2/3/4 years), then amount", buyerColor, {0.8,0.9,1})
        return true
      elseif def.kind == "ESTATEINVEST" then
        -- ESTATEINVEST: Choose payment method (60% now vs 3×30%) and apartment level
        local g = card.getGUID()
        buyerColor = normalizeColor(buyerColor)
        local ngoSubsidyEst = 0
        local vocEst = firstWithTag(TAG_VOCATIONS_CTRL)
        if vocEst and vocEst.call then
          local okEst, resEst = pcall(function() return vocEst.call("VOC_GetNGOInvestmentSubsidy", { color = buyerColor }) end)
          if okEst and resEst ~= nil then ngoSubsidyEst = tonumber(resEst) or 0 end
        end
        pendingInvestment[g] = {
          color = buyerColor,
          def = def,
          card = card,
          kind = def.kind,
          paymentMethod = nil,  -- "60pct" or "3x30pct"
          apartmentLevel = nil,  -- "L1", "L2", "L3", "L4"
          ngoSubsidy = ngoSubsidyEst,
        }
        
        -- Keep card lifted for apartment level choice
        uiClearButtons(card)
        local homePos = UI.homePos[g]
        if homePos then
          pcall(function()
            card.setLock(false)
            local liftPos = {homePos.x, homePos.y + UI_LIFT_Y, homePos.z}
            card.setPositionSmooth(liftPos, false, true)
          end)
        end
        
        -- Show apartment level choice first (vertical layout using Z coordinates)
        -- In TTS, "below" is achieved by Z coordinate, not Y
        local LEVEL_BTN_Y = 0.16  -- Y position for all level buttons
        local LEVEL_BTN_Z_START = 0.75  -- Top button Z position
        local LEVEL_BTN_Z_SPACING = -0.53  -- Spacing between buttons (negative = going down)
        
        card.createButton({
          click_function = "inv_estateinvest_L1",
          function_owner = self,
          label = "L1\n(2,000 WIN)",
          position = {0, LEVEL_BTN_Y, LEVEL_BTN_Z_START},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.5,
          color = {0.3, 0.7, 0.9, 1.0},
          font_color = {1, 1, 1, 1},
          tooltip = "Studio apartment: 2,000 WIN",
        })
        card.createButton({
          click_function = "inv_estateinvest_L2",
          function_owner = self,
          label = "L2\n(3,500 WIN)",
          position = {0, LEVEL_BTN_Y, LEVEL_BTN_Z_START + LEVEL_BTN_Z_SPACING},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.5,
          color = {0.3, 0.8, 0.5, 1.0},
          font_color = {1, 1, 1, 1},
          tooltip = "Flat with 3 rooms: 3,500 WIN",
        })
        card.createButton({
          click_function = "inv_estateinvest_L3",
          function_owner = self,
          label = "L3\n(5,500 WIN)",
          position = {0, LEVEL_BTN_Y, LEVEL_BTN_Z_START + (LEVEL_BTN_Z_SPACING * 2)},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.5,
          color = {0.9, 0.7, 0.3, 1.0},
          font_color = {1, 1, 1, 1},
          tooltip = "House in suburbs: 5,500 WIN",
        })
        card.createButton({
          click_function = "inv_estateinvest_L4",
          function_owner = self,
          label = "L4\n(10,000 WIN)",
          position = {0, LEVEL_BTN_Y, LEVEL_BTN_Z_START + (LEVEL_BTN_Z_SPACING * 3)},
          rotation = {0, 0, 0},
          width = UI_BTN_W * 0.7,
          height = UI_BTN_H * 0.7,
          font_size = UI_BTN_FONT * 0.5,
          color = {0.9, 0.5, 0.9, 1.0},
          font_color = {1, 1, 1, 1},
          tooltip = "Mansion: 10,000 WIN",
        })
        uiSetDescription(card, "Choose apartment level, then payment method")
        safeBroadcastToColor("🏠 ESTATEINVEST: Choose apartment level (L1-L4), then payment method", buyerColor, {0.8,0.9,1})
        return true
      end
      
      return true  -- Card stays on table, waiting for input
    end
    
    -- Effect completed immediately (no dice needed) or failed
    -- For lottery cards, stash after dice; for future cards, handle differently
    if effectResult then
      Wait.time(function()
        if card and card.tag=="Card" then
          stashPurchasedCard(card)
        end
      end, 0.05)
      safeBroadcastToColor("🛒 Purchased: "..tostring(name), buyerColor, {0.8,0.9,1})
    else
      -- Effect failed (e.g., not implemented), refund money?
      -- For now, just stash card and let player know
      Wait.time(function()
        if card and card.tag=="Card" then
          stashPurchasedCard(card)
        end
      end, 0.05)
    end
    return effectResult
  end

  -- Handle Consumable cards (existing flow)
  local effectResult = applyConsumableEffect(buyerColor, card, def)
  
  -- If dice needed, card will be stashed after dice roll (don't stash yet)
  if effectResult == "WAIT_DICE" then
    safeBroadcastToColor("🛒 Purchased: "..tostring(name).." - Roll the die, then click ROLL DICE", buyerColor, {0.8,0.9,1})
    return true
  end

  -- Effect completed immediately (no dice needed)
  -- IMPORTANT: do NOT destruct; stash back to deck/closed
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.05)

  if options.discountTokens and options.voucherTag and options.discountTokens > 0 then
    pscRemoveStatusCount(buyerColor, options.voucherTag, options.discountTokens)
    safeBroadcastToColor("🛒 Purchased: "..tostring(name).." with "..tostring(options.discountTokens).."× discount", buyerColor, {0.8,0.9,1})
  else
    safeBroadcastToColor("🛒 Purchased: "..tostring(name), buyerColor, {0.8,0.9,1})
  end
  return true
end

-- =========================
-- [S10B] UI callbacks
-- =========================
function shop_onCardClicked(card, player_color, alt_click)
  if not isCard(card) then return end
  uiOpenModal(card)
end

function shop_onNo(card, player_color, alt_click)
  if not isCard(card) then return end
  if checkBusyGate(player_color) then return end
  uiCloseModal(card)
end

-- Voucher: "Use discount? (S)" No -> buy at full price
function shop_voucherNo(card, player_color, alt_click)
  if not isCard(card) then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingVoucherChoice[g]
  pendingVoucherChoice[g] = nil
  UI.modalOpen[g] = nil
  if not pending or not pending.buyer then
    uiEnsureIdle(card)
    return
  end
  local ok = attemptBuyCard(card, pending.buyer)
  -- Hi-Tech: card moved to player board. WAIT_DICE (Nature Trip, PILLS, Lottery, etc.): card must stay lifted for die roll.
  if classifyRowByName(card) ~= "H" and not pendingDice[g] then
    uiReturnHome(card)
    uiEnsureIdle(card)
  end
  if ok and not pendingDice[g] then refreshShopOpenUI_later(0.25) end
end

-- Voucher: "Use discount? (S)" Yes -> if S==1 buy with 1 token; if S>1 show "How many?"
function shop_voucherYes(card, player_color, alt_click)
  if not isCard(card) then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingVoucherChoice[g]
  if not pending or not pending.buyer then
    pendingVoucherChoice[g] = nil
    uiEnsureIdle(card)
    return
  end
  if pending.voucherCount == 1 then
    pendingVoucherChoice[g] = nil
    UI.modalOpen[g] = nil
    local ok = attemptBuyCard(card, pending.buyer, { discountTokens = 1, voucherTag = pending.voucherTag })
    -- Hi-Tech: card moved to player board. WAIT_DICE (Nature Trip, PILLS, Lottery, etc.): card must stay lifted for die roll.
    if classifyRowByName(card) ~= "H" and not pendingDice[g] then
      uiReturnHome(card)
      uiEnsureIdle(card)
    end
    if ok and not pendingDice[g] then refreshShopOpenUI_later(0.25) end
    return
  end
  pending.step = "ask_count"
  uiAttachVoucherCountModal(card, pending.voucherCount)
end

-- Voucher: "How many?" -> use N tokens (N=1..4)
function shop_voucherUseN(card, player_color, N)
  if not isCard(card) or not N or N < 1 or N > 4 then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingVoucherChoice[g]
  pendingVoucherChoice[g] = nil
  UI.modalOpen[g] = nil
  if not pending or not pending.buyer then
    uiEnsureIdle(card)
    return
  end
  local ok = attemptBuyCard(card, pending.buyer, { discountTokens = N, voucherTag = pending.voucherTag })
  -- Hi-Tech: card moved to player board. WAIT_DICE (Nature Trip, PILLS, Lottery, etc.): card must stay lifted for die roll.
  if classifyRowByName(card) ~= "H" and not pendingDice[g] then
    uiReturnHome(card)
    uiEnsureIdle(card)
  end
  if ok and not pendingDice[g] then refreshShopOpenUI_later(0.25) end
end
function shop_voucherUse1(card, pc, alt) shop_voucherUseN(card, pc, 1) end
function shop_voucherUse2(card, pc, alt) shop_voucherUseN(card, pc, 2) end
function shop_voucherUse3(card, pc, alt) shop_voucherUseN(card, pc, 3) end
function shop_voucherUse4(card, pc, alt) shop_voucherUseN(card, pc, 4) end

function shop_onYes(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  if not isShopOpenSlotCard(card) then
    uiCloseModal(card)
    return
  end

  local name = getNameSafe(card)
  local row = classifyRowByName(card)
  local def = nil
  if row == "I" then
    def = INVESTMENT_DEF[name]
    if def and (def.kind == "DEBENTURES" or def.kind == "LOAN" or def.kind == "STOCK" or def.kind == "ENDOWMENT" or def.kind == "ESTATEINVEST") then
      uiClearButtons(card)
    else
      uiCloseModalSoft(card)
    end
  elseif row == "C" or row == "H" then
    local active = getActiveTurnColor()
    local buyer  = resolveBuyerColor(player_color)
    if active and buyer and buyer == active then
      local voucherTag = (row == "C") and TAG_STATUS_VOUCH_C or TAG_STATUS_VOUCH_H
      local voucherCount = pscGetStatusCount(buyer, voucherTag)
      if voucherCount >= 1 then
        local g = card.getGUID()
        pendingVoucherChoice[g] = { buyer = buyer, row = row, card = card, voucherCount = voucherCount, voucherTag = voucherTag, step = "ask_use" }
        uiClearButtons(card)
        uiAttachVoucherUseModal(card, voucherCount)
        return
      end
    end
    uiCloseModalSoft(card)
  else
    uiCloseModalSoft(card)
  end

  local active = getActiveTurnColor()
  local buyer  = resolveBuyerColor(player_color)

  if DEBUG then
    safeBroadcastAll("DBG BUY | active="..tostring(active).." | click="..tostring(player_color).." | buyer="..tostring(buyer), {0.85,0.85,1})
  end

  -- Permission check: must have active turn, and buyer must match active turn
  -- Reject "White" and invalid colors
  if not active or active == "" or active == "White" then
    safeBroadcastToColor("⛔ ShopEngine: No active turn. Please start the game first.", player_color or "White", {1,0.6,0.2})
    Wait.time(function()
      if card and card.tag=="Card" then uiEnsureIdle(card) end
    end, 0.15)
    return
  end
  
  if not buyer or buyer == "" or buyer == "White" then
    safeBroadcastToColor("⛔ ShopEngine: Invalid buyer color. Only active player can buy cards.", player_color or "White", {1,0.6,0.2})
    Wait.time(function()
      if card and card.tag=="Card" then uiEnsureIdle(card) end
    end, 0.15)
    return
  end
  
  if buyer ~= active then
    safeBroadcastToColor("⛔ ShopEngine: Only the active player ("..active..") can buy cards. (buyer="..buyer..")", player_color or "White", {1,0.6,0.2})
    Wait.time(function()
      if card and card.tag=="Card" then uiEnsureIdle(card) end
    end, 0.15)
    return
  end

  local ok = attemptBuyCard(card, buyer)
  if not ok then
    Wait.time(function()
      if card and card.tag=="Card" then uiEnsureIdle(card) end
    end, 0.15)
    return
  end

  -- Only refresh UI if card wasn't left waiting for dice
  local g = card.getGUID()
  if not pendingDice[g] then
    refreshShopOpenUI_later(0.25)
  end
end

function shop_onRollDice(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  
  local g = card.getGUID()
  local pending = pendingDice[g]
  if not pending then
    safeBroadcastToColor("⚠️ No pending dice roll on this card", player_color, {1,0.6,0.2})
    return
  end
  
  -- Roll the die (like TurnController does when button is clicked)
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", player_color, {1,0.6,0.2})
    return
  end
  
  -- Randomize and roll the die (same as TurnController)
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  -- Wait for die to settle (same pattern as TurnController)
  local timeout = os.time() + 6
  Wait.condition(
    function()
      -- Die has settled, read the value
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", player_color, {1,0.7,0.3})
        return
      end
      
      -- Clear pending state
      pendingDice[g] = nil
      diceInitialValue[g] = nil
      
      -- Complete the effect with the roll value (check card type)
      local result = nil
      if pending.cardType == "INVESTMENT" then
        result = applyInvestmentEffect(pending.color, card, pending.def, v)
      else
        -- Default: Consumable
        result = applyConsumableEffect(pending.color, card, pending.def, v)
      end
      
      -- Clear UI and stash card
      uiClearButtons(card)
      uiClearDescription(card)
      
      Wait.time(function()
        if card and card.tag=="Card" then
          stashPurchasedCard(card)
        end
        refreshShopOpenUI_later(0.25)
      end, 0.3)
      
      safeBroadcastToColor("🎲 Die rolled: "..v, player_color, {0.8,0.9,1})
    end,
    function()
      -- Condition: wait for die to be resting or timeout
      local resting = false
      pcall(function() resting = die.resting end)
      if resting then return true end
      if os.time() >= timeout then return true end
      return false
    end
  )
end

-- =========================
-- [S10C] INVESTMENT COUNTER UI HANDLERS
-- =========================
function inv_onCounterIncrement(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending then return end
  
  pending.counterValue = (pending.counterValue or 0) + (pending.increment or 50)
  uiAttachCounter(card, pending.counterValue, pending.minAmount or 50, pending.increment or 50)
end

function inv_onCounterDecrement(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending then return end
  
  local newValue = (pending.counterValue or 0) - (pending.increment or 50)
  if newValue < (pending.minAmount or 50) then newValue = pending.minAmount or 50 end
  pending.counterValue = newValue
  uiAttachCounter(card, pending.counterValue, pending.minAmount or 50, pending.increment or 50)
end

function inv_onCounterOK(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  local g = card.getGUID()
  local pending = pendingInvestment[g]
  if not pending then return end
  
  local color = normalizeColor(pending.color)
  local amount = pending.counterValue or 0
  local minAmount = pending.minAmount or 50
  local subsidy = tonumber(pending.ngoSubsidy) or 0
  if subsidy < 0 then subsidy = 0 end
  local amountToCharge = math.max(0, amount - subsidy)
  
  if amount < minAmount then
    safeBroadcastToColor("⛔ Minimum investment is "..tostring(minAmount).." WIN", color, {1,0.6,0.2})
    return
  end
  
  -- Process investment based on kind
  local success = false
  if pending.kind == "DEBENTURES" then
    success = processDebenturesPurchase(color, card, amount, amountToCharge)
    if success and subsidy > 0 then
      local voc = firstWithTag(TAG_VOCATIONS_CTRL)
      if voc and voc.call then pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = color }) end) end
    end
    if success then
      -- Clear pending state and buttons only on success
      pendingInvestment[g] = nil
      uiClearButtons(card)
    else
      -- Keep counter UI active so player can adjust amount
      -- Don't clear pending state or buttons
    end
  elseif pending.kind == "LOAN" then
    success = processLoanPurchase(color, card, amount)
    if success then
      -- Clear pending state and buttons only on success
      pendingInvestment[g] = nil
      uiClearButtons(card)
    else
      -- Keep counter UI active so player can adjust amount
    end
  elseif pending.kind == "STOCK" then
    success = processStockPurchase(color, card, amount, amountToCharge)
    if success and subsidy > 0 then
      local voc = firstWithTag(TAG_VOCATIONS_CTRL)
      if voc and voc.call then pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = color }) end) end
    end
    if success then
      -- Clear pending state (buttons handled by processStockPurchase)
      pendingInvestment[g] = nil
    else
      -- Keep counter UI active so player can adjust amount
      -- Don't clear pending state or buttons
    end
  elseif pending.kind == "ENDOWMENT" then
    -- ENDOWMENT: duration already chosen, now process amount
    local duration = pending.duration
    if not duration or duration < 2 or duration > 4 then
      safeBroadcastToColor("⛔ Invalid duration for ENDOWMENT", color, {1,0.6,0.2})
      return
    end
    success = processEndowmentPurchase(color, card, amount, duration, amountToCharge)
    if success and subsidy > 0 then
      local voc = firstWithTag(TAG_VOCATIONS_CTRL)
      if voc and voc.call then pcall(function() voc.call("VOC_ConsumeNGOInvestmentPerk", { color = color }) end) end
    end
    if success then
      -- Clear pending state and buttons only on success
      pendingInvestment[g] = nil
      uiClearButtons(card)
    else
      -- Keep counter UI active so player can adjust amount
    end
  else
    safeBroadcastToColor("⛔ Unknown investment type: "..tostring(pending.kind), color, {1,0.6,0.2})
    return
  end
end

-- DEBENTURES cash out handler
function inv_debentures_cashOut(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local color = normalizeColor(player_color)
  if not S.investments[color] or not S.investments[color].debentures then return end
  
  local inv = S.investments[color].debentures
  local totalInvested = inv.totalInvested or 0
  
  -- Check if 3 payments complete (can cash out with profit)
  if inv.paidCount >= 3 then
    -- Cash out with profit (200% of total investment)
    local payout = totalInvested * 2
    local ok = moneyAdd(color, payout)
    if ok then
      safeBroadcastAll("💰 "..color.." cashed out Debentures: Received "..tostring(payout).." WIN (invested "..tostring(totalInvested)..", profit "..tostring(totalInvested)..")", {0.9,1,0.6})
    else
      safeBroadcastToColor("⚠️ Failed to add payout", color, {1,0.7,0.2})
      return
    end
  else
    -- Early cash out (no profit, just return invested amount)
    local ok = moneyAdd(color, totalInvested)
    if ok then
      safeBroadcastAll("💰 "..color.." cashed out Debentures early: Received "..tostring(totalInvested).." WIN (no profit)", {0.8,0.8,0.8})
    else
      safeBroadcastToColor("⚠️ Failed to add cash out amount", color, {1,0.7,0.2})
      return
    end
  end
  
  -- Remove from cost calculator (cancel remaining payments)
  -- Since CostsCalc is additive, we subtract the remaining payments
  local remainingPayments = 3 - inv.paidCount
  if remainingPayments > 0 then
    local totalRemaining = inv.investedPerTurn * remainingPayments
    Costs_add(color, -totalRemaining)  -- Subtract remaining payments
    log("Debentures cashout: Removed "..tostring(totalRemaining).." WIN from cost calculator for "..color)
  end
  
  -- Clear investment state
  S.investments[color].debentures = nil
  
  -- Remove card buttons and stash card
  pcall(function() card.clearButtons() end)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.3)
end

-- STOCK handlers
function inv_stock_continueYes(card, player_color, alt_click)
  -- Player chose to continue: automatically roll second die
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  
  -- Resolve active player color (not just clicking color)
  local color = resolveBuyerColor(player_color)
  if not color or color == "" or color == "White" then
    safeBroadcastToColor("⛔ Invalid player color", player_color or "White", {1,0.6,0.2})
    return
  end
  
  -- Verify investment exists and card matches
  if not S.investments[color] or not S.investments[color].stock then
    safeBroadcastToColor("⛔ Stock investment not found", color, {1,0.6,0.2})
    return
  end
  
  local inv = S.investments[color].stock
  local cardGUID = card.getGUID()
  if inv.cardGUID ~= cardGUID then
    safeBroadcastToColor("⛔ Card mismatch for stock investment", color, {1,0.6,0.2})
    return
  end
  
  if inv.firstRoll == nil then
    safeBroadcastToColor("⚠️ First roll not found", color, {1,0.7,0.2})
    return
  end
  if inv.secondRoll ~= nil then
    safeBroadcastToColor("⚠️ Second roll already made", color, {1,0.7,0.2})
    return
  end
  
  -- Clear buttons and show "Rolling..." message
  uiClearButtons(card)
  uiSetDescription(card, "Rolling second die...")
  safeBroadcastToColor("🎲 Rolling second die...", color, {0.8,0.9,1})
  
  -- Roll the die
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", color, {1,0.6,0.2})
    -- Return money if die not found
    moneyAdd(color, inv.investmentAmount or 0)
    S.investments[color].stock = nil
    return
  end
  
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  -- Wait for die to settle
  local timeout = os.time() + 6
  Wait.condition(
    function()
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", color, {1,0.7,0.3})
        -- Return money if can't read die
        moneyAdd(color, inv.investmentAmount or 0)
        S.investments[color].stock = nil
        return
      end
      
      -- Store second roll
      inv.secondRoll = v
      inv.resolved = true
      
      local firstRoll = inv.firstRoll
      local secondRoll = v
      local investmentAmount = inv.investmentAmount or 0
      
      -- Calculate result
      local payout = 0
      local message = ""
      local colorMsg = {0.8,0.8,0.8}
      
      if secondRoll > firstRoll then
        -- Win: Double investment (2× return, 100% profit)
        payout = investmentAmount * 2
        message = "🎉🎉 "..color.." Stock: WON! (First="..firstRoll..", Second="..secondRoll..") → "..tostring(payout).." WIN (profit: "..tostring(investmentAmount)..")"
        colorMsg = {0.9,1,0.6}
      elseif secondRoll == firstRoll then
        -- Break even: Get investment back
        payout = investmentAmount
        message = "➖ "..color.." Stock: Break even (First="..firstRoll..", Second="..secondRoll..") → "..tostring(payout).." WIN back"
        colorMsg = {0.8,0.8,0.8}
      else
        -- Lose: No payout
        payout = 0
        message = "❌ "..color.." Stock: LOST (First="..firstRoll..", Second="..secondRoll..") → 0 WIN (lost "..tostring(investmentAmount)..")"
        colorMsg = {0.9,0.7,0.7}
      end
      
      -- Pay out
      if payout > 0 then
        local ok = moneyAdd(color, payout)
        if not ok then
          safeBroadcastAll("⚠️ Stock: Failed to add payout", {1,0.7,0.2})
        end
      end
      
      safeBroadcastAll(message, colorMsg)
      
      -- Clear investment state
      S.investments[color].stock = nil
      
      -- Remove card buttons and stash card
      pcall(function() card.clearButtons() end)
      uiClearDescription(card)
      Wait.time(function()
        if card and card.tag=="Card" then
          stashPurchasedCard(card)
        end
      end, 0.3)
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

function inv_stock_continueNo(card, player_color, alt_click)
  -- Player chose to cancel: return money and resolve
  if not (card and card.tag=="Card") then return end
  if checkBusyGate(player_color) then return end
  
  -- Resolve active player color (not just clicking color)
  local color = resolveBuyerColor(player_color)
  if not color or color == "" or color == "White" then
    safeBroadcastToColor("⛔ Invalid player color", player_color or "White", {1,0.6,0.2})
    return
  end
  
  -- Verify investment exists and card matches
  if not S.investments[color] or not S.investments[color].stock then
    safeBroadcastToColor("⛔ Stock investment not found", color, {1,0.6,0.2})
    return
  end
  
  local inv = S.investments[color].stock
  local cardGUID = card.getGUID()
  if inv.cardGUID ~= cardGUID then
    safeBroadcastToColor("⛔ Card mismatch for stock investment", color, {1,0.6,0.2})
    return
  end
  
  local investmentAmount = inv.investmentAmount or 0
  
  -- Return money
  local ok = moneyAdd(color, investmentAmount)
  if ok then
    safeBroadcastAll("💰 "..color.." Stock: Investment cancelled. "..tostring(investmentAmount).." WIN returned", {0.8,0.9,1})
  else
    safeBroadcastAll("⚠️ Stock: Failed to return investment", {1,0.7,0.2})
  end
  
  -- Clear investment state
  S.investments[color].stock = nil
  
  -- Remove card buttons and stash card
  pcall(function() card.clearButtons() end)
  uiClearDescription(card)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.3)
end

-- STOCK dice roll handlers (kept for backward compatibility, but not used in new flow)
function inv_stock_rollFirst(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local color = normalizeColor(player_color)
  if not S.investments[color] or not S.investments[color].stock then return end
  
  local inv = S.investments[color].stock
  if inv.firstRoll ~= nil then
    safeBroadcastToColor("⚠️ First roll already made. Click ROLL SECOND DIE", color, {1,0.7,0.2})
    return
  end
  
  -- Roll the die
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", color, {1,0.6,0.2})
    return
  end
  
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  -- Wait for die to settle
  local timeout = os.time() + 6
  Wait.condition(
    function()
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", color, {1,0.7,0.3})
        return
      end
      
      -- Store first roll
      inv.firstRoll = v
      safeBroadcastAll("🎲 "..color.." Stock: First roll = "..v, {0.8,0.9,1})
      
      -- Update card buttons: show second roll button, keep resign
      pcall(function()
        card.clearButtons()
        card.createButton({
          click_function = "inv_stock_rollSecond",
          function_owner = self,
          label = "ROLL\nSECOND DIE",
          position = {-0.4, 0.33, 1.0},
          rotation = {0, 0, 0},
          width = 700,
          height = 300,
          font_size = 120,
          color = {0.2, 0.6, 0.9, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "Roll second die (must be > "..v.." to win)",
        })
        card.createButton({
          click_function = "inv_stock_resign",
          function_owner = self,
          label = "RESIGN\n(Break Even)",
          position = {0.4, 0.33, 1.0},
          rotation = {0, 0, 0},
          width = 700,
          height = 300,
          font_size = 120,
          color = {0.6, 0.6, 0.6, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "Resign and get investment back (no profit/loss)",
        })
      end)
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

function inv_stock_rollSecond(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local color = normalizeColor(player_color)
  if not S.investments[color] or not S.investments[color].stock then return end
  
  local inv = S.investments[color].stock
  if inv.firstRoll == nil then
    safeBroadcastToColor("⚠️ Roll first die first", color, {1,0.7,0.2})
    return
  end
  if inv.secondRoll ~= nil then
    safeBroadcastToColor("⚠️ Second roll already made", color, {1,0.7,0.2})
    return
  end
  
  -- Roll the die
  local die = getObjectFromGUID(DIE_GUID)
  if not die then
    safeBroadcastToColor("⚠️ Die not found (GUID: "..DIE_GUID..")", color, {1,0.6,0.2})
    return
  end
  
  pcall(function() die.randomize() end)
  pcall(function() die.roll() end)
  
  -- Wait for die to settle
  local timeout = os.time() + 6
  Wait.condition(
    function()
      local v = tryReadDieValue(die)
      if not v or v < 1 or v > 6 then
        safeBroadcastToColor("⚠️ Could not read die value", color, {1,0.7,0.3})
        return
      end
      
      -- Store second roll
      inv.secondRoll = v
      inv.resolved = true
      
      local firstRoll = inv.firstRoll
      local secondRoll = v
      local investmentAmount = inv.investmentAmount or 0
      
      -- Calculate result
      local payout = 0
      local message = ""
      local colorMsg = {0.8,0.8,0.8}
      
      if secondRoll > firstRoll then
        -- Win: Double investment (2× return, 100% profit)
        payout = investmentAmount * 2
        message = "🎉🎉 "..color.." Stock: WON! (First="..firstRoll..", Second="..secondRoll..") → "..tostring(payout).." WIN (profit: "..tostring(investmentAmount)..")"
        colorMsg = {0.9,1,0.6}
      elseif secondRoll == firstRoll then
        -- Break even: Get investment back
        payout = investmentAmount
        message = "➖ "..color.." Stock: Break even (First="..firstRoll..", Second="..secondRoll..") → "..tostring(payout).." WIN back"
        colorMsg = {0.8,0.8,0.8}
      else
        -- Lose: No payout
        payout = 0
        message = "❌ "..color.." Stock: LOST (First="..firstRoll..", Second="..secondRoll..") → 0 WIN (lost "..tostring(investmentAmount)..")"
        colorMsg = {0.9,0.7,0.7}
      end
      
      -- Pay out
      if payout > 0 then
        local ok = moneyAdd(color, payout)
        if not ok then
          safeBroadcastAll("⚠️ Stock: Failed to add payout", {1,0.7,0.2})
        end
      end
      
      safeBroadcastAll(message, colorMsg)
      
      -- Clear investment state
      S.investments[color].stock = nil
      
      -- Remove card buttons and stash card
      pcall(function() card.clearButtons() end)
      Wait.time(function()
        if card and card.tag=="Card" then
          stashPurchasedCard(card)
        end
      end, 0.3)
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

function inv_stock_resign(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local color = normalizeColor(player_color)
  if not S.investments[color] or not S.investments[color].stock then return end
  
  local inv = S.investments[color].stock
  local amount = inv.investmentAmount or 0
  
  -- Return investment (break even)
  local ok = moneyAdd(color, amount)
  if ok then
    safeBroadcastAll("💰 "..color.." resigned from Stock: Received "..tostring(amount).." WIN back (break even)", {0.8,0.8,0.8})
  else
    safeBroadcastToColor("⚠️ Failed to add cash out amount", color, {1,0.7,0.2})
    return
  end
  
  -- Clear investment state
  S.investments[color].stock = nil
  
  -- Remove card buttons and stash card
  pcall(function() card.clearButtons() end)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.3)
end

-- =========================
-- [S11] CORE OPS (pipelines helpers)
-- =========================
local function closeAllShopObjects()
  for _,d in ipairs(safeGetObjectsWithTag(TAG_SHOP_DECK)) do
    if isDeck(d) then forceFaceDown(d) end
  end

  for _,o in ipairs(getAllObjects()) do
    if isCard(o) and isShopCardByName(o) then
      forceFaceDown(o)
      ensureTag(o, TAG_SHOP_CARD)
      uiClearButtons(o)
      uiClearDescription(o)
      UI.modalOpen[o.getGUID()] = nil
      UI.homePos[o.getGUID()] = nil
    end
  end
end

local function moveDeckToClosed(row, deckObj)
  local sw = slotWorlds(row)
  if not sw or not sw.closed or not deckObj then return false end
  local p = sw.closed
  pcall(function() deckObj.setPosition({p.x, p.y + DEAL_Y, p.z}) end)
  if S.desiredYaw then pcall(function() deckObj.setRotation({0, S.desiredYaw, 0}) end) end
  lockBrief(deckObj)
  return true
end

local function shuffleDeck(deckObj)
  if not isDeck(deckObj) then return end
  forceFaceDown(deckObj)
  pcall(function() deckObj.shuffle() end)
end

local function collectAllShopCardsIntoDecks()
  local dc, dh, di = deckForRow("C"), deckForRow("H"), deckForRow("I")
  if not dc or not dh or not di then
    warn("collectAll: missing one or more decks (C/H/I). Check deck tags.")
    return {C=0,H=0,I=0,UNK=0}
  end

  local moved = {C=0,H=0,I=0,UNK=0}

  -- 1) If any shop cards were merged into a deck (by players), extract them and put back.
  --    NOTE: We skip the main shop decks themselves (TAG_SHOP_DECK).
  local function isMainShopDeck(o)
    if not (o and o.hasTag) then return false end

    -- USED piles must NEVER be treated as "main shop decks"
    if o.hasTag(TAG_SHOP_USED) or o.hasTag(TAG_SHOP_USED_C) or o.hasTag(TAG_SHOP_USED_I) then
      return false
    end

    -- Main deck must have WLB_SHOP_DECK + one of the authoritative deck tags
    if o.hasTag(TAG_SHOP_DECK) then
      return o.hasTag(TAG_DECK_C) or o.hasTag(TAG_DECK_H) or o.hasTag(TAG_DECK_I)
    end

    return false
  end

  local function deckShopRowSummary(deckObj)
    local okList, list = pcall(function() return deckObj.getObjects() end)
    if (not okList) or type(list) ~= "table" or #list == 0 then
      return {C=0,H=0,I=0,total=0}
    end
    local out = {C=0,H=0,I=0,total=#list}
    for _, entry in ipairs(list) do
      local nm = entry.nickname or entry.name or ""
      local row = classifyRowByNameStr(nm)
      if row == "C" then out.C = out.C + 1 end
      if row == "H" then out.H = out.H + 1 end
      if row == "I" then out.I = out.I + 1 end
    end
    return out
  end

  local function guessRowForMergedDeckByTags(deckObj)
    if not deckObj then return nil end

    -- 1) Prefer explicit USED tags (recommended: stable even if names are empty)
    if deckObj.hasTag then
      if deckObj.hasTag(TAG_SHOP_USED_C) then return "C" end
      if deckObj.hasTag(TAG_SHOP_USED_I) then return "I" end

      -- fallback if USED tags are missing but deck-tag exists
      if deckObj.hasTag(TAG_DECK_C) then return "C" end
      if deckObj.hasTag(TAG_DECK_I) then return "I" end
      if deckObj.hasTag(TAG_DECK_H) then return "H" end
    end
    return nil
  end

  for _,o in ipairs(getAllObjects()) do
    if isDeck(o) and (not isMainShopDeck(o)) then
      -- If this is a used-pile deck, merge it back by USED tags even when card names are empty.
      local rowHint = guessRowForMergedDeckByTags(o)
      if rowHint == "C" or rowHint == "I" then
        local target = (rowHint == "C") and dc or di
        local qty = 0
        pcall(function() qty = o.getQuantity() end)
        qty = tonumber(qty) or 0
        forceFaceDown(o)
        uiClearButtons(o)
        uiClearDescription(o)
        pcall(function() target.putObject(o) end)
        if rowHint == "C" then moved.C = moved.C + qty end
        if rowHint == "I" then moved.I = moved.I + qty end
      else
        -- Only touch decks that ACTUALLY contain shop cards (by contained names).
        local sum = deckShopRowSummary(o)
        local anyShop = (sum.C + sum.H + sum.I) > 0
        if anyShop then
          -- Prefer merging whole deck if it contains ONLY one shop row type.
          local onlyC = (sum.C > 0) and (sum.H == 0) and (sum.I == 0)
          local onlyH = (sum.H > 0) and (sum.C == 0) and (sum.I == 0)
          local onlyI = (sum.I > 0) and (sum.C == 0) and (sum.H == 0)

          if onlyC or onlyH or onlyI then
            local target = onlyC and dc or onlyH and dh or di
            local qty = 0
            pcall(function() qty = o.getQuantity() end)
            qty = tonumber(qty) or 0
            forceFaceDown(o)
            uiClearButtons(o)
            uiClearDescription(o)
            pcall(function() target.putObject(o) end)
            if onlyC then moved.C = moved.C + qty end
            if onlyH then moved.H = moved.H + qty end
            if onlyI then moved.I = moved.I + qty end
          else
            -- Mixed decks: extract matching shop cards by guid (best effort).
            local okList, list = pcall(function() return o.getObjects() end)
            if okList and type(list) == "table" and #list > 0 then
              local extracted = 0
              for _, entry in ipairs(list) do
                local nm = entry.nickname or entry.name or ""
                local row = classifyRowByNameStr(nm)
                if row then
                  extracted = extracted + 1
                  local target = (row=="C") and dc or (row=="H") and dh or di
                  local guid = entry.guid
                  Wait.time(function()
                    if not (o and o.tag=="Deck") then return end
                    pcall(function()
                      o.takeObject({
                        guid = guid,
                        flip = false,
                        smooth = false,
                        callback_function = function(card)
                          if not card or card.tag ~= "Card" then return end
                          ensureTag(card, TAG_SHOP_CARD)
                          uiClearButtons(card)
                          uiClearDescription(card)
                          forceFaceDown(card)
                          UI.modalOpen[card.getGUID()] = nil
                          UI.homePos[card.getGUID()] = nil
                          pcall(function() target.putObject(card) end)
                        end
                      })
                    end)
                  end, 0.03 * extracted)
                end
              end
              if extracted > 0 then
                log("Collect: extracted "..tostring(extracted).." shop cards from mixed deck guid="..tostring(o.getGUID()))
              end
            end
          end
        end
      end
    end
  end

  -- 2) Collect any loose shop cards by name into their decks (original behavior)
  for _,o in ipairs(getAllObjects()) do
    if isCard(o) then
      local row = classifyRowByName(o)
      if row then
        ensureTag(o, TAG_SHOP_CARD)
        forceFaceDown(o)
        uiClearButtons(o)
        uiClearDescription(o)
        UI.modalOpen[o.getGUID()] = nil
        UI.homePos[o.getGUID()] = nil

        if row=="C" then pcall(function() dc.putObject(o) end); moved.C=moved.C+1 end
        if row=="H" then pcall(function() dh.putObject(o) end); moved.H=moved.H+1 end
        if row=="I" then pcall(function() di.putObject(o) end); moved.I=moved.I+1 end
      end
    end
  end

  log("Collect by NAME -> decks | C="..moved.C.." H="..moved.H.." I="..moved.I)
  return moved
end

local function deal3Open(row, deckObj)
  if not isDeck(deckObj) then return end
  local sw = slotWorlds(row)
  if not sw then return end

  forceFaceDown(deckObj)

  for i=1,3 do
    local p = sw.open[i]
    if p and (not slotHasCard(p)) then
      pcall(function()
        deckObj.takeObject({
          position = {p.x, p.y + DEAL_Y, p.z},
          smooth = false,
          flip = true,
          callback_function = function(card)
            if not card or card.tag~="Card" then return end
            ensureTag(card, TAG_SHOP_CARD)
            forceFaceUp(card)
            lockBrief(card)
            Wait.time(function()
              if card and isCard(card) then uiEnsureIdle(card) end
            end, 0.10)
          end
        })
      end)
    end
  end

  refreshShopOpenUI_later(0.35)
end

local function takeOpenCardsBackToDeck(row, deckObj)
  if not isDeck(deckObj) then return end
  local sw = slotWorlds(row)
  if not sw then return end

  for i=1,3 do
    local p = sw.open[i]
    if p then
      local near = objectsNearPos(p, EPS_SLOT)
      for _,o in ipairs(near) do
        if isCard(o) then
          local r2 = classifyRowByName(o)
          if r2 == row then
            ensureTag(o, TAG_SHOP_CARD)
            forceFaceDown(o)
            uiClearButtons(o)
            uiClearDescription(o)
            UI.modalOpen[o.getGUID()] = nil
            UI.homePos[o.getGUID()] = nil
            pcall(function() deckObj.putObject(o) end)
          end
        end
      end
    end
  end
end

-- =========================
-- [S12] JOB / PIPELINES
-- =========================
local function startJob()
  S.jobId = (tonumber(S.jobId) or 0) + 1
  return S.jobId
end
local function isJob(id) return S.jobId == id end

local function pipeline_RESET()
  if S.busy then warn("RESET blocked: busy"); return end
  if not ensureBoard() then return end

  local dc, dh, di = deckForRow("C"), deckForRow("H"), deckForRow("I")
  if not dc or not dh or not di then
    safeBroadcastAll("⛔ ShopEngine: missing C/H/I decks (check deck tags).", {1,0.4,0.4})
    return
  end

  S.busy = true
  local job = startJob()

  -- Reset game state
  S.pillsUseCount = { Yellow=0, Blue=0, Red=0, Green=0 }
  S.restEquivalent = { Yellow=0, Blue=0, Red=0, Green=0 }
  S.boughtThisTurn = {}
  S.ownedHiTech = { Yellow={}, Blue={}, Red={}, Green={} }
  S.permanentRestEquivalent = { Yellow=0, Blue=0, Red=0, Green=0 }
  
  -- Reset Hi-Tech usage tracking
  hitechUsageThisTurn = { Yellow={}, Blue={}, Red={}, Green={} }
  pendingTVUse = {}

  safeBroadcastAll("🛒 SHOP RESET…", {0.8,0.9,1})

  Wait.time(function()
    if not isJob(job) then return end
    closeAllShopObjects()
  end, SHORT_DELAY)

  Wait.time(function()
    if not isJob(job) then return end
    collectAllShopCardsIntoDecks()
  end, STEP_DELAY)

  Wait.time(function()
    if not isJob(job) then return end
    moveDeckToClosed("C", dc); forceFaceDown(dc)
    moveDeckToClosed("H", dh); forceFaceDown(dh)
    moveDeckToClosed("I", di); forceFaceDown(di)
  end, STEP_DELAY * 2)

  Wait.time(function()
    if not isJob(job) then return end
    shuffleDeck(dc); shuffleDeck(dh); shuffleDeck(di)
  end, STEP_DELAY * 3)

  Wait.time(function()
    if not isJob(job) then return end
    deal3Open("C", dc)
    deal3Open("H", dh)
    deal3Open("I", di)
  end, STEP_DELAY * 4)

  Wait.time(function()
    if not isJob(job) then return end
    refreshShopOpenUI_later(0.25)
    S.busy = false
    safeBroadcastAll("✅ SHOP RESET done.", {0.7,1,0.7})
  end, STEP_DELAY * 4 + 0.6)
end

local function pipeline_REFILL()
  if S.busy then warn("REFILL blocked: busy"); return end
  if not ensureBoard() then return end

  local dc, dh, di = deckForRow("C"), deckForRow("H"), deckForRow("I")
  if not dc or not dh or not di then
    safeBroadcastAll("⛔ ShopEngine: missing C/H/I decks (check deck tags).", {1,0.4,0.4})
    return
  end

  S.busy = true
  local job = startJob()

  Wait.time(function()
    if not isJob(job) then return end
    deal3Open("C", dc)
    deal3Open("H", dh)
    deal3Open("I", di)
  end, 0.15)

  Wait.time(function()
    if not isJob(job) then return end
    refreshShopOpenUI_later(0.25)
    S.busy = false
    safeBroadcastAll("✅ SHOP REFILL done.", {0.7,1,0.7})
  end, 0.90)
end

local function pipeline_RANDOMIZE(row)
  if S.busy then warn("RAND blocked: busy"); return end
  if not ensureBoard() then return end

  local d = deckForRow(row)
  if not d then
    safeBroadcastAll("⛔ ShopEngine: missing deck for "..tostring(row).." (check tag).", {1,0.4,0.4})
    return
  end

  S.busy = true
  local job = startJob()

  safeBroadcastAll("🔀 SHOP RANDOMIZE "..row.."…", {0.85,0.85,1})

  Wait.time(function()
    if not isJob(job) then return end
    takeOpenCardsBackToDeck(row, d)
  end, SHORT_DELAY)

  Wait.time(function()
    if not isJob(job) then return end
    shuffleDeck(d)
  end, STEP_DELAY)

  Wait.time(function()
    if not isJob(job) then return end
    deal3Open(row, d)
  end, STEP_DELAY * 2)

  Wait.time(function()
    if not isJob(job) then return end
    refreshShopOpenUI_later(0.25)
    S.busy = false
    safeBroadcastAll("✅ SHOP RANDOMIZE "..row.." done.", {0.7,1,0.7})
  end, STEP_DELAY * 2 + 0.6)
end

-- =========================
-- [S13] DEBUG CHECK (counts)
-- =========================
local function countLooseByName()
  local c,h,i = 0,0,0
  for _,o in ipairs(getAllObjects()) do
    if isCard(o) then
      local r = classifyRowByName(o)
      if r=="C" then c=c+1 end
      if r=="H" then h=h+1 end
      if r=="I" then i=i+1 end
    end
  end
  return c,h,i
end

local function debugReport()
  local dc, dh, di = deckForRow("C"), deckForRow("H"), deckForRow("I")
  local qc, qh, qi = deckQty(dc), deckQty(dh), deckQty(di)
  local lc, lh, li = countLooseByName()

  print("=== [WLB SHOP] CHECK ===")
  print("Version: "..VERSION)
  print("Loose by NAME:  C="..lc.." H="..lh.." I="..li)
  print("Deck qty:       C="..qc.." H="..qh.." I="..qi)
  print("Expected totals: C="..EXPECT_C.." H="..EXPECT_H.." I="..EXPECT_I)
  print("If totals != expected, missing cards are likely inside a different deck or named differently.")
  safeBroadcastAll("🧪 SHOP CHECK -> console (Loose/Deck counts).", {0.9,0.9,1})
end

-- =========================
-- [S14] UI (buttons on controller object)
-- =========================
local function btn(label, fn, x, z, w, h, fs, tip)
  self.createButton({
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x, 0.25, z},
    rotation = {0, 180, 0},
    width = w, height = h,
    font_size = fs,
    tooltip = tip or ""
  })
end

local function drawUI()
  self.clearButtons()

  btn("RESET",  "UI_reset",  -1.35,  0.70, 1200, 520, 190, "Close+Collect(by NAME)+MoveToClosed+Shuffle+Deal (C/H/I)")
  btn("REFILL", "UI_refill", -1.35,  0.05, 1200, 520, 190, "Fill missing OPEN slots (no mixing)")

  btn("RAND\nC", "UI_randC",  1.35,  0.70, 1200, 360, 170, "Randomize CONSUMABLES row")
  btn("RAND\nH", "UI_randH",  1.35,  0.25, 1200, 360, 170, "Randomize HI-TECH row")
  btn("RAND\nI", "UI_randI",  1.35, -0.20, 1200, 360, 170, "Randomize INVESTMENTS row")

  btn("CHECK", "UI_check",     0.00, -0.70, 1200, 420, 160, "Print loose/deck counts to console")
  btn("+1000\nWIN", "UI_add1000", 0.00, -1.20, 1200, 420, 160, "DEBUG: dodaj 1000 WIN dla aktywnego gracza")
end

function UI_reset()  pipeline_RESET() end
function UI_refill() pipeline_REFILL() end
function UI_randC()  pipeline_RANDOMIZE("C") end
function UI_randH()  pipeline_RANDOMIZE("H") end
function UI_randI()  pipeline_RANDOMIZE("I") end
function UI_check()  debugReport() end

function UI_add1000(_, player_color, alt_click)
  local target = resolveBuyerColor(player_color)
  local ok = moneyAdd(target, 1000)
  if ok then
    safeBroadcastAll("✅ DEBUG: +1000 WIN for "..tostring(target), {0.7,1,0.7})
  else
    safeBroadcastAll("⛔ DEBUG +1000 WIN: MoneyCtrl/API not working for "..tostring(target), {1,0.4,0.4})
  end
end

-- =========================
-- [S14B] NGO WORKER PERKS: Take Trip (free), Investment subsidy
-- =========================
-- Fallback defs when card display name is not an exact CONSUMABLE_DEF key (e.g. "Zero Gravity Flight", "A Visit to the Family Planning Centre")
local NATURE_TRIP_FALLBACK_DEF = { cost = 1000, extraAP = 2, kind = "NATURE_TRIP", countsAsTrip = true }
local FAMILY_FALLBACK_DEF      = { cost = 1000, extraAP = 0, kind = "FAMILY", countsAsTrip = true }
local function tripFallbackDefForName(name)
  if not name or name == "" then return nil end
  local u = string.upper(name)
  if string.find(u, "TRIP") or string.find(name, "Trip") then return NATURE_TRIP_FALLBACK_DEF end
  if string.find(u, "FAMILY") or string.find(u, "PLANNING") or string.find(u, "VISIT") then return FAMILY_FALLBACK_DEF end
  if string.find(u, "GRAVITY") or string.find(u, "ZERO") then return { cost = 3000, extraAP = 1, kind = "SAT", sat = 12, countsAsTrip = true } end
  if string.find(u, "PARACHUTE") then return { cost = 2000, extraAP = 1, kind = "SAT", sat = 8, countsAsTrip = true } end
  if string.find(u, "BUNGEE") then return { cost = 1500, extraAP = 1, kind = "SAT", sat = 6, countsAsTrip = true } end
  if string.find(u, "BALLOON") or string.find(u, "BALOON") then return { cost = 1000, extraAP = 1, kind = "SAT", sat = 4, countsAsTrip = true } end
  if string.find(u, "FLIGHT") then return { cost = 3000, extraAP = 1, kind = "SAT", sat = 12, countsAsTrip = true } end
  return nil
end

-- True if def (or name) counts as a "Trip" for NGO Take Trip (free) perk.
local function defCountsAsTrip(def, name)
  if def and (def.countsAsTrip or def.kind == "NATURE_TRIP" or def.kind == "FAMILY") then return true end
  if def and def.kind == "SAT" and (def.countsAsTrip or (name and (string.find(string.upper(name or ""), "GRAVITY") or string.find(string.upper(name or ""), "PARACHUTE") or string.find(string.upper(name or ""), "BUNGEE") or string.find(string.upper(name or ""), "BALLOON")))) then return true end
  return tripFallbackDefForName(name) ~= nil
end

-- Find all visible Trip cards: consumable row C, any card that counts as a trip (nature trip, family visit, zero gravity, parachute, bungee, balloon, etc.).
local function findAllVisibleTripCards()
  local list = {}
  if not ensureBoard() then return list end
  local function addIfTrip(o, requireOpenSlot)
    if not isCard(o) or classifyRowByName(o) ~= "C" then return end
    if requireOpenSlot and not isShopOpenSlotCard(o) then return end
    local name = getNameSafe(o)
    local def = CONSUMABLE_DEF[name]
    if def and defCountsAsTrip(def, name) then
      table.insert(list, { card = o, def = def })
      return
    end
    local fallback = tripFallbackDefForName(name)
    if fallback then
      table.insert(list, { card = o, def = fallback })
    end
  end
  for _, o in ipairs(getAllObjects()) do
    addIfTrip(o, true)
  end
  if #list == 0 then
    for _, o in ipairs(getAllObjects()) do
      addIfTrip(o, false)
    end
  end
  return list
end

-- Remove "Take this Trip (free)" buttons from all visible Trip cards (after player picked one or cancel)
local function clearNGOTakeTripButtons()
  local list = findAllVisibleTripCards()
  for _, entry in ipairs(list) do
    local card = entry.card
    if card and card.clearButtons then
      pcall(function() card.clearButtons() end)
    end
  end
  S.pendingNGOTakeTripColor = nil
end

-- NGO Worker L2: Show "Take this Trip (free)" on each visible Trip card; player picks one, then we apply effect and mark used.
function API_showNGOTakeTripChoice(params)
  params = params or {}
  local color = (type(params) == "table" and (params.color or params.player_color)) or params
  if type(color) ~= "string" or color == "" then return false end
  color = normalizeColor(color)
  local list = findAllVisibleTripCards()
  if #list == 0 then return false end
  S.pendingNGOTakeTripColor = color
  for _, entry in ipairs(list) do
    local card = entry.card
    if card and card.createButton then
      local g = card.getGUID()
      if not UI.homePos[g] then
        local p = card.getPosition()
        UI.homePos[g] = { x = p[1] or p.x, y = p[2] or p.y, z = p[3] or p.z }
      end
      pcall(function()
        -- Position high and at front of card (Y=0.7, Z=1.15) so button is on top and easy to click, not under other buttons
        card.createButton({
          click_function = "shop_ngoTakeThisTrip",
          function_owner = self,
          label = "Take this Trip\n(free)",
          position = {0, 0.7, 1.15},
          rotation = {0, 0, 0},
          width = 1200,
          height = 420,
          font_size = 130,
          color = {0.3, 0.85, 0.4, 0.95},
          font_color = {1, 1, 1, 1},
          tooltip = "NGO Take Trip (free) – use this card, no cost",
        })
      end)
    end
  end
  return true
end

-- Called when player clicks "Take this Trip (free)" on a Trip card: apply effect for that card only, mark perk used, clear other Trip buttons.
function shop_ngoTakeThisTrip(card, player_color, alt_click)
  if not (card and card.tag == "Card") then return end
  local color = S.pendingNGOTakeTripColor
  if not color or color == "" then
    clearNGOTakeTripButtons()
    return
  end
  local name = getNameSafe(card)
  local def = CONSUMABLE_DEF[name]
  if not def or not defCountsAsTrip(def, name) then
    def = tripFallbackDefForName(name)
  end
  if not def then
    clearNGOTakeTripButtons()
    return
  end
  clearNGOTakeTripButtons()
  local g = card.getGUID()
  if not UI.homePos[g] then
    local p = card.getPosition()
    UI.homePos[g] = { x = p[1] or p.x, y = p[2] or p.y, z = p[3] or p.z }
  end
  local effectResult = applyConsumableEffect(color, card, def)
  if effectResult == "WAIT_DICE" then
    safeBroadcastToColor("🌿 Trip (free): Roll the die, then click ROLL DICE on this card", color, {0.7,1,0.7})
  else
    -- Effect applied immediately (SAT, etc.) – discard card to used pile like normal purchase
    Wait.time(function()
      if card and card.tag == "Card" then
        stashPurchasedCard(card)
      end
      refreshShopOpenUI_later(0.25)
    end, 0.3)
  end
  local voc = firstWithTag(TAG_VOCATIONS_CTRL)
  if voc and voc.call then
    pcall(function() voc.call("VOC_MarkNGOTakeTripUsed", { color = color }) end)
  end
  broadcastToAll("🌿 " .. color .. " used NGO Take Trip (free) — took one Trip from the shop. (Once per level.)", {0.6,1,0.7})
end

-- =========================
-- [S15] PUBLIC API (for other controllers)
-- =========================
function API_reset(_)  pipeline_RESET();  return true end
function API_refill(_) pipeline_REFILL(); return true end

function API_randomize(args)
  args = args or {}
  local row = tostring(args.row or args.r or ""):upper()
  if row ~= "C" and row ~= "H" and row ~= "I" then return false end
  pipeline_RANDOMIZE(row)
  return true
end

function API_refreshUI(_)
  refreshShopOpenUI_later(0.10)
  return true
end

function API_getRestEquivalent(params)
  -- Returns rest-equivalent bonus for a player color (includes both temporary and permanent)
  -- params: {color="Yellow"} or just "Yellow"
  local color = params
  if type(params) == "table" then
    color = params.color or params.player_color or params[1]
  end
  if type(color) ~= "string" or color == "" then return 0 end
  
  -- Normalize color (capitalize first letter)
  color = color:sub(1,1):upper() .. color:sub(2):lower()
  
  local temp = S.restEquivalent[color] or 0
  local perm = S.permanentRestEquivalent[color] or 0
  return temp + perm
end

function API_clearRestEquivalent(params)
  -- Clears rest-equivalent bonus for a player color (called after using it in end-of-turn)
  -- params: {color="Yellow"} or just "Yellow"
  local color = params
  if type(params) == "table" then
    color = params.color or params.player_color or params[1]
  end
  if type(color) ~= "string" or color == "" then return false end
  
  -- Normalize color (capitalize first letter)
  color = color:sub(1,1):upper() .. color:sub(2):lower()
  
  S.restEquivalent[color] = 0
  return true
end

function API_ownsHiTech(params)
  -- Check if player owns a specific Hi-Tech card
  -- params: {color="Yellow", cardName="HSHOP_01_COFFEE"} or {color="Yellow", kind="COFFEE"}
  local color = params.color or params.player_color
  local cardName = params.cardName
  local kind = params.kind
  
  if type(color) ~= "string" or color == "" then return false end
  color = color:sub(1,1):upper() .. color:sub(2):lower()
  
  if cardName then
    return ownsHiTech(color, cardName)
  elseif kind then
    return ownsHiTechKind(color, kind)
  end
  
  return false
end

-- Process investment payments at start of turn
function API_processInvestmentPayments(params)
  -- Called at start of each turn to add investment payments to cost calculator
  -- params: {color="Yellow"} or just "Yellow"
  local color = params
  if type(params) == "table" then
    color = params.color or params.player_color or params[1]
  end
  if type(color) ~= "string" or color == "" then return false end
  color = normalizeColor(color)
  
  if not S.investments[color] then return true end
  
  local costsCalc = firstWithTag(TAG_COSTS_CALC)
  if not costsCalc or not costsCalc.call then
    warn("No Costs Calculator found for investment payments")
    return false
  end
  
  -- Process DEBENTURES payments
  if S.investments[color].debentures then
    local inv = S.investments[color].debentures
    if inv.paidCount < 3 then
      -- Add payment to cost calculator
      Costs_add(color, inv.investedPerTurn)
      inv.paidCount = inv.paidCount + 1
      inv.totalInvested = inv.totalInvested + (inv.investedPerTurn or 0)
      log("Debentures: "..color.." payment "..tostring(inv.paidCount).."/3 added to cost calculator")
      
      -- If 3 payments complete, update card button
      if inv.paidCount >= 3 then
        local card = getObjectFromGUID(inv.cardGUID)
        if card and card.tag == "Card" then
          pcall(function()
            card.clearButtons()
            card.createButton({
              click_function = "inv_debentures_cashOut",
              function_owner = self,
              label = "CASH OUT\n(WITH PROFIT)",
              position = {0, 0.33, 1.0},
              rotation = {0, 0, 0},
              width = 800,
              height = 300,
              font_size = 130,
              color = {0.9, 0.7, 0.2, 0.95},
              font_color = {1, 1, 1, 1},
              tooltip = "Cash out with 100% profit (200% return)",
            })
          end)
        end
      end
    end
  end
  
  -- Process LOAN payments
  if S.investments[color].loan then
    local inv = S.investments[color].loan
    if inv.paidInstalments < 4 then
      -- Add instalment to cost calculator
      Costs_add(color, inv.instalmentAmount)
      inv.paidInstalments = inv.paidInstalments + 1
      log("Loan: "..color.." instalment "..tostring(inv.paidInstalments).."/4 added to cost calculator")
    end
  end
  
  -- Process ENDOWMENT payments
  if S.investments[color].endowment then
    local inv = S.investments[color].endowment
    if inv.paidCount < inv.duration then
      -- Add payment to cost calculator
      Costs_add(color, inv.amountPerYear)
      inv.paidCount = inv.paidCount + 1
      inv.totalInvested = inv.totalInvested + (inv.amountPerYear or 0)
      log("Endowment: "..color.." payment "..tostring(inv.paidCount).."/"..inv.duration.." added to cost calculator")
      
      -- If all payments complete, show cash out button
      if inv.paidCount >= inv.duration then
        local card = getObjectFromGUID(inv.cardGUID)
        if card and card.tag == "Card" then
          pcall(function()
            card.clearButtons()
            local profitPct = (inv.duration == 2 and 50) or (inv.duration == 3 and 125) or 200
            card.createButton({
              click_function = "inv_endowment_cashOut",
              function_owner = self,
              label = "CASH OUT\n("..profitPct.."% profit)",
              position = {0, 0.33, 1.0},
              rotation = {0, 0, 0},
              width = 800,
              height = 300,
              font_size = 130,
              color = {0.9, 0.7, 0.2, 0.95},
              font_color = {1, 1, 1, 1},
              tooltip = "Cash out with "..profitPct.."% profit",
            })
          end)
        end
      end
    end
  end
  
  -- Process ESTATEINVEST payments (3×30% method)
  if S.investments[color].estateInvest then
    local inv = S.investments[color].estateInvest
    if inv.method == "3x30pct" and inv.paidCount < 3 then
      -- Add payment to cost calculator
      if costsCalc and costsCalc.call then
          Costs_add(color, inv.paymentAmount)
        inv.paidCount = inv.paidCount + 1
        inv.paidAmount = inv.paidAmount + (inv.paymentAmount or 0)
        log("EstateInvest: "..color.." payment "..tostring(inv.paidCount).."/3 added to cost calculator")
      end
    end
  end
  
  -- Deliver apartments for ESTATEINVEST (on next turn after purchase)
  if S.investments[color].estateInvest then
    local inv = S.investments[color].estateInvest
    if inv.deliveryPending == true then
      -- Deliver apartment this turn (next turn after purchase)
      inv.deliveryPending = false
      deliverEstateInvestApartment(color, inv.level)
    end
  end
  
  return true
end

-- Deliver apartment for ESTATEINVEST investment
local function deliverEstateInvestApartment(color, level)
  -- Find Estate Engine
  local TAG_MARKET_CTRL = "WLB_MARKET_CTRL"
  local estateEngine = nil
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_MARKET_CTRL) then
      estateEngine = o
      break
    end
  end
  
  if not estateEngine then
    warn("Estate Engine not found for apartment delivery")
    return false
  end
  
  -- Find appropriate deck for level
  local deckTag = "WLB_DECK_"..level
  local deck = nil
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(deckTag) and o.tag == "Deck" then
      deck = o
      break
    end
  end
  
  if not deck then
    warn("Estate deck not found for level "..level)
    return false
  end
  
  -- Take top card from deck (skip dummy cards)
  local card = nil
  local attempts = 0
  while attempts < 10 do
    local topCard = deck.takeObject({index=0})
    if not topCard then break end
    
    -- Check if dummy card
    local isDummy = false
    if topCard.hasTag and topCard.hasTag("WLB_ESTATE_DUMMY") then
      isDummy = true
    else
      local name = getNameSafe(topCard)
      if name and (string.find(name, "SOLD OUT") or string.find(name, " SOLD")) then
        isDummy = true
      end
    end
    
    if isDummy then
      -- Put dummy back at bottom and try next
      deck.putObject(topCard)
      attempts = attempts + 1
    else
      card = topCard
      break
    end
  end
  
  if not card then
    safeBroadcastToColor("⚠️ No estate card available for "..level, color, {1,0.7,0.2})
    return false
  end
  
  -- Place card on player board (similar to Estate Engine's placement logic)
  local TAG_PLAYER_BOARD = "WLB_BOARD"
  local TAG_COLOR_PREFIX = "WLB_COLOR_"
  local colorTagStr = TAG_COLOR_PREFIX .. color
  
  local board = nil
  for _,o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_PLAYER_BOARD) and o.hasTag(colorTagStr) then
      board = o
      break
    end
  end
  
  if not board then
    warn("Player board not found for "..color)
    deck.putObject(card)
    return false
  end
  
  -- Estate slot positions (local coordinates relative to board) - same as Estate Engine
  local ESTATE_SLOT_LOCAL = {
    Yellow = {x= 1.259, y=0.592, z=-0.238},
    Blue   = {x= 1.265, y=0.592, z=-0.198},
    Red    = {x= 1.134, y=0.592, z=-0.202},
    Green  = {x= 1.222, y=0.592, z=-0.301},
  }
  
  local slotPos = ESTATE_SLOT_LOCAL[color]
  if not slotPos then
    warn("No estate slot position for "..color)
    deck.putObject(card)
    return false
  end
  
  -- Convert local to world coordinates using board.positionToWorld (same as Estate Engine)
  local boardRot = board.getRotation()
  local okW, wp = pcall(function()
    return board.positionToWorld({x=slotPos.x, y=slotPos.y, z=slotPos.z})
  end)
  
  if not okW or type(wp) ~= "table" then
    warn("Failed to convert local to world coordinates for "..color)
    deck.putObject(card)
    return false
  end
  
  wp.y = (tonumber(wp.y) or 0) + 0.20  -- Slight Y offset to prevent sinking (same as Estate Engine)
  
  -- Tag card as owned (same tags as Estate Engine)
  -- Estate investment apartments are considered rented (not bought)
  local TAG_ESTATE_OWNED = "WLB_ESTATE_OWNED"
  local TAG_ESTATE_MODE_RENT = "WLB_ESTATE_MODE_RENT"
  
  pcall(function()
    card.addTag("WLB_ESTATE_CARD")
    card.addTag(TAG_ESTATE_OWNED)
    card.addTag(TAG_ESTATE_MODE_RENT)  -- Estate investment apartments are rented
    card.addTag(colorTagStr)
  end)
  
  -- Place card on board (same as Estate Engine)
  pcall(function()
    card.setPositionSmooth({wp.x, wp.y, wp.z}, false, true)
    card.setRotationSmooth({0, boardRot.y, 0}, false, true)
  end)
  
  -- CRITICAL: Update Estate Engine state and TokenEngine housing level
  Wait.time(function()
    -- Update Estate Engine's currentEstateLevel for rental cost tracking
    local TAG_MARKET_CTRL = "WLB_MARKET_CTRL"
    local estateEngine = nil
    for _,o in ipairs(getAllObjects()) do
      if o and o.hasTag and o.hasTag(TAG_MARKET_CTRL) then
        estateEngine = o
        break
      end
    end
    
    if estateEngine and estateEngine.call then
      -- Try to call Estate Engine API to update state
      safeCall(function()
        pcall(function()
          -- Call updateRentalCostInCalculator indirectly by calling Estate Engine's API if available
          -- For now, we'll directly update rental cost in calculator (delta from L0 to new level)
          local ESTATE_RENTAL_COST = {
            L0=50, L1=200, L2=350, L3=550, L4=1000
          }
          local oldLevel = "L0"  -- Assume L0 before delivery
          local newLevel = level
          local oldCost = ESTATE_RENTAL_COST[oldLevel] or 0
          local newCost = ESTATE_RENTAL_COST[newLevel] or 0
          local delta = newCost - oldCost
          
          if delta ~= 0 then
            Costs_add(color, delta)
            log("EstateInvest delivery: Adjusted rental cost by "..tostring(delta).." WIN for "..color.." (from "..oldLevel.." to "..newLevel..")")
          end
        end)
      end)
    end
    
    -- Update TokenEngine housing level for correct token placement
    local TAG_TOKEN_ENGINE = "WLB_TOKEN_SYSTEM"
    local tokenEngine = nil
    for _,o in ipairs(getAllObjects()) do
      if o and o.hasTag and o.hasTag(TAG_TOKEN_ENGINE) then
        tokenEngine = o
        break
      end
    end
    
    if tokenEngine and tokenEngine.call then
      safeCall(function()
        pcall(function()
          tokenEngine.call("TE_SetHousing_ARGS", { color = color, level = level })
        end)
      end)
      log("EstateInvest delivery: Updated TokenEngine housing to "..level.." for "..color)
    end
  end, 0.3)  -- Small delay to ensure card placement is complete
  
  safeBroadcastAll("🏠 "..color.." received "..level.." apartment from Estate Investment!", {0.8,0.9,1})
  return true
end

-- ENDOWMENT cash out handler
function inv_endowment_cashOut(card, player_color, alt_click)
  if not (card and card.tag=="Card") then return end
  local color = normalizeColor(player_color)
  if not S.investments[color] or not S.investments[color].endowment then return end
  
  local inv = S.investments[color].endowment
  if inv.paidCount < inv.duration then
    safeBroadcastToColor("⛔ Endowment: All payments not yet complete ("..inv.paidCount.."/"..inv.duration..")", color, {1,0.6,0.2})
    return
  end
  
  local totalInvested = inv.totalInvested or (inv.amountPerYear * inv.duration)
  local payout = 0
  
  -- Calculate payout based on duration
  if inv.duration == 2 then
    payout = math.floor(totalInvested * 1.5)  -- 50% profit
  elseif inv.duration == 3 then
    payout = math.floor(totalInvested * 2.25)  -- 125% profit
  elseif inv.duration == 4 then
    payout = math.floor(totalInvested * 3.0)  -- 200% profit
  else
    safeBroadcastToColor("⚠️ Invalid duration", color, {1,0.7,0.2})
    return
  end
  
  local profit = payout - totalInvested
  local ok = moneyAdd(color, payout)
  if ok then
    safeBroadcastAll("💰 "..color.." cashed out Endowment ("..inv.duration.." years): Received "..tostring(payout).." WIN (invested "..tostring(totalInvested)..", profit "..tostring(profit)..")", {0.9,1,0.6})
  else
    safeBroadcastToColor("⚠️ Failed to add payout", color, {1,0.7,0.2})
    return
  end
  
  -- Clear investment state
  S.investments[color].endowment = nil
  
  -- Remove card buttons and stash card
  pcall(function() card.clearButtons() end)
  Wait.time(function()
    if card and card.tag=="Card" then
      stashPurchasedCard(card)
    end
  end, 0.3)
end

-- Force payment of remaining loans at end of game
function API_processEndOfGameLoans(params)
  -- Called at end of game to force payment of all remaining loans
  -- params: optional, can be empty
  local costsCalc = firstWithTag(TAG_COSTS_CALC)
  if not costsCalc or not costsCalc.call then
    warn("No Costs Calculator found for end-of-game loan processing")
    return false
  end
  
  -- Process all players' loans
  for color, invData in pairs(S.investments) do
    if invData.loan then
      local inv = invData.loan
      if inv.paidInstalments < 4 then
        local remainingInstalments = 4 - inv.paidInstalments
        local totalRemaining = remainingInstalments * inv.instalmentAmount
        
        -- Add remaining balance to cost calculator
        safeCall(function()
          costsCalc.call("addCost", {color=color, amount=totalRemaining})
        end)
        
        safeBroadcastAll("💰 End of Game: "..color.." must pay remaining loan balance: "..tostring(totalRemaining).." WIN ("..remainingInstalments.." instalments)", {1,0.8,0.2})
        log("End of Game: "..color.." loan - added "..totalRemaining.." WIN to cost calculator")
      end
    end
  end
  
  return true
end

function API_getOwnedHiTech(params)
  -- Get list of owned Hi-Tech cards for a player
  -- params: {color="Yellow"}
  local color = params.color or params.player_color
  if type(color) ~= "string" or color == "" then return {} end
  
  color = normalizeColor(color)
  
  -- Return copy of owned cards list
  if S.ownedHiTech[color] then
    local result = {}
    for _, name in ipairs(S.ownedHiTech[color]) do
      table.insert(result, name)
    end
    return result
  end
  
  return {}
end

-- =========================
-- [S16] SAVE / LOAD
-- =========================
function onSave()
  -- Save state including pillsUseCount, restEquivalent, ownedHiTech, permanentRestEquivalent, and investments
  local stateToSave = {
    pillsUseCount = S.pillsUseCount,
    restEquivalent = S.restEquivalent,
    boughtThisTurn = S.boughtThisTurn,
    lastTurnColor = S.lastTurnColor,
    ownedHiTech = S.ownedHiTech,
    permanentRestEquivalent = S.permanentRestEquivalent,
    investments = S.investments
  }
  return JSON.encode(stateToSave)
end

function onLoad(saved_data)
  -- Load persisted state
  if saved_data and saved_data ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if ok and type(data) == "table" then
      if data.pillsUseCount then
        S.pillsUseCount = data.pillsUseCount
      end
      if data.restEquivalent then
        S.restEquivalent = data.restEquivalent
      end
      if data.boughtThisTurn then
        S.boughtThisTurn = data.boughtThisTurn
      end
      if data.lastTurnColor then
        S.lastTurnColor = data.lastTurnColor
      end
      if data.ownedHiTech then
        -- Migrate: normalize color keys in ownedHiTech (merge unnormalized keys like "red" into normalized "Red")
        local normalizedOwnedHiTech = {}
        for oldColor, cards in pairs(data.ownedHiTech) do
          local newColor = normalizeColor(oldColor)
          if not normalizedOwnedHiTech[newColor] then
            normalizedOwnedHiTech[newColor] = {}
          end
          if type(cards) == "table" then
            -- Merge cards, avoiding duplicates
            for _, cardName in ipairs(cards) do
              local found = false
              for _, existingName in ipairs(normalizedOwnedHiTech[newColor]) do
                if existingName == cardName then found = true break end
              end
              if not found then
                table.insert(normalizedOwnedHiTech[newColor], cardName)
              end
            end
          end
        end
        S.ownedHiTech = normalizedOwnedHiTech
      end
      if data.permanentRestEquivalent then
        S.permanentRestEquivalent = data.permanentRestEquivalent
      end
      if data.investments then
        -- Normalize color keys in investments
        local normalizedInvestments = {}
        for oldColor, invData in pairs(data.investments) do
          local newColor = normalizeColor(oldColor)
          normalizedInvestments[newColor] = invData
        end
        S.investments = normalizedInvestments
      end
    end
  end
  
  -- Ensure state tables exist
  S.pillsUseCount = S.pillsUseCount or { Yellow=0, Blue=0, Red=0, Green=0 }
  S.restEquivalent = S.restEquivalent or { Yellow=0, Blue=0, Red=0, Green=0 }
  S.boughtThisTurn = S.boughtThisTurn or {}
  S.investments = S.investments or { Yellow={}, Blue={}, Red={}, Green={} }
  
  drawUI()
  ensureBoard()
  S.lastTurnColor = getActiveTurnColor()

  log("Loaded v"..VERSION)

  Wait.time(function()
    refreshShopOpenUI()
  end, 0.35)
end
