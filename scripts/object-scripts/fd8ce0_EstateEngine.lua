-- =========================================================
-- WLB MARKET ENGINE v1.8.1 (ESTATES) - FIX: Player Yellow + RETURN/SELL VISIBLE
--  ✅ Fix broadcastToColor: normalize "Player Yellow" -> "Yellow"
--  ✅ RETURN/SELL buttons forced to safe visible position (center-top)
--  ✅ RETURN/SELL returns to TOP of deck via drop-from-above
-- =========================================================

local DEBUG = true

-- =========================
-- TAGS / CONFIG
-- =========================
local TAG_MARKET_CTRL   = "WLB_MARKET_CTRL"

local TAG_ESTATE_CARD   = "WLB_ESTATE_CARD"
local TAG_ESTATE_DUMMY  = "WLB_ESTATE_DUMMY"
local TAG_ESTATE_DECK   = "WLB_ESTATE_DECK"

local TAG_DECK_L1 = "WLB_DECK_L1"
local TAG_DECK_L2 = "WLB_DECK_L2"
local TAG_DECK_L3 = "WLB_DECK_L3"
local TAG_DECK_L4 = "WLB_DECK_L4"

local TAG_PLAYERBOARD   = "WLB_BOARD"
local TAG_AP_CTRL       = "WLB_AP_CTRL"
local TAG_TOKEN_ENGINE  = "WLB_TOKEN_SYSTEM"
local TAG_PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL"
local TAG_MONEY         = "WLB_MONEY"
local TAG_COSTS_CALC    = "WLB_COSTS_CALC"
local TAG_STATUS_VOUCH_P    = "WLB_STATUS_VOUCH_P"
-- Property vouchers: only 2 exist in the game → max 40% discount (2 × 20%)
local PROPERTY_VOUCHER_MAX  = 2
local COLOR_TAG_PREFIX  = "WLB_COLOR_"
local TAG_PLAYERBOARD   = "WLB_BOARD"

-- placed/ownership tags
local TAG_ESTATE_OWNED     = "WLB_ESTATE_OWNED"
local TAG_ESTATE_MODE_RENT = "WLB_ESTATE_MODE_RENT"
local TAG_ESTATE_MODE_BUY  = "WLB_ESTATE_MODE_BUY"

-- Names (prefix detection)
local CARD_L1 = "ESTATE_L1"
local CARD_L2 = "ESTATE_L2"
local CARD_L3 = "ESTATE_L3"
local CARD_L4 = "ESTATE_L4"

-- AP rules
local AP_SPEND_TO = "E"
local AP_COST = 1

-- Estate prices (buy prices in WIN/VIN)
local ESTATE_PRICE = { 
  L1=2000,   -- Studio apartment
  L2=3500,   -- Flat with 3 rooms
  L3=5500,   -- House in the suburbs
  L4=10000   -- Mansion
}
local SELL_REFUND_FACTOR = 0.5

-- Rental costs per turn (10% of purchase price, or 50 for L0 default)
local ESTATE_RENTAL_COST = {
  L0=50,     -- Room in grandma's house (default, printed on board)
  L1=200,    -- Studio apartment (10% of 2000)
  L2=350,    -- Flat with 3 rooms (10% of 3500)
  L3=550,    -- House in suburbs (10% of 5500)
  L4=1000    -- Mansion (10% of 10000)
}

-- Tile UI
local TILE_UIY = 0.22
local TILE_BTN_W = 1150
local TILE_BTN_H = 520
local TILE_BTN_FS = 170
local TILE_BTN_H_BIG = 900
local TILE_BTN_FS_BIG = 190

-- Deck UI
local STAGE_PROMPT  = 1
local STAGE_ACTIONS = 2
local UI_ROT_Y_DECK = 0

local PROMPT_TIP = "What would you like to do with this property?"
local PROMPT_W     = 1200
local PROMPT_H     = 520
local PROMPT_LABEL = "⋯"
local PROMPT_FS    = 180
local PROMPT_BG    = {0, 0, 0, 0.25}
local PROMPT_FC    = {1, 1, 1, 1}

local ACTIONS_Z_SPREAD = 1.45
local COL_RENT_BG    = {0.18, 0.50, 1.00, 1.00}
local COL_RENT_FC    = {1,1,1,1}
local COL_NOTHING_BG = {0.80, 0.80, 0.80, 1.00}
local COL_NOTHING_FC = {0,0,0,1}
local COL_BUY_BG     = {0.20, 0.85, 0.25, 1.00}
local COL_BUY_FC     = {0,0,0,1}

-- =========================
-- ESTATE SLOT LOCAL@BOARD (playerboards)
-- =========================
local ESTATE_SLOT_LOCAL = {
  Yellow = {x= 1.259, y=0.592, z=-0.238},
  Blue   = {x= 1.265, y=0.592, z=-0.198},
  Red    = {x= 1.134, y=0.592, z=-0.202},
  Green  = {x= 1.222, y=0.592, z=-0.301},
}

-- =========================
-- SHOPBOARD PARKING LOCAL@SHOPBOARD (measured)
-- =========================
local SHOPBOARD_GUID = "2df5f1" -- Shops Board
local SHOP_PARK_LOCAL = {
  L1 = {x=-2.758, y=0.592, z=-3.638},
  L2 = {x=-5.795, y=0.592, z=-3.665},
  L3 = {x=-2.742, y=0.592, z= 1.392},
  L4 = {x=-5.783, y=0.592, z= 1.271},
}
local PARK_LIFT_Y = 0.20

-- PARK sequencing / safety
local PARK_LOCK = false
local PARK_LOCK_TOKEN = 0
local PARK_TIMEOUT_S = 14.0

-- HOW we stack REAL on top:
local STACK_HEIGHT_BASE = 2.2
local STACK_HEIGHT_STEP = 0.35
local STACK_STEP_DELAY  = 0.18
local AFTER_STACK_DELAY = 0.30

-- RETURN/Sell top-merge (drop from above)
local RETURN_DROP_HEIGHT = 3.2
local RETURN_MERGE_DELAY = 0.45

-- Card button (Return/Sell) - SAFE VISIBLE PLACE
local CARD_BTN_W  = 720
local CARD_BTN_H  = 260
local CARD_BTN_FS = 150
local CARD_BTN_POS = {0.00, 0.33, 1.05}   -- center-ish, high enough to see
local CARD_BTN_ROT = {0, 0, 0}            -- do NOT rotate 180

local TAG_SHOP_ENGINE = "WLB_SHOP_ENGINE"

-- =========================
-- STATE
-- =========================
local S = {
  decks = { L1=nil, L2=nil, L3=nil, L4=nil },
  parking = { L1=nil, L2=nil, L3=nil, L4=nil },
  deckStage = {},
  shopboard = nil,
  enteredEstateThisTurn = { Yellow=false, Blue=false, Red=false, Green=false },  -- Per-turn entry tracking (like Shop Engine)
  currentEstateLevel = { Yellow="L0", Blue="L0", Red="L0", Green="L0" },  -- Track current rental level per player (L0 = grandma's house)
  currentEstateIsRented = { Yellow=false, Blue=false, Red=false, Green=false },  -- true = pay rent, false = owned (L0 or bought)
  pendingEstateVoucher = nil,  -- { level, acting, voucherCount, step } when asking "Use discount?"
}

-- =========================
-- HELPERS
-- =========================
local function log(msg)  if DEBUG then print("[WLB MARKET] "..tostring(msg)) end end
local function warn(msg) print("[WLB MARKET][WARN] "..tostring(msg)) end

local function safeCall(fn)
  local ok, res = pcall(fn)
  if ok then return true, res end
  return false, nil
end

local function isAlive(o)
  if not o then return false end
  return pcall(function() return o.getGUID() end)
end

local function addTagSafe(o, tag)
  if isAlive(o) and o.addTag then pcall(function() o.addTag(tag) end) end
end

local function removeTagSafe(o, tag)
  if isAlive(o) and o.removeTag then pcall(function() o.removeTag(tag) end) end
end

local function colorTag(c) return COLOR_TAG_PREFIX .. tostring(c) end

local function getNameSafe(obj)
  if not obj then return nil end
  local ok, name = pcall(function() return obj.getName() end)
  if ok and name and name ~= "" then return name end
  return nil
end

local function normalizeColor(c)
  if c == nil then return nil end
  local s = tostring(c)
  -- common problematic prefix
  s = s:gsub("^Player%s+", "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")

  local low = string.lower(s)
  local map = {
    yellow="Yellow", blue="Blue", red="Red", green="Green",
    white="White", brown="Brown", teal="Teal", orange="Orange",
    purple="Purple", pink="Pink", black="Black", grey="Grey", gray="Grey"
  }
  return map[low] or s
end

local function isPlayableColor(c)
  c = normalizeColor(c)
  return c=="Yellow" or c=="Blue" or c=="Red" or c=="Green"
end

local function sayToColor(color, msg, col)
  col = col or {1,1,1}
  color = normalizeColor(color)

  if not isPlayableColor(color) then
    broadcastToAll(msg, col)
    return
  end

  -- NEVER throw: wrap in pcall
  pcall(function()
    broadcastToColor(msg, color, col)
  end)
end

-- Find Token Engine for token removal/return operations
local function findTokenEngine()
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_TOKEN_ENGINE) then
      return o
    end
  end
  return nil
end

-- Find PlayerStatusController for voucher count / remove
local function findPSC()
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_PLAYER_STATUS_CTRL) then return o end
  end
  return nil
end

local function pscGetStatusCount(color, statusTag)
  local psc = findPSC()
  if not psc or not psc.call then return 0 end
  local ok, ret = pcall(function() return psc.call("PS_Event", { color = color, op = "GET_STATUS_COUNT", statusTag = statusTag }) end)
  if ok and type(ret) == "number" then return math.max(0, math.floor(ret)) end
  return 0
end

local function pscRemoveStatusCount(color, statusTag, count)
  local psc = findPSC()
  if not psc or not psc.call then return false end
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count == 0 then return true end
  local ok, ret = pcall(function() return psc.call("PS_Event", { color = color, op = "REMOVE_STATUS_COUNT", statusTag = statusTag, count = count }) end)
  return ok and ret
end

-- Call Token Engine to remove tokens to safe park
local function removeTokensToSafePark(color)
  local tokenEngine = findTokenEngine()
  if not tokenEngine or not tokenEngine.call then
    warn("Token Engine not found for remove tokens")
    return false
  end
  local ok, res = pcall(function()
    return tokenEngine.call("TE_RemoveTokensToSafePark", color)
  end)
  return ok
end

-- Call Token Engine to return tokens from safe park
local function returnTokensFromSafePark(color)
  local tokenEngine = findTokenEngine()
  if not tokenEngine or not tokenEngine.call then
    warn("Token Engine not found for return tokens")
    return false
  end
  local ok, res = pcall(function()
    return tokenEngine.call("TE_ReturnTokensFromSafePark", color)
  end)
  return ok
end

local function getActingColor(clickedColor)
  if Turns and Turns.turn_color and isPlayableColor(Turns.turn_color) then
    return normalizeColor(Turns.turn_color)
  end
  if isPlayableColor(clickedColor) then return normalizeColor(clickedColor) end
  return nil
end

local function getLevelFromCardName(name)
  name = tostring(name or "")
  local up = string.upper(name)
  if string.find(up, CARD_L1, 1, true) == 1 then return "L1" end
  if string.find(up, CARD_L2, 1, true) == 1 then return "L2" end
  if string.find(up, CARD_L3, 1, true) == 1 then return "L3" end
  if string.find(up, CARD_L4, 1, true) == 1 then return "L4" end
  return nil
end

local function isDummyCard(card)
  if not isAlive(card) then return false end
  if card.hasTag and card.hasTag(TAG_ESTATE_DUMMY) then return true end
  local nm = tostring(card.getName() or "")
  local up = string.upper(nm)
  if string.find(up, "SOLD OUT", 1, true) ~= nil then return true end
  if string.find(up, " SOLD", 1, true) ~= nil then return true end
  return false
end

local function classifyRealEstateCard(card)
  if not isAlive(card) then return nil end
  if card.tag ~= "Card" then return nil end
  local nm = tostring(card.getName() or "")
  local lvl = getLevelFromCardName(nm)
  if not lvl then return nil end
  if isDummyCard(card) then return nil end
  return lvl
end

-- =========================
-- SHOPBOARD + PARKING
-- =========================
local function ensureShopboard()
  if S.shopboard and isAlive(S.shopboard) and S.shopboard.getGUID() == SHOPBOARD_GUID then return true end
  local o = getObjectFromGUID(SHOPBOARD_GUID)
  if o then S.shopboard = o return true end
  S.shopboard = nil
  return false
end

local function ensureParkingWorld()
  if not ensureShopboard() then
    warn("ShopBoard missing GUID="..tostring(SHOPBOARD_GUID))
    return false
  end
  for _,lvl in ipairs({"L1","L2","L3","L4"}) do
    local l = SHOP_PARK_LOCAL[lvl]
    local okW, wp = safeCall(function()
      return S.shopboard.positionToWorld({x=l.x, y=l.y, z=l.z})
    end)
    if okW and type(wp)=="table" then
      wp.y = (tonumber(wp.y) or 0) + PARK_LIFT_Y
      S.parking[lvl] = {x=wp.x, y=wp.y, z=wp.z}
    end
  end
  return true
end

local function moveToWorld(pos, obj, rotY, smooth)
  if not isAlive(obj) then return end
  rotY = rotY or 180
  smooth = (smooth == true)
  pcall(function()
    obj.setPositionSmooth({pos.x,pos.y,pos.z}, smooth, true)
    obj.setRotationSmooth({0, rotY, 0}, smooth, true)
  end)
end

-- =========================
-- DECK LOOKUP (by tags)
-- =========================
local function findDeckByTag(tag)
  local list = getObjectsWithTag(tag) or {}
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_ESTATE_DECK) then return o end
  end
  return nil
end

local function refreshDeckRefs()
  S.decks.L1 = findDeckByTag(TAG_DECK_L1)
  S.decks.L2 = findDeckByTag(TAG_DECK_L2)
  S.decks.L3 = findDeckByTag(TAG_DECK_L3)
  S.decks.L4 = findDeckByTag(TAG_DECK_L4)
end

-- =========================
-- PLAYERBOARD FINDER
-- =========================
local function boundsArea(o)
  local ok, b = pcall(function() return o.getBoundsNormalized() end)
  if not ok or type(b) ~= "table" or type(b.size) ~= "table" then return 0 end
  local x = tonumber(b.size.x) or 0
  local z = tonumber(b.size.z) or 0
  return x * z
end

local function findPlayerBoard(color)
  color = normalizeColor(color)
  local list = getObjectsWithTag(colorTag(color)) or {}
  local best, bestArea = nil, -1
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_PLAYERBOARD) then
      local a = boundsArea(o)
      if a > bestArea then bestArea, best = a, o end
    end
  end
  return best
end

-- =========================
-- OWNED ESTATE DETECTOR
-- =========================
local function findOwnedEstateOnBoard(color)
  color = normalizeColor(color)
  if not color or color == "" then return nil, nil end
  
  -- Search for estate cards: must have player's color tag, ESTATE_CARD tag, and ESTATE_OWNED tag
  -- This ensures we only find cards that actually belong to this player
  local colorTagStr = colorTag(color)
  local list = getObjectsWithTag(colorTagStr) or {}
  
  for _,o in ipairs(list) do
    if isAlive(o) and o.tag == "Card" and o.hasTag then
      -- Must have ALL of these tags: color tag, estate card tag, and owned tag
      if o.hasTag(TAG_ESTATE_CARD) and o.hasTag(TAG_ESTATE_OWNED) and o.hasTag(colorTagStr) then
        -- Verify card name matches estate pattern (ESTATE_L1, ESTATE_L2, etc.)
        local cardName = getNameSafe(o)
        if cardName then
          local lvl = getLevelFromCardName(cardName)
          if lvl then 
            log("findOwnedEstateOnBoard: Found "..lvl.." estate for "..color)
            return o, lvl 
          end
        end
      end
    end
  end
  
  log("findOwnedEstateOnBoard: No estate found for "..color)
  return nil, nil
end

-- =========================
-- CARD BUTTONS (RETURN/SELL)
-- =========================
local function clearCardButtons(card)
  if isAlive(card) and card.clearButtons then
    safeCall(function() card.clearButtons() end)
  end
end

local function attachReturnOrSellButton(card)
  if not isAlive(card) then return end

  clearCardButtons(card)

  local label = "RETURN"
  if card.hasTag and card.hasTag(TAG_ESTATE_MODE_BUY) then label = "SELL" end

  safeCall(function()
    card.createButton({
      label = label,
      click_function = "ME_returnOrSellEstate",
      function_owner = self,
      position = CARD_BTN_POS,
      rotation = CARD_BTN_ROT,
      width = CARD_BTN_W,
      height = CARD_BTN_H,
      font_size = CARD_BTN_FS,
      color = {0,0,0,0.60},
      font_color = {1,1,1,1},
      tooltip = (label=="SELL")
        and "Sell this estate (refund 1/2 price) and return it to agency"
        or  "Return this rented estate to agency",
    })
  end)
end

local function returnEstateToDeckTop(card)
  if not isAlive(card) then return false end
  refreshDeckRefs()

  local lvl = getLevelFromCardName(card.getName())
  if not lvl then return false end

  local deck = S.decks[lvl]
  if not isAlive(deck) then return false end

  local dp = deck.getPosition()
  local dr = deck.getRotation()

  -- Remove all ownership and mode tags
  removeTagSafe(card, TAG_ESTATE_OWNED)
  removeTagSafe(card, TAG_ESTATE_MODE_RENT)
  removeTagSafe(card, TAG_ESTATE_MODE_BUY)
  
  -- Remove color tags (critical: prevents ownership detection bugs)
  -- Find all color tags on the card and remove them
  for _, color in ipairs({"Yellow", "Blue", "Red", "Green"}) do
    removeTagSafe(card, colorTag(color))
  end

  pcall(function()
    if card.unlock then card.unlock() end
    card.setRotationSmooth({0, dr.y, 0}, false, true)
    card.setPositionSmooth({dp.x, dp.y + RETURN_DROP_HEIGHT, dp.z}, false, true)
  end)

  Wait.time(function()
    if not isAlive(card) then return end
    if card.tag == "Card" then
      pcall(function()
        card.setRotationSmooth({0, dr.y, 0}, false, true)
        card.setPositionSmooth({dp.x, dp.y + (RETURN_DROP_HEIGHT + 0.6), dp.z}, false, true)
      end)
    end
  end, RETURN_MERGE_DELAY)

  return true
end

-- =========================
-- PLACE CARD ON BOARD
-- =========================
local function placeCardOnBoard(card, color)
  color = normalizeColor(color)
  local board = findPlayerBoard(color)
  if not board then return false, "No playerboard for "..tostring(color) end
  local off = ESTATE_SLOT_LOCAL[color]
  if not off then return false, "No ESTATE_SLOT_LOCAL for "..tostring(color) end

  local br = board.getRotation()
  local okW, wp = safeCall(function()
    return board.positionToWorld({x=off.x, y=off.y, z=off.z})
  end)
  if not okW or type(wp)~="table" then return false, "board.positionToWorld failed" end

  wp.y = (tonumber(wp.y) or 0) + 0.20
  safeCall(function() card.setPositionSmooth({wp.x,wp.y,wp.z}, false, true) end)
  safeCall(function() card.setRotationSmooth({0, br.y, 0}, false, true) end)

  addTagSafe(card, TAG_ESTATE_CARD)
  addTagSafe(card, TAG_ESTATE_OWNED)
  addTagSafe(card, colorTag(color))

  return true, ""
end

-- =========================
-- MONEY SPEND
-- =========================
local function findMoneyCtrlForColor(color)
  color = normalizeColor(color)
  local ctag = colorTag(color)

  -- IMPORTANT:
  -- If both exist (legacy money tile + new money-on-board), we must prefer the board
  -- to avoid using the old tile by accident.

  -- 1) Player board with embedded money API (PlayerBoardController_Shared)
  local boards = getObjectsWithTag(TAG_PLAYERBOARD) or {}
  for _,b in ipairs(boards) do
    if b and b.hasTag and b.hasTag(ctag) and b.call then
      local ok = pcall(function() return b.call("getMoney") end)
      if ok then return b end
    end
  end

  -- 2) Legacy money tile
  local list = getObjectsWithTag(TAG_MONEY) or {}
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(ctag) then return o end
  end

  return nil
end

local function moneyTrySpend(color, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  
  color = normalizeColor(color)
  local moneyCtrl = findMoneyCtrlForColor(color)
  if not moneyCtrl or not moneyCtrl.call then
    sayToColor(color, "⛔ Money controller not found.", {1,0.6,0.2})
    return false
  end
  
  local ok, result = safeCall(function()
    return moneyCtrl.call("API_spend", {amount=amount})
  end)
  
  if not ok then
    sayToColor(color, "⛔ Money spend failed.", {1,0.6,0.2})
    return false
  end
  
  if type(result) == "table" and result.ok == false then
    local reason = result.reason or "insufficient_funds"
    if reason == "insufficient_funds" then
      sayToColor(color, "⛔ Not enough money. Need "..tostring(amount).." WIN, have "..tostring(result.money or 0).." WIN.", {1,0.6,0.2})
    else
      sayToColor(color, "⛔ Money spend failed: "..tostring(reason), {1,0.6,0.2})
    end
    return false
  end
  
  return true
end

-- =========================
-- COSTS CALCULATOR INTEGRATION
-- =========================
local function findCostsCalculator()
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_COSTS_CALC) then
      return o
    end
  end
  return nil
end

-- Get vocation for a player color (for Social Worker 50% rent discount)
local function getVocationForColor(c)
  if not c or c == "" then return nil end
  local list = getObjectsWithTag("WLB_VOCATIONS_CTRL") or {}
  local voc = list[1]
  if not voc or not voc.call then return nil end
  local ok, vocation = pcall(function() return voc.call("VOC_GetVocation", { color = c }) end)
  if ok and type(vocation) == "string" then return vocation end
  return nil
end

-- Update rental cost in cost calculator when estate changes
-- IMPORTANT: TurnController adds rental costs every turn at turn start.
-- This function adjusts costs immediately when estate level changes mid-turn.
-- Strategy: Simply calculate delta between old and new rental costs, then adjust.
-- We use S.currentEstateLevel as the source of truth for what level the player currently has.
-- isRent: true when player just rented (apply Social Worker 50% same-turn); false when bought.
local function updateRentalCostInCalculator(color, oldLevel, newLevel, isRent)
  color = normalizeColor(color)
  if not color or color == "" then return end
  
  -- Get old level from state if not provided (this is the source of truth)
  local effectiveOldLevel = oldLevel
  if not effectiveOldLevel or effectiveOldLevel == "" then
    effectiveOldLevel = S.currentEstateLevel[color] or "L0"
  end
  
  -- Ensure it's a valid level
  if effectiveOldLevel ~= "L0" and effectiveOldLevel ~= "L1" and effectiveOldLevel ~= "L2" and effectiveOldLevel ~= "L3" and effectiveOldLevel ~= "L4" then
    effectiveOldLevel = "L0"
  end
  
  -- Only update if estate level actually changed
  if effectiveOldLevel == newLevel then
    log("Estate rental: No change for "..color.." (stays at "..tostring(effectiveOldLevel).."), skipping cost update")
    return
  end
  
  local costsCalc = findCostsCalculator()
  if not costsCalc or not costsCalc.call then
    warn("Costs Calculator not found for rental cost update")
    return
  end
  
  -- Get current cost from calculator for logging
  local currentCost = 0
  local okGet, currentCostResult = pcall(function()
    return costsCalc.call("getCost", {color=color})
  end)
  if okGet and type(currentCostResult) == "number" then
    currentCost = currentCostResult
  end
  
  -- Calculate costs for old and new levels
  local oldCost = ESTATE_RENTAL_COST[effectiveOldLevel] or 0
  local newCost = ESTATE_RENTAL_COST[newLevel] or 0
  local delta = newCost - oldCost
  
  -- Social Worker passive: 50% rent for rented apartment. Apply same-turn when player just rented (isRent=true).
  if delta > 0 and isRent and getVocationForColor(color) == "SOCIAL_WORKER" then
    delta = math.floor(delta * 0.5)
  end
  
  -- Adjust by the delta (this correctly transitions from old cost to new cost)
  if delta ~= 0 then
    safeCall(function()
      costsCalc.call("addCost", {color=color, amount=delta, label="Rent "..tostring(effectiveOldLevel).."→"..tostring(newLevel)})
    end)
    log("Estate rental: "..color.." adjusted cost by "..tostring(delta).." WIN (from "..tostring(effectiveOldLevel).."="..tostring(oldCost).." to "..tostring(newLevel).."="..tostring(newCost)..", was "..tostring(currentCost)..", now "..tostring(currentCost + delta)..")")
  else
    log("Estate rental: No adjustment needed for "..color.." (cost already correct)")
  end
end

-- =========================
-- AP SPEND
-- =========================
local function findApCtrlForColor(color)
  color = normalizeColor(color)
  local list = getObjectsWithTag(TAG_AP_CTRL) or {}
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(colorTag(color)) then return o end
  end
  return nil
end

local function apTrySpend1(color)
  color = normalizeColor(color)
  local ap = findApCtrlForColor(color)
  if not ap then return false end

  local okCan, can = safeCall(function()
    return ap.call("canSpendAP", {to=AP_SPEND_TO, amount=AP_COST})
  end)
  if okCan and can == false then return false end

  local okSpend, spent = safeCall(function()
    return ap.call("spendAP", {to=AP_SPEND_TO, amount=AP_COST})
  end)
  if okSpend then
    if spent == nil then return true end
    if type(spent)=="boolean" then return spent end
    if type(spent)=="table" and spent.ok~=nil then return spent.ok==true end
  end
  return false
end

-- =========================
-- ESTATE ENTRY AP (CAR + Per-Turn Tracking)
-- =========================
local function findShopEngine()
  local list = getObjectsWithTag(TAG_SHOP_ENGINE) or {}
  for _,o in ipairs(list) do
    if o and o.hasTag and o.hasTag(TAG_SHOP_ENGINE) then return o end
  end
  return nil
end

-- Check if player owns CAR Hi-Tech card
local function hasCarEntryFree(color)
  color = normalizeColor(color)
  if not color or color == "" then return false end
  
  local shopEngine = findShopEngine()
  if not shopEngine or not shopEngine.call then return false end
  
  local ok, hasCar = safeCall(function()
    return shopEngine.call("API_ownsHiTech", {color=color, kind="CAR"})
  end)
  
  return (ok and hasCar == true)
end

-- Pay entry AP if needed (CAR waives entry, per-turn tracking means free if already entered)
local function payEstateEntryAPIfNeeded(color)
  color = normalizeColor(color)
  if not color or color == "" then return false end
  
  -- CAR: If player owns a CAR, estate entry is free
  if hasCarEntryFree(color) then
    log("CAR: Estate entry free for "..tostring(color))
    S.enteredEstateThisTurn[color] = true  -- Mark as entered (free)
    return true
  end
  
  -- Per-turn entry tracking: If already entered this turn, entry is free
  if S.enteredEstateThisTurn[color] then
    return true
  end
  
  -- Charge 1 AP for entry
  local ok = apTrySpend1(color)
  if not ok then
    sayToColor(color, "⛔ Brak AP (Events) na wejście do agencji.", {1,0.6,0.2})
    return false
  end
  
  S.enteredEstateThisTurn[color] = true  -- Mark as entered
  return true
end

-- =========================
-- DECK UI
-- =========================
local function setDeckStage(deck, stage)
  if not isAlive(deck) then return end
  S.deckStage[deck.getGUID()] = stage
end

local function getDeckStage(deck)
  if not isAlive(deck) then return STAGE_PROMPT end
  return S.deckStage[deck.getGUID()] or STAGE_PROMPT
end

local function clearDeckButtons(deck)
  if isAlive(deck) and deck.clearButtons then safeCall(function() deck.clearButtons() end) end
end

local function promptSpec(clickFn)
  return {
    label = PROMPT_LABEL,
    click_function = clickFn,
    function_owner = self,
    position = {0, 0.33, 0},
    rotation = {0, UI_ROT_Y_DECK, 0},
    width = PROMPT_W,
    height = PROMPT_H,
    font_size = PROMPT_FS,
    color = PROMPT_BG,
    font_color = PROMPT_FC,
    tooltip = PROMPT_TIP,
  }
end

local function actionSpec(label, clickFn, z, tip, bg, fc)
  return {
    label = label,
    click_function = clickFn,
    function_owner = self,
    position = {0, 0.33, z},
    rotation = {0, UI_ROT_Y_DECK, 0},
    width = 1050,
    height = 360,
    font_size = 190,
    color = bg,
    font_color = fc,
    tooltip = tip or "",
  }
end

function ME_prompt_L1(_, pc) end
function ME_prompt_L2(_, pc) end
function ME_prompt_L3(_, pc) end
function ME_prompt_L4(_, pc) end
-- Note: ME_rent_L1/2/3/4 and ME_buy_L1/2/3/4 are defined later (see lines ~980)
function ME_nothing_L1(_, pc) end
function ME_nothing_L2(_, pc) end
function ME_nothing_L3(_, pc) end
function ME_nothing_L4(_, pc) end

local function rebuildDeckUI(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return end
  clearDeckButtons(deck)

  local stage = getDeckStage(deck)
  if stage == STAGE_PROMPT then
    safeCall(function() deck.createButton(promptSpec("ME_prompt_"..level)) end)
    return
  end

  local dz = ACTIONS_Z_SPREAD
  safeCall(function()
    deck.createButton(actionSpec("RENT", "ME_rent_"..level, dz, "Spend 1 AP (Events) and rent", COL_RENT_BG, COL_RENT_FC))
    deck.createButton(actionSpec("NOTHING", "ME_nothing_"..level, 0, "Close", COL_NOTHING_BG, COL_NOTHING_FC))
    deck.createButton(actionSpec("BUY", "ME_buy_"..level, -dz, "Spend 1 AP (Events) and buy", COL_BUY_BG, COL_BUY_FC))
  end)
end

local function rebuildAllDeckUI()
  rebuildDeckUI("L1")
  rebuildDeckUI("L2")
  rebuildDeckUI("L3")
  rebuildDeckUI("L4")
end

-- =========================
-- TAKE TOP REAL CARD (skip dummy)
-- =========================
local function takeTopRealCard(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return nil, "No deck" end

  if deck.tag == "Card" then
    if isDummyCard(deck) then return nil, "Only dummy card" end
    return deck, nil
  end

  if deck.tag ~= "Deck" then return nil, "Not a Deck" end

  local basePos = deck.getPosition()
  for _=1,30 do
    local taken = nil
    local ok = pcall(function()
      taken = deck.takeObject({ position = {basePos.x, basePos.y + 2.0, basePos.z}, smooth = false })
    end)
    if (not ok) or (not taken) then return nil, "takeObject failed" end

    if isDummyCard(taken) then
      safeCall(function() deck.putObject(taken) end)
    else
      return taken, nil
    end
  end

  return nil, "No real card found"
end

-- =========================
-- ACTIONS
-- =========================
local function doPrompt(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return end
  setDeckStage(deck, STAGE_ACTIONS)
  rebuildDeckUI(level)
end

local function doNothing(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return end
  setDeckStage(deck, STAGE_PROMPT)
  rebuildDeckUI(level)
end

local function blockAlreadyHasEstate(acting, desiredLevel)
  local msg = "⛔ Masz już apartament. Najpierw kliknij RETURN/SELL na poprzednim apartamencie."
  sayToColor(acting, msg, {1,0.55,0.25})
  broadcastToAll("⛔ "..tostring(acting)..": "..msg, {1,0.55,0.25})
  doNothing(desiredLevel)
end

local function doRent(level, clickedColor)
  local acting = getActingColor(clickedColor)
  if not acting then broadcastToAll("⛔ Brak aktywnego gracza.", {1,0.6,0.2}) return end

  local owned = findOwnedEstateOnBoard(acting)
  if owned then
    blockAlreadyHasEstate(acting, level)
    return
  end

  -- Pay entry AP if needed (CAR waives entry, per-turn tracking)
  if not payEstateEntryAPIfNeeded(acting) then
    return  -- Error message already shown
  end

  -- Remove tokens to safe park before placing estate card
  removeTokensToSafePark(acting)
  
  -- Small delay to let tokens move
  Wait.time(function()
    local card, err = takeTopRealCard(level)
    if not card then
      sayToColor(acting, "⛔ RENT: "..tostring(err), {1,0.6,0.2})
      -- Return tokens if card taking failed
      returnTokensFromSafePark(acting)
      return
    end

    local ok, why = placeCardOnBoard(card, acting)
    if not ok then
      sayToColor(acting, "⛔ "..tostring(why), {1,0.4,0.4})
      local deck = S.decks[level]
      if isAlive(deck) and deck.putObject then safeCall(function() deck.putObject(card) end) end
      -- Return tokens if placement failed
      returnTokensFromSafePark(acting)
      return
    end

    addTagSafe(card, TAG_ESTATE_MODE_RENT)
    removeTagSafe(card, TAG_ESTATE_MODE_BUY)
    attachReturnOrSellButton(card)

    -- Update rental cost in cost calculator (remove old level, add new level)
    -- Only adjust delta - TurnController handles base L0 costs per turn. Pass isRent=true for Social Worker 50% same-turn.
    local oldLevel = S.currentEstateLevel[acting] or "L0"  -- Default to L0 if not set
    S.currentEstateLevel[acting] = level
    S.currentEstateIsRented[acting] = true  -- Rented = pay rent
    updateRentalCostInCalculator(acting, oldLevel, level, true)

    -- Update TokenEngine housing level and reposition family tokens to the new apartment's slots (L1–L4)
    local tokenEngine = findTokenEngine()
    if tokenEngine and tokenEngine.call then
      safeCall(function()
        pcall(function()
          tokenEngine.call("TE_SetHousing_ARGS", { color = acting, level = level })
        end)
      end)
      log("Estate rental: Updated TokenEngine housing to "..level.." for "..acting)
    end

    -- Return tokens after card is placed (TE_SetHousing already repositions; this ensures any safe-park flow is consistent)
    Wait.time(function()
      returnTokensFromSafePark(acting)
    end, 0.5)

    doNothing(level)
  end, 0.3)
end

-- Inner buy: pay finalPrice, optionally remove voucherTokensToRemove (20% per token), take card, place
local function doBuyExecute(level, acting, finalPrice, voucherTokensToRemove)
  voucherTokensToRemove = math.max(0, math.floor(tonumber(voucherTokensToRemove) or 0))
  if finalPrice > 0 then
    if not moneyTrySpend(acting, finalPrice) then return end
    local msg = "💰 BUY: Paid "..tostring(finalPrice).." WIN for "..level.." estate."
    if voucherTokensToRemove > 0 then
      msg = msg .. " (used "..tostring(voucherTokensToRemove).." discount token(s))"
      pscRemoveStatusCount(acting, TAG_STATUS_VOUCH_P, voucherTokensToRemove)
    end
    sayToColor(acting, msg, {0.7,1,0.7})
  end

  removeTokensToSafePark(acting)
  
  -- Small delay to let tokens move
  Wait.time(function()
    local card, err = takeTopRealCard(level)
    if not card then
      sayToColor(acting, "⛔ BUY: "..tostring(err), {1,0.6,0.2})
      -- Return tokens if card taking failed
      returnTokensFromSafePark(acting)
      return
    end

    local ok, why = placeCardOnBoard(card, acting)
    if not ok then
      sayToColor(acting, "⛔ "..tostring(why), {1,0.4,0.4})
      local deck = S.decks[level]
      if isAlive(deck) and deck.putObject then safeCall(function() deck.putObject(card) end) end
      -- Return tokens if placement failed
      returnTokensFromSafePark(acting)
      return
    end

    addTagSafe(card, TAG_ESTATE_MODE_BUY)
    removeTagSafe(card, TAG_ESTATE_MODE_RENT)
    attachReturnOrSellButton(card)

    -- Update rental cost in cost calculator (remove old level, add new level)
    -- Note: Buying also requires rental cost payment per turn. Pass isRent=false (no Social Worker discount on buy).
    local oldLevel = S.currentEstateLevel[acting] or "L0"  -- Default to L0 if not set
    S.currentEstateLevel[acting] = level
    S.currentEstateIsRented[acting] = false  -- Bought = no rent
    updateRentalCostInCalculator(acting, oldLevel, level, false)

    -- Update TokenEngine housing level and reposition family tokens to the new apartment's slots (L1–L4)
    local tokenEngine = findTokenEngine()
    if tokenEngine and tokenEngine.call then
      safeCall(function()
        pcall(function()
          tokenEngine.call("TE_SetHousing_ARGS", { color = acting, level = level })
        end)
      end)
      log("Estate buy: Updated TokenEngine housing to "..level.." for "..acting)
    end

    -- Return tokens after card is placed (TE_SetHousing already repositions; this ensures any safe-park flow is consistent)
    Wait.time(function()
      returnTokensFromSafePark(acting)
    end, 0.5)

    doNothing(level)
  end, 0.3)
end

-- Called by EventsController when auction winner has already paid; assign L2 card to winner (no money taken here).
function Auction_AssignL2(params)
  params = params or {}
  local color = params.color and normalizeColor(params.color) or nil
  if not color or not isPlayableColor(color) then return end
  doBuyExecute("L2", color, 0, 0)
end

-- API: Get estate level and rent status for a player (single source of truth for TurnController rental costs).
-- Returns { level = "L0"|"L1"|"L2"|"L3"|"L4", isRented = boolean } or nil if invalid color.
-- L0 = grandma's house (pays rent). L1-L4: isRented=true means pay rent; isRented=false means owned (no rent).
function ME_GetEstateLevel(params)
  params = params or {}
  local color = params.color and normalizeColor(params.color) or nil
  if not color or not isPlayableColor(color) then return nil end
  local level = S.currentEstateLevel[color] or "L0"
  local isRented = (S.currentEstateIsRented[color] == true)
  return { level = level, isRented = isRented }
end

local function showVoucherChoiceOnDeck(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return end
  local p = S.pendingEstateVoucher
  if not p or p.level ~= level then return end
  setDeckStage(deck, STAGE_ACTIONS)
  deck.clearButtons()
  local price = ESTATE_PRICE[level] or 0
  deck.createButton({
    click_function = "ME_estateFullPrice",
    function_owner = self,
    label = "FULL PRICE\n("..tostring(price).." WIN)",
    position = {0, TILE_UIY, ACTIONS_Z_SPREAD},
    width = TILE_BTN_W, height = TILE_BTN_H, font_size = TILE_BTN_FS,
    color = COL_BUY_BG, font_color = COL_BUY_FC,
    tooltip = "Pay full price",
  })
  deck.createButton({
    click_function = "ME_estateUseDiscount",
    function_owner = self,
    label = "USE DISCOUNT ("..tostring(p.voucherCount)..")",
    position = {0, TILE_UIY, -ACTIONS_Z_SPREAD},
    width = TILE_BTN_W, height = TILE_BTN_H, font_size = TILE_BTN_FS,
    color = {0.3, 0.6, 0.9, 1}, font_color = {1,1,1,1},
    tooltip = "Use 1+ property discount tokens (20% each)",
  })
end

local function showVoucherCountOnDeck(level)
  local deck = S.decks[level]
  if not isAlive(deck) then return end
  local p = S.pendingEstateVoucher
  if not p or p.level ~= level then return end
  deck.clearButtons()
  local n = math.min(PROPERTY_VOUCHER_MAX, math.max(1, p.voucherCount or 1))
  deck.createButton({
    click_function = "ME_estateNoop",
    function_owner = self,
    label = "How many tokens? (1.."..tostring(n)..")",
    position = {0, TILE_UIY, ACTIONS_Z_SPREAD + 0.3},
    width = TILE_BTN_W * 1.2, height = 340, font_size = 140,
    color = PROMPT_BG, font_color = PROMPT_FC,
    tooltip = "",
  })
  for i = 1, n do
    local price = ESTATE_PRICE[level] or 0
    local finalP = math.max(0, math.floor(price * (1 - 0.20 * i)))
    deck.createButton({
      click_function = (i==1 and "ME_estateUse1") or (i==2 and "ME_estateUse2") or (i==3 and "ME_estateUse3") or "ME_estateUse4",
      function_owner = self,
      label = tostring(i).." token(s)\n("..tostring(finalP).." WIN)",
      position = {0, TILE_UIY, -ACTIONS_Z_SPREAD - (i-1)*0.5},
      width = TILE_BTN_W * 0.9, height = TILE_BTN_H, font_size = TILE_BTN_FS * 0.9,
      color = {0.25, 0.5, 0.85, 1}, font_color = {1,1,1,1},
      tooltip = "Use "..tostring(i).." token(s)",
    })
  end
end

function ME_estateNoop() end

function ME_estateFullPrice(deck, pc)
  local p = S.pendingEstateVoucher
  S.pendingEstateVoucher = nil
  if not p or not p.level or not p.acting then
    if p and p.level then rebuildDeckUI(p.level) end
    return
  end
  local price = ESTATE_PRICE[p.level] or 0
  doBuyExecute(p.level, p.acting, price, 0)
  rebuildDeckUI(p.level)
end

function ME_estateUseDiscount(deck, pc)
  local p = S.pendingEstateVoucher
  if not p or not p.level or not p.acting then
    S.pendingEstateVoucher = nil
    if p and p.level then rebuildDeckUI(p.level) end
    return
  end
  if p.voucherCount == 1 then
    S.pendingEstateVoucher = nil
    local price = ESTATE_PRICE[p.level] or 0
    local finalP = math.max(0, math.floor(price * 0.80))
    doBuyExecute(p.level, p.acting, finalP, 1)
    rebuildDeckUI(p.level)
    return
  end
  p.step = "ask_count"
  showVoucherCountOnDeck(p.level)
end

function ME_estateUseN(deck, pc, N)
  N = math.max(1, math.min(PROPERTY_VOUCHER_MAX, math.floor(tonumber(N) or 1)))
  local p = S.pendingEstateVoucher
  S.pendingEstateVoucher = nil
  if not p or not p.level or not p.acting then
    if p and p.level then rebuildDeckUI(p.level) end
    return
  end
  local price = ESTATE_PRICE[p.level] or 0
  local finalP = math.max(0, math.floor(price * (1 - 0.20 * N)))
  doBuyExecute(p.level, p.acting, finalP, N)
  rebuildDeckUI(p.level)
end
function ME_estateUse1(deck, pc) ME_estateUseN(deck, pc, 1) end
function ME_estateUse2(deck, pc) ME_estateUseN(deck, pc, 2) end
function ME_estateUse3(deck, pc) ME_estateUseN(deck, pc, 3) end
function ME_estateUse4(deck, pc) ME_estateUseN(deck, pc, 4) end

local function doBuy(level, clickedColor)
  local acting = getActingColor(clickedColor)
  if not acting then broadcastToAll("⛔ Brak aktywnego gracza.", {1,0.6,0.2}) return end

  local owned = findOwnedEstateOnBoard(acting)
  if owned then
    blockAlreadyHasEstate(acting, level)
    return
  end

  if not payEstateEntryAPIfNeeded(acting) then
    return
  end

  local price = ESTATE_PRICE[level] or 0
  local voucherCount = pscGetStatusCount(acting, TAG_STATUS_VOUCH_P)

  if voucherCount >= 1 then
    S.pendingEstateVoucher = { level = level, acting = acting, voucherCount = voucherCount, step = "ask_use" }
    showVoucherChoiceOnDeck(level)
    sayToColor(acting, "Use discount? You have "..tostring(voucherCount).." property voucher(s). Choose FULL PRICE or USE DISCOUNT.", {0.85,0.95,1})
    return
  end

  doBuyExecute(level, acting, price, 0)
end

function ME_prompt_L1(_, pc) doPrompt("L1") end
function ME_prompt_L2(_, pc) doPrompt("L2") end
function ME_prompt_L3(_, pc) doPrompt("L3") end
function ME_prompt_L4(_, pc) doPrompt("L4") end

function ME_nothing_L1(_, pc) doNothing("L1") end
function ME_nothing_L2(_, pc) doNothing("L2") end
function ME_nothing_L3(_, pc) doNothing("L3") end
function ME_nothing_L4(_, pc) doNothing("L4") end

function ME_rent_L1(_, pc) doRent("L1", pc) end
function ME_rent_L2(_, pc) doRent("L2", pc) end
function ME_rent_L3(_, pc) doRent("L3", pc) end
function ME_rent_L4(_, pc) doRent("L4", pc) end

function ME_buy_L1(_, pc) doBuy("L1", pc) end
function ME_buy_L2(_, pc) doBuy("L2", pc) end
function ME_buy_L3(_, pc) doBuy("L3", pc) end
function ME_buy_L4(_, pc) doBuy("L4", pc) end

-- =========================
-- RETURN/SELL HANDLER (button on card)
-- =========================
function ME_returnOrSellEstate(card, pc)
  local acting = getActingColor(pc)
  if not acting then return end
  if not isAlive(card) then return end

  -- owner safety
  if card.hasTag and (not card.hasTag(colorTag(acting))) then
    sayToColor(acting, "⛔ To nie jest Twoj apartament.", {1,0.5,0.5})
    return
  end

  -- RETURN/SELL doesn't charge entry AP - entry was already paid on rent/buy
  -- Only charge AP if NOT already entered this turn (but entry should have been paid)
  -- Since rent/buy already paid entry, return/sell in same turn should be free entry-wise
  -- But we still need to spend 1 AP for the return/sell action itself
  -- Actually, wait - the user said rent + return should cost only 1 AP total
  -- So if entry was already paid (S.enteredEstateThisTurn[acting] == true), then return/sell should be free AP-wise
  
  -- Per user request: If already entered this turn (paid entry AP), return/sell should cost 0 AP
  -- This means rent + return in same turn = 1 AP total (entry only)
  if S.enteredEstateThisTurn[acting] then
    -- Entry already paid, return/sell is free
    log("Estate return/sell: "..acting.." already entered this turn, return/sell is free (entry already paid)")
  else
    -- Edge case: returning without renting (shouldn't happen, but handle it)
    if not apTrySpend1(acting) then
      sayToColor(acting, "⛔ Brak AP (Events) na RETURN/SELL.", {1,0.6,0.2})
      return
    end
  end

  local lvl = getLevelFromCardName(card.getName())
  if not lvl then
    sayToColor(acting, "⛔ Nie rozpoznano poziomu apartamentu.", {1,0.5,0.5})
    return
  end

  local isBuy = (card.hasTag and card.hasTag(TAG_ESTATE_MODE_BUY)) or false
  if isBuy then
    local price = ESTATE_PRICE[lvl] or 0
    local refund = math.floor(price * SELL_REFUND_FACTOR + 0.0001)
    sayToColor(acting, "💰 SELL: refund "..tostring(refund).." VIN (placeholder).", {0.7,1,0.7})
  else
    sayToColor(acting, "🏠 RETURN: aktualizacja czynszu (placeholder).", {0.7,0.9,1})
  end

  clearCardButtons(card)

  -- Update rental cost in cost calculator (revert to L0 default)
  -- Only adjust delta - TurnController handles base L0 costs per turn
  local oldLevel = S.currentEstateLevel[acting] or "L0"  -- Default to L0 if somehow not set
  S.currentEstateLevel[acting] = "L0"  -- Revert to grandma's house
  S.currentEstateIsRented[acting] = false  -- L0 = no rented apartment
  updateRentalCostInCalculator(acting, oldLevel, "L0", false)

  -- Update TokenEngine housing level back to L0 and reposition family tokens to board (grandma's house)
  local tokenEngine = findTokenEngine()
  if tokenEngine and tokenEngine.call then
    safeCall(function()
      pcall(function()
        tokenEngine.call("TE_SetHousing_ARGS", { color = acting, level = "L0" })
      end)
    end)
    log("Estate return/sell: Updated TokenEngine housing back to L0 for "..acting)
  end

  local ok = returnEstateToDeckTop(card)
  if not ok then
    sayToColor(acting, "⛔ Nie udalo sie zwrocic karty do talii (brak deck ref).", {1,0.4,0.4})
  end
end

-- =========================
-- TILE UI
-- =========================
local function tileBtn(label, fn, x, z, w, h, fs, tip)
  self.createButton({
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x, TILE_UIY, z},
    width = w,
    height = h,
    font_size = fs,
    tooltip = tip or "",
    rotation = {0, 0, 0},
  })
end

local function buildTileUI()
  self.clearButtons()
  tileBtn("SCAN\nESTATES", "ME_scan",        -1.35,  0.90, TILE_BTN_W, TILE_BTN_H,     TILE_BTN_FS,     "Refresh decks + rebuild deck UI")
  tileBtn("RESET\nUI",     "ME_resetUI",     -1.35,  0.10, TILE_BTN_W, TILE_BTN_H,     TILE_BTN_FS,     "Force deck UI back to PROMPT stage")
  tileBtn("DEBUG",         "ME_debug",       -1.35, -0.70, TILE_BTN_W, 420,            TILE_BTN_FS,     "Print boards/shopboard/parking + loose real counts")
  tileBtn("PARK\nDEX",     "ME_park",         1.35,  0.10, TILE_BTN_W, TILE_BTN_H_BIG, TILE_BTN_FS_BIG, "Recollect loose REAL cards -> TOP of decks, then park decks")
  tileBtn("FORCE\nUNLOCK", "ME_forceUnlock",  1.35, -0.80, TILE_BTN_W, 420,            150,             "Emergency unlock if PARK got stuck")
end

-- =========================
-- SCAN / RESET / DEBUG
-- =========================
function ME_scan()
  ensureParkingWorld()
  refreshDeckRefs()
  for _,lvl in ipairs({"L1","L2","L3","L4"}) do
    local d = S.decks[lvl]
    if isAlive(d) then setDeckStage(d, STAGE_PROMPT) end
  end
  rebuildAllDeckUI()
  log("SCAN done")
end

function ME_resetUI()
  refreshDeckRefs()
  for _,lvl in ipairs({"L1","L2","L3","L4"}) do
    local d = S.decks[lvl]
    if isAlive(d) then
      setDeckStage(d, STAGE_PROMPT)
      rebuildDeckUI(lvl)
    end
  end
  log("RESET UI done")
end

local function collectLooseRealCardsList()
  local out = {L1={},L2={},L3={},L4={}}
  local seen = {}

  local function consider(o)
    if not isAlive(o) then return end
    if o.tag ~= "Card" then return end
    local g = o.getGUID()
    if seen[g] then return end
    seen[g] = true
    local lvl = classifyRealEstateCard(o)
    if lvl then table.insert(out[lvl], o) end
  end

  for _,o in ipairs(getAllObjects()) do consider(o) end
  for _,p in ipairs(Player.getPlayers()) do
    for _,o in ipairs(p.getHandObjects()) do consider(o) end
  end

  return out
end

function ME_debug()
  local tc = tostring(Turns and Turns.turn_color or "nil")
  broadcastToAll("🧩 MARKET DEBUG | Turns.turn_color="..tc, {0.8,0.9,1})

  for _,c in ipairs({"Yellow","Blue","Red","Green"}) do
    local b = findPlayerBoard(c)
    if b then
      broadcastToAll("✅ Board "..c.." = "..tostring(b.getName()).." ("..tostring(b.getGUID())..")", {0.7,1,0.7})
    else
      broadcastToAll("❌ Board "..c.." MISSING | need tags: "..TAG_PLAYERBOARD.." + "..colorTag(c), {1,0.4,0.4})
    end
  end

  ensureParkingWorld()
  ensureShopboard()
  if S.shopboard then
    broadcastToAll("✅ ShopBoard = "..tostring(S.shopboard.getName()).." ("..tostring(S.shopboard.getGUID())..")", {0.7,1,0.7})
  else
    broadcastToAll("❌ ShopBoard MISSING | GUID="..tostring(SHOPBOARD_GUID), {1,0.4,0.4})
  end

  refreshDeckRefs()
  local okAll = isAlive(S.decks.L1) and isAlive(S.decks.L2) and isAlive(S.decks.L3) and isAlive(S.decks.L4)
  broadcastToAll("🧩 Deck refs OK="..tostring(okAll), {0.9,0.9,0.6})

  local loose = collectLooseRealCardsList()
  broadcastToAll("🃏 Loose REAL: L1="..#loose.L1.." L2="..#loose.L2.." L3="..#loose.L3.." L4="..#loose.L4, {0.9,0.9,0.6})
end

function ME_forceUnlock()
  PARK_LOCK = false
  PARK_LOCK_TOKEN = PARK_LOCK_TOKEN + 1
  broadcastToAll("🟨 MARKET: FORCE UNLOCK executed.", {1,0.9,0.3})
end

-- =========================
-- PARK CORE (unchanged logic)
-- =========================
local function stackRealListOnTop(lvl, list, token, onDone)
  if PARK_LOCK_TOKEN ~= token then onDone(); return end
  refreshDeckRefs()
  local deck = S.decks[lvl]
  if not isAlive(deck) then
    broadcastToAll("⛔ PARK: missing deck "..lvl, {1,0.4,0.4})
    onDone()
    return
  end

  local dp = deck.getPosition()
  local dr = deck.getRotation()

  local i = 1
  local function step()
    if PARK_LOCK_TOKEN ~= token then onDone(); return end
    if i > #list then
      Wait.time(onDone, AFTER_STACK_DELAY)
      return
    end

    local card = list[i]
    i = i + 1

    if not isAlive(card) then
      Wait.time(step, 0.01)
      return
    end

    addTagSafe(card, TAG_ESTATE_CARD)

    local h = STACK_HEIGHT_BASE + (i-2) * STACK_HEIGHT_STEP
    moveToWorld({x=dp.x, y=dp.y + h, z=dp.z}, card, dr.y, false)

    Wait.time(step, STACK_STEP_DELAY)
  end

  step()
end

local function parkDecks(token)
  refreshDeckRefs()
  for _,lvl in ipairs({"L1","L2","L3","L4"}) do
    if PARK_LOCK_TOKEN ~= token then return end
    local d = S.decks[lvl]
    local p = S.parking[lvl]
    if isAlive(d) and p then
      moveToWorld(p, d, 180, true)
    end
  end
end

function ME_park()
  if PARK_LOCK then
    broadcastToAll("⛔ PARK: juz trwa (poczekaj).", {1,0.6,0.2})
    return
  end

  if not ensureParkingWorld() then
    broadcastToAll("⛔ PARK: brak ShopBoard/parkingow", {1,0.4,0.4})
    return
  end

  refreshDeckRefs()
  if (not isAlive(S.decks.L1)) or (not isAlive(S.decks.L2)) or (not isAlive(S.decks.L3)) or (not isAlive(S.decks.L4)) then
    broadcastToAll("⛔ PARK: Missing one or more estate decks. Fix deck tags first, then SCAN.", {1,0.4,0.4})
    return
  end

  PARK_LOCK = true
  PARK_LOCK_TOKEN = PARK_LOCK_TOKEN + 1
  local token = PARK_LOCK_TOKEN

  broadcastToAll("🟦 PARK: stacking REAL cards on TOP (dummy stays bottom)...", {0.6,0.85,1})

  Wait.time(function()
    if PARK_LOCK and PARK_LOCK_TOKEN == token then
      PARK_LOCK = false
      PARK_LOCK_TOKEN = PARK_LOCK_TOKEN + 1
      broadcastToAll("⛔ PARK TIMEOUT: aborted (use DEBUG, or FORCE UNLOCK).", {1,0.4,0.4})
    end
  end, PARK_TIMEOUT_S)

  local loose = collectLooseRealCardsList()

  stackRealListOnTop("L1", loose.L1, token, function()
    stackRealListOnTop("L2", loose.L2, token, function()
      stackRealListOnTop("L3", loose.L3, token, function()
        stackRealListOnTop("L4", loose.L4, token, function()
          if PARK_LOCK_TOKEN ~= token then return end
          parkDecks(token)
          Wait.time(function()
            if PARK_LOCK_TOKEN ~= token then return end
            ME_scan()
            PARK_LOCK = false
            broadcastToAll("🟩 PARK done. Loose REAL stacked on TOP.", {0.7,1,0.7})
            log("PARK finished")
          end, 0.35)
        end)
      end)
    end)
  end)
end

-- =========================
-- PUBLIC API for Turn Controller
-- =========================
function miRequestPark(params)
  params = params or {}
  local delay = tonumber(params.delay) or 0
  broadcastToAll("🟦 MARKET API: miRequestPark(delay="..tostring(delay)..")", {0.6,0.85,1})
  if delay > 0 then
    Wait.time(function() ME_park() end, delay)
  else
    ME_park()
  end
  return true
end

function miRequestParkAndScan(params)
  params = params or {}
  local delay = tonumber(params.delay) or 0
  broadcastToAll("🟦 MARKET API: miRequestParkAndScan(delay="..tostring(delay)..")", {0.6,0.85,1})
  local function go() ME_park() end
  if delay > 0 then Wait.time(go, delay) else go() end
  return true
end

-- =========================
-- LIFECYCLE
-- =========================
function onLoad(saved)
  addTagSafe(self, TAG_MARKET_CTRL)
  broadcastToAll("🟩 WLB MARKET ENGINE LOADED v1.8.1 ("..self.getGUID()..")", {0.7,1,0.7})
  buildTileUI()
  ensureParkingWorld()
  refreshDeckRefs()
  ME_scan()
  
  -- NOTE: Rental costs are now handled by TurnController.onTurnStart_AddRentalCosts()
  -- which adds rental costs automatically at the start of each turn.
  -- This initialization code has been removed to prevent duplicate costs.
end
