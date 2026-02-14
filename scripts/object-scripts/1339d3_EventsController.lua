-- =========================================================
-- WLB EVENTS CONTROLLER v3.6.0 (FULL REWRITE)
-- GOALS (vs 3.5.0):
--  ✅ FIX: NEWGAME must ALWAYS collect cards from slots 1-7 (even if track cleared)
--     - slot scan is done by WORLD POSITION (vectors), not by state.track.
--     - collection happens BEFORE clearTrack() to avoid losing references.
--  ✅ Keep 3.5.0 features:
--     - vectors instead of zones
--     - robust UI (idle vs modal), engine-modal protection
--     - obligatory lock logic + watchdog
--     - extra AP charged by controller after engine success
--     - robust AP_CTRL lookup by tags
--
-- Measured LOCAL positions @ EVENT_BOARD (GUID d031d9):
--   deck  = {x=-6.825, y=0.592, z=1.063}
--   slot7 = {x=-4.796, y=0.592, z=1.139}
--   slot6 = {x=-3.199, y=0.592, z=1.363}
--   slot5 = {x=-1.605, y=0.592, z=1.145}
--   slot4 = {x= 0.000, y=0.592, z=1.284}
--   slot3 = {x= 1.600, y=0.592, z=1.450}
--   slot2 = {x= 3.221, y=0.592, z=1.423}
--   slot1 = {x= 4.828, y=0.592, z=1.536}
--   used  = {x= 6.841, y=0.592, z=1.522}
-- =========================================================

local DEBUG = true

-- === SECTION 1: CONFIG =======================================================

local EVENT_BOARD_GUID  = "d031d9"
local EVENT_ENGINE_GUID = "7b92b3"
-- Optional: GUID of the object that runs the Global script (for auction UI panel). If empty, tag WLB_GLOBAL is used to find it; if neither, only card buttons are used.
local EVT_GLOBAL_GUID   = ""
local TAG_EVT_GLOBAL    = "WLB_GLOBAL"
local AUCTION_BIDDER_TIMER_SEC = 20

-- Deck/card tags
local TAG_EVT_CARD   = "WLB_EVT_CARD"

local TAG_YOUTH_CARD = "WLB_EVT_YOUTH_CARD"
local TAG_YOUTH_DECK = "WLB_DECK_YOUTH"

local TAG_ADULT_CARD = "WLB_EVT_ADULT_CARD"
local TAG_ADULT_DECK = "WLB_DECK_ADULT"

local YOUTH_DECK_NAME = "YDECK"
local ADULT_DECK_NAME = "ADECK"

-- OPTIONAL: heuristics by prefixes
local YOUTH_PREFIXES = {"YD_"}
local ADULT_PREFIXES = {"AD_", "ADECK_", "A_"}

-- PARKING positions (WORLD)
local PARK_YOUTH_POS = {x = 41, y = 5.7, z = -28}
local PARK_ADULT_POS = {x = 36, y = 5.7, z = -28}
local PARK_STACK_DY  = 0.18
local PARK_LOCK_TIME = 0.25

-- Geometry eps (distance checks)
local SLOT_DIST_EPS  = 1.25
local DECK_DIST_EPS  = 2.25
local USED_DIST_EPS  = 2.25
local PARK_MERGE_EPS = 3.5

-- World Y lift above track position
local DEAL_Y_OFFSET  = 0.35
local USED_Y_OFFSET  = 0.45
local LOCK_TIME      = 0.20

-- Rotation settle
local REHOME_SETTLE_SEC = 0.30

-- Timing
local PIPE_STEP_DELAY_SEC = 2.0
local PIPE_SHORT_SEC      = 0.25
local PIPE_SETTLE_SEC     = 0.85  -- Increased to allow cards to settle after merging/shuffling

-- Track card UI
local UI_TOOLTIP_TEXT = "Do you want to play this card?"
local UI_KARMA_QUESTION  = "Use Good Karma to avoid results of this card?"
local UI_LIFT_Y = 2.2
local UI_LOCK_WHEN_MODAL = true

local UI_BTN_W = 2300
local UI_BTN_H = 620
local UI_BTN_FONT = 260

local UI_POS_YES = {0, 0.85,  1.45}
local UI_POS_NO  = {0, 0.85, -1.45}

local CATCH_W = 1800
local CATCH_H = 2600

-- Delayed obligatory notice after NEXT
local POST_NEXT_OBLIGATORY_DELAY = 0.35

-- Watchdog for obligatory lock refresh (seconds)
local OBLIG_WATCHDOG_SEC = 0.45
-- Dev: set true to log karma modal decisions (obligatory? effectiveColor? hasKarma?)
local DEBUG_KARMA = false

-- === SECTION 1.0: TRACK LOCAL VECTORS =======================================

local TRACK_LOCAL = {
  deck = {x=-6.825, y=0.592, z=1.063},
  used = {x= 6.841, y=0.592, z=1.522},
  slots = {
    [1] = {x= 4.828, y=0.592, z=1.536},
    [2] = {x= 3.221, y=0.592, z=1.423},
    [3] = {x= 1.600, y=0.592, z=1.450},
    [4] = {x= 0.000, y=0.592, z=1.284},
    [5] = {x=-1.605, y=0.592, z=1.145},
    [6] = {x=-3.199, y=0.592, z=1.363},
    [7] = {x=-4.796, y=0.592, z=1.139},
  }
}

-- Extra AP by slot (1=front, 7=deep)
local EXTRA_BY_SLOT = { [1]=0, [2]=1, [3]=1, [4]=2, [5]=2, [6]=3, [7]=3 }

-- === SECTION 1.05: AP CTRL tags (for EXTRA AP charging) ======================
local TAG_AP_CTRL      = "WLB_AP_CTRL"
local TAG_SHOP_ENGINE  = "WLB_SHOP_ENGINE"
local COLOR_TAG_PREFIX = "WLB_COLOR_"
local TAG_MONEY        = "WLB_MONEY"
local TAG_BOARD        = "WLB_BOARD"

-- === SECTION 1.1: small helpers =============================================

local function log(msg)
  if DEBUG then print("[WLB EVT CTRL] " .. tostring(msg)) end
end

local function warn(msg)
  print("[WLB EVT CTRL][WARN] " .. tostring(msg))
end

local function clampPlayers(n)
  n = tonumber(n) or 4
  if n ~= 2 and n ~= 3 and n ~= 4 then n = 4 end
  return n
end

local function discardCount(players)
  players = clampPlayers(players)
  if players == 4 then return 1 end
  if players == 3 then return 2 end
  return 3
end

-- === SECTION 1.2: STATE ======================================================

local state = {
  setup = false,
  players = 4,
  mode = "AUTO",
  deckKind = "YOUTH",
  track = { slots = {} },
  resetInProgress = false,
  jobId = 0
}

local uiState = {
  modalOpen = {},   -- [cardGuid]=true
  homePos = {},     -- [cardGuid]={x,y,z}
  karmaChoice = {}, -- [cardGuid]=true when showing "Use Good Karma?" (obligatory + has karma)
  modalColor = {},  -- [cardGuid]=clickerColor (fallback when Turns.turn_color empty)
}

local nextBusy = false
local desiredDeckRot = nil
local obligatoryLock = false

-- === SECTION 1.3: AUCTION STATE (Call for Auction card AD_47) ===============
local AUCTION_JOIN_DEPOSIT = 500
local AUCTION_MIN_PRICE = 1500
local AUCTION_INCREMENT = 100

local auctionState = {
  active = false,
  state = nil,           -- "JOINING" | "BIDDING" | "RESOLVED"
  initiatorColor = nil,
  eventCardGuid = nil,
  propertyLevel = "L2",
  participants = {},     -- [color] = true
  deposits = {},         -- [color] = 500
  currentPrice = AUCTION_MIN_PRICE,
  increment = AUCTION_INCREMENT,
  currentBidderColor = nil,
  leaderColor = nil,
  activeBidders = {},    -- ordered list of colors still in bidding
  finalOrder = nil,      -- from TurnController for bidder order
  bidderTimerId = nil,   -- Wait.time id for 20s auto-pass
  bidderTickId = nil,    -- 1s repeat for UI countdown
  bidderTurnStartTime = nil,  -- os.clock() when current bidder's turn started
}

-- === SECTION 2: PERSISTENCE ==================================================

local function sanitizeValue(v, depth)
  depth = depth or 0
  if depth > 20 then return nil end

  local tv = type(v)
  if tv == "function" or tv == "userdata" or tv == "thread" then
    return nil
  end
  if tv ~= "table" then
    return v
  end

  local out = {}
  for k,val in pairs(v) do
    local tk = type(k)
    if tk ~= "function" and tk ~= "userdata" and tk ~= "thread" then
      local sv = sanitizeValue(val, depth+1)
      if sv ~= nil then out[k] = sv end
  end
  end
  return out
end

local function saveState()
  local clean = sanitizeValue(state) or {}
  self.script_state = JSON.encode(clean)
end

local function loadState()
  if self.script_state and self.script_state ~= "" then
    local ok, t = pcall(JSON.decode, self.script_state)
    if ok and type(t) == "table" then
      state = t
    end
  end

  state.track = state.track or { slots = {} }
  state.track.slots = state.track.slots or {}

  state.players = clampPlayers(state.players)
  state.mode = tostring(state.mode or "AUTO"):upper()
  if state.mode ~= "AUTO" and state.mode ~= "MANUAL" then state.mode = "AUTO" end

  state.deckKind = tostring(state.deckKind or "YOUTH"):upper()
  if state.deckKind ~= "YOUTH" and state.deckKind ~= "ADULT" then state.deckKind = "YOUTH" end

  state.resetInProgress = (state.resetInProgress == true)
  state.jobId = tonumber(state.jobId) or 0
  state.karmaDiagnostics = (state.karmaDiagnostics == true)
end

-- === SECTION 3: BOARD + WORLD POSITIONS ======================================

local function board()
  if not EVENT_BOARD_GUID or EVENT_BOARD_GUID=="" then return nil end
  return getObjectFromGUID(EVENT_BOARD_GUID)
end

local function hasBoard()
  local b = board()
  return (b ~= nil and b.positionToWorld ~= nil and b.positionToLocal ~= nil) and true or false
end

local function toWorld(localPos)
  local b = board()
  if not b or not localPos then return nil end
  local wp = b.positionToWorld({localPos.x, localPos.y, localPos.z})
  return {x=wp.x, y=wp.y, z=wp.z}
end

local function deckWorldPos() return toWorld(TRACK_LOCAL.deck) end
local function usedWorldPos() return toWorld(TRACK_LOCAL.used) end
local function slotWorldPos(i) return toWorld(TRACK_LOCAL.slots[i]) end

-- Auction card (Call for Auction): fixed local position on the board, x=10 for hovering spot
local AUCTION_CARD_LOCAL = { x = 10, y = 0.592, z = 1.522 }
local function auctionCardWorldPos()
  return toWorld(AUCTION_CARD_LOCAL)
end

-- === SECTION 3.1: generic helpers ============================================

local function objByGUID(g)
  if not g or g == "" then return nil end
  return getObjectFromGUID(g)
end

-- Auction: find money controller for a color (board with getMoney or WLB_MONEY tile)
local function auctionFindMoney(color)
  if not color or color == "" then return nil end
  local ct = COLOR_TAG_PREFIX .. (color:sub(1,1):upper() .. color:sub(2):lower())
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(ct) then
      if o.hasTag(TAG_BOARD) and o.call then
        local ok = pcall(function() return o.call("getMoney") end)
        if ok then return o end
      end
      if o.hasTag(TAG_MONEY) then return o end
    end
  end
  return nil
end

local function auctionGetMoney(color)
  local m = auctionFindMoney(color)
  if not m or not m.call then return 0 end
  local ok, v = pcall(function() return m.call("getMoney") end)
  if ok and type(v) == "number" then return v end
  ok, v = pcall(function() return m.call("getValue") end)
  if ok and type(v) == "number" then return v end
  return 0
end

local function auctionCanSpend(color, amount)
  return (auctionGetMoney(color) or 0) >= (tonumber(amount) or 0)
end

local function auctionSpend(color, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  local m = auctionFindMoney(color)
  if not m or not m.call then return false end
  local ok = pcall(function() m.call("addMoney", { amount = -amount }) end)
  if ok then return true end
  ok = pcall(function() m.call("API_spend", { amount = amount }) end)
  return ok
end

local function auctionAdd(color, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return true end
  local m = auctionFindMoney(color)
  if not m or not m.call then return false end
  local ok = pcall(function() m.call("addMoney", { amount = amount }) end)
  if ok then return true end
  ok = pcall(function() m.call("addMoney", { delta = amount }) end)
  return ok
end

local function isCardOrDeck(o)
  if not o then return false end
  local tag = nil
  pcall(function() tag = o.tag end)
  return (tag == "Card" or tag == "Deck")
end
local function isCard(o)
  if not o then return false end
  local tag = nil
  pcall(function() tag = o.tag end)
  return (tag == "Card")
end

local function safeQty(obj)
  if not obj then return 0 end
  local objTag = nil
  pcall(function() objTag = obj.tag end)
  if objTag == "Deck" then
    local q = 0
    pcall(function() q = obj.getQuantity() end)
    return tonumber(q) or 0
  end
  if objTag == "Card" then return 1 end
  return 0
end

local function ensureTag(obj, tag)
  if not obj or not obj.addTag or not obj.hasTag then return end
  if not obj.hasTag(tag) then pcall(function() obj.addTag(tag) end) end
end

local function forceFaceUp(card)
  if not card then return end
  local isCard = false
  local isFaceDown = false
  pcall(function() isCard = (card.tag == "Card") end)
  if not isCard then return end
  pcall(function() isFaceDown = card.is_face_down end)
  if isFaceDown then pcall(function() card.flip() end) end
  Wait.time(function()
    if card then
      local stillCard, stillFaceDown = false, false
      pcall(function() stillCard = (card.tag == "Card") end)
      pcall(function() stillFaceDown = card.is_face_down end)
      if stillCard and stillFaceDown then pcall(function() card.flip() end) end
    end
  end, 0.25)
end

local function forceFaceDown(obj)
  if not obj then return end
  local objTag = nil
  local isFaceUp = false
  pcall(function() objTag = obj.tag end)
  if objTag ~= "Deck" and objTag ~= "Card" then return end
  pcall(function() isFaceUp = (obj.is_face_down == false) end)
  if isFaceUp then pcall(function() obj.flip() end) end
  Wait.time(function()
    if obj then
      local stillTag = nil
      local stillFaceUp = false
      pcall(function() stillTag = obj.tag end)
      pcall(function() stillFaceUp = (obj.is_face_down == false) end)
      if (stillTag == "Deck" or stillTag == "Card") and stillFaceUp then
        pcall(function() obj.flip() end)
      end
    end
  end, 0.35)
end

local function applyDesiredRotation(obj)
  if not obj or not desiredDeckRot then return end
  if obj.setRotation then
    pcall(function() obj.setRotation({desiredDeckRot.x, desiredDeckRot.y, desiredDeckRot.z}) end)
  end
end

local function dist2(a, b)
  local dx = a.x - b.x
  local dz = a.z - b.z
  return dx*dx + dz*dz
end

local function isNearPos(obj, p, eps)
  if not obj or not p or not obj.getPosition then return false end
  local op = obj.getPosition()
  if not op then return false end
  return dist2({x=op.x, z=op.z}, {x=p.x, z=p.z}) <= (eps*eps)
end

local function isObjNearSlot(obj, slotIdx)
  local sp = slotWorldPos(slotIdx)
  if not sp then return false end
  return isNearPos(obj, sp, SLOT_DIST_EPS)
end

local function isObjNearAnySlot(obj)
  if not obj then return false end
  for i=1,7 do
    if isObjNearSlot(obj, i) then return true end
  end
  return false
end

local function collectNearWorldPos(p, eps)
  local out = {}
  if not p then return out end
  for _, o in ipairs(getAllObjects()) do
    if isCardOrDeck(o) and isNearPos(o, p, eps) then
      table.insert(out, o)
    end
  end
  return out
end

-- === SECTION 4: KIND / TAG HELPERS ===========================================

local function parkPosForKind(kind)
  kind = tostring(kind or "YOUTH"):upper()
  if kind == "ADULT" then return PARK_ADULT_POS end
  return PARK_YOUTH_POS
end

local function kindTags(kind)
  kind = tostring(kind or "YOUTH"):upper()
  if kind == "ADULT" then
    return TAG_ADULT_DECK, TAG_ADULT_CARD, ADULT_DECK_NAME
  end
  return TAG_YOUTH_DECK, TAG_YOUTH_CARD, YOUTH_DECK_NAME
end

local function ensureEventCardTagsForKind(obj, kind)
  if not obj then return end
  ensureTag(obj, TAG_EVT_CARD)
  local deckTag, cardTag = kindTags(kind)
  ensureTag(obj, cardTag)
  local objTag = nil
  pcall(function() objTag = obj.tag end)
  if objTag == "Deck" then ensureTag(obj, deckTag) end
end

local function startsWithAnyPrefix(text, prefixes)
  text = tostring(text or "")
  for _,p in ipairs(prefixes or {}) do
    p = tostring(p or "")
    if p ~= "" and string.sub(text, 1, #p) == p then
      return true
    end
  end
  return false
end

local function classifyKindByHeuristics(o)
  if not o then return nil end
  local objTag = nil
  pcall(function() objTag = o.tag end)
  if objTag ~= "Card" and objTag ~= "Deck" then return nil end

  if o.hasTag then
    if o.hasTag(TAG_YOUTH_CARD) or o.hasTag(TAG_YOUTH_DECK) then return "YOUTH" end
    if o.hasTag(TAG_ADULT_CARD) or o.hasTag(TAG_ADULT_DECK) then return "ADULT" end
  end

  local name = (o.getName and o.getName()) or ""
  local desc = (o.getDescription and o.getDescription()) or ""
  if startsWithAnyPrefix(name, YOUTH_PREFIXES) or startsWithAnyPrefix(desc, YOUTH_PREFIXES) then return "YOUTH" end
  if startsWithAnyPrefix(name, ADULT_PREFIXES) or startsWithAnyPrefix(desc, ADULT_PREFIXES) then return "ADULT" end

  if objTag == "Deck" and o.getName then
    local n = o.getName()
    if n == YOUTH_DECK_NAME or n == "Y-Deck" then return "YOUTH" end
    if n == ADULT_DECK_NAME or n == "A-Deck" then return "ADULT" end
  end

  return nil
end

-- === SECTION 5: PARKING / ANTI-MERGE =========================================

local function moveObjectToPark(obj, kind, stackIndex, reason)
  if not obj or not isCardOrDeck(obj) then return false end
  local p = parkPosForKind(kind)
  if not p then return false end

  pcall(function() obj.setLock(true) end)
  forceFaceDown(obj)
  applyDesiredRotation(obj)

  local dy = PARK_STACK_DY * (stackIndex or 0)
  pcall(function() obj.setPosition({p.x, p.y + dy, p.z}) end)

  Wait.time(function()
    if obj then pcall(function() obj.setLock(false) end) end
  end, PARK_LOCK_TIME)

  local objTag = ""
  local objGuid = ""
  pcall(function() objTag = tostring(obj.tag or "") end)
  pcall(function() objGuid = tostring(obj.getGUID and obj.getGUID() or "") end)
  log("PARK "..tostring(kind).." : "..objTag.." guid="..objGuid.." ("..tostring(reason or "?")..")")
  return true
end

local function evacuateDeckAreaToPark(kind, reason)
  if not state.setup then return false end
  local dp = deckWorldPos()
  if not dp then return false end

  local near = collectNearWorldPos(dp, DECK_DIST_EPS)
  local moved, stack = 0, 0

  for _, o in ipairs(near) do
    if isCardOrDeck(o) then
      if not isObjNearAnySlot(o) then
        moveObjectToPark(o, kind, stack, "evacuate:"..tostring(reason or ""))
        stack = stack + 1
        moved = moved + 1
      end
    end
  end

  if moved > 0 then log("evacuateDeckAreaToPark moved="..tostring(moved).." -> "..tostring(kind)) end
  return true
end

local function rehomeDeckToDeckPos(deckObj, kind, reason)
  if not deckObj or deckObj.tag ~= "Deck" then return false end
  if not state.setup then return false end

  local dp = deckWorldPos()
  if not dp then return false end

  evacuateDeckAreaToPark(kind, "rehome:"..tostring(reason or ""))

  local deckTag, cardTag, expectedName = kindTags(kind)

  Wait.time(function()
    if not deckObj then return end

    ensureTag(deckObj, deckTag)
    ensureTag(deckObj, TAG_EVT_CARD)
    ensureTag(deckObj, cardTag)

    pcall(function() deckObj.setLock(true) end)
    pcall(function() deckObj.setPosition({dp.x, dp.y + 0.35, dp.z}) end)
    applyDesiredRotation(deckObj)

    Wait.time(function()
      if not deckObj then return end
      pcall(function() deckObj.setName(expectedName) end)
      forceFaceDown(deckObj)

      Wait.time(function()
        if deckObj then pcall(function() deckObj.setLock(false) end) end
      end, 0.20)

      log("Rehome OK kind="..tostring(kind).." name="..tostring(expectedName).." guid="..tostring(deckObj.getGUID()).." qty="..tostring(safeQty(deckObj)))
    end, REHOME_SETTLE_SEC)

  end, PIPE_SHORT_SEC)

  return true
end

-- === SECTION 6: TRACK CARD UI (IDLE + MODAL) =================================

function ui_noop() end

local function uiClearButtons(card)
  if not isCard(card) then return end
  pcall(function() card.clearButtons() end)
end

local function uiRememberHome(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  if not uiState.homePos[g] then
    local p = card.getPosition()
    uiState.homePos[g] = {x=p.x, y=p.y, z=p.z}
  end
end

local function uiSetTrackDescription(card)
  if not isCard(card) then return end
  pcall(function() card.setDescription(UI_TOOLTIP_TEXT) end)
end

local function uiClearTrackDescription(card)
  if not isCard(card) then return end
  pcall(function() card.setDescription("") end)
end

local function uiReturnHome(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  local p = uiState.homePos[g]
  if p then
    pcall(function() card.setPositionSmooth({p.x,p.y,p.z}, false, true) end)
  end
  if UI_LOCK_WHEN_MODAL then pcall(function() card.setLock(false) end) end
end

local function uiLift(card)
  if not isCard(card) then return end
  uiRememberHome(card)
  local g = card.getGUID()
  local p = uiState.homePos[g]
  if p then
    pcall(function() card.setPositionSmooth({p.x, p.y + UI_LIFT_Y, p.z}, false, true) end)
  end
  if UI_LOCK_WHEN_MODAL then pcall(function() card.setLock(true) end) end
end

local function uiAttachClickCatcher_IDLE(card)
  if not isCard(card) then return end
  card.createButton({
    click_function = "evt_onCardClicked",
    function_owner = self,
    label          = "",
    position       = {0, 0.35, 0},
    rotation       = {0, 0, 0},
    width          = CATCH_W,
    height         = CATCH_H,
    font_size      = 1,
    color          = {0, 0, 0, 0},
    font_color     = {0, 0, 0, 0},
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
    width          = 3800,
    height         = 360,
    font_size      = 170,
    color          = {0, 0, 0, 0.70},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
end

-- Good Karma choice: "Use Good Karma to avoid results?" YES (use karma) / NO (resolve as usual). Used when card is obligatory AND player has Good Karma.
local function uiAttachKarmaChoice_MODAL(card)
  if not isCard(card) then return end
  card.createButton({
    click_function = "ui_noop",
    function_owner = self,
    label          = UI_KARMA_QUESTION,
    position       = {0, 0.95, 0},
    rotation       = {0, 0, 0},
    width          = 3800,
    height         = 360,
    font_size      = 150,
    color          = {0, 0, 0, 0.70},
    font_color     = {1, 1, 1, 1},
    tooltip        = "",
  })
  card.createButton({
    click_function = "evt_onYes",
    function_owner = self,
    label          = "YES",
    position       = UI_POS_YES,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {1.0, 0.84, 0.0, 0.95},
    font_color     = {0, 0, 0, 1},
    tooltip        = "Use Good Karma: skip this card without consequences (token consumed)",
  })
  card.createButton({
    click_function = "evt_onNo",
    function_owner = self,
    label          = "NO",
    position       = UI_POS_NO,
    rotation       = {0, 0, 0},
    width          = UI_BTN_W,
    height         = UI_BTN_H,
    font_size      = UI_BTN_FONT,
    color          = {0.2, 0.7, 0.2, 0.95},
    font_color     = {1, 1, 1, 1},
    tooltip        = "No, resolve this card as usual",
  })
end

local function uiAttachYesNo_MODAL(card)
  if not isCard(card) then return end
  uiAttachQuestionLabel_MODAL(card)

  card.createButton({
    click_function = "evt_onYes",
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
    click_function = "evt_onNo",
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
  -- Obligatory + Good Karma: karma-choice modal is shown instead (in uiOpenModal)
end

-- Engine-side modal buttons we must NOT overwrite
local ENGINE_MODAL_FNS = {
  evt_roll = true,
  evt_cancelPending = true,
  evt_choiceA = true,
  evt_choiceB = true,
  evt_choicePay = true,
  evt_choiceSat = true,
  evt_onUseKarma = true,  -- Add our new handler
  -- Vocation Event card buttons
  evt_veCrime = true,
  evt_veChoiceA = true,
  evt_veChoiceB = true,
  evt_veTargetYellow = true,
  evt_veTargetBlue = true,
  evt_veTargetRed = true,
  evt_veTargetGreen = true,
  evt_veCrimeRoll = true,
}

local function cardHasEngineModalUI(card)
  if not isCard(card) or not card.getButtons then return false end
  local btns = nil
  local ok, v = pcall(function() return card.getButtons() end)
  if ok then btns = v end
  if type(btns) ~= "table" then return false end

  for _,b in ipairs(btns) do
    local fn = b and b.click_function
    if fn and ENGINE_MODAL_FNS[fn] then
      return true
    end
  end
  return false
end

-- Karma/obligatory helpers MUST be defined in same scope as uiOpenModal (TTS may chunk script; later locals can be nil here)
local function getEngine()
  return objByGUID(EVENT_ENGINE_GUID)
end
local function getPSC()
  if type(getObjectsWithTag) == "function" then
    local list = getObjectsWithTag("WLB_PLAYER_STATUS_CTRL") or {}
    if #list > 0 then return list[1] end
  end
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag("WLB_PLAYER_STATUS_CTRL") then return o end
  end
  return nil
end
local getPlayerStatusController = getPSC
local function hasGoodKarma(color)
  if not color or color == "" then return false end
  local c = tostring(color)
  c = c:sub(1,1):upper() .. c:sub(2):lower()
  local psc = getPSC()
  if not psc or not psc.call then return false end
  local ok, res = pcall(function()
    return psc.call("PS_Event", {
      color = c,
      op = "HAS_STATUS",
      statusTag = "WLB_STATUS_GOOD_KARMA"
    })
  end)
  return (ok and res == true) and true or false
end
local function consumeGoodKarma(color)
  if not color or color == "" then return false end
  local c = tostring(color)
  c = c:sub(1,1):upper() .. c:sub(2):lower()
  local psc = getPSC()
  if not psc or not psc.call then return false end
  local ok, _ = pcall(function()
    psc.call("PS_Event", {
      color = c,
      op = "REMOVE_STATUS",
      statusTag = "WLB_STATUS_GOOD_KARMA"
    })
  end)
  return ok
end
local function isCardObligatory(card)
  if not card then return false end
  local engine = getEngine()
  if not engine or not engine.call then return false end
  local cardGuid = card.getGUID()
  if not cardGuid or cardGuid == "" then return false end
  local ok, result = pcall(function()
    return engine.call("isObligatoryCard", { card_guid = cardGuid })
  end)
  return (ok and result == true)
end

function uiEnsureIdle(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  if uiState.modalOpen[g] then return end
  if cardHasEngineModalUI(card) then return end

  uiClearButtons(card)
  uiSetTrackDescription(card)
  uiAttachClickCatcher_IDLE(card)
end

function uiOpenModal(card, clickerColor)
  if not isCard(card) then return end
  local g = card.getGUID()
  if uiState.modalOpen[g] then return end
  uiState.modalOpen[g] = true
  if clickerColor then uiState.modalColor[g] = clickerColor end

  -- Obligatory + Good Karma check MUST run before uiSetTrackDescription(card), so EventEngine
  -- can read card ID from name/description (isObligatoryCard uses card_guid → extractCardId).
  local effectiveColor = (Turns and Turns.turn_color and Turns.turn_color ~= "") and Turns.turn_color or (uiState.modalColor and uiState.modalColor[g]) or clickerColor or nil
  local showKarmaChoice = false
  local ok1, ok2, obligatory, hasKarma = nil, nil, nil, nil
  if effectiveColor and effectiveColor ~= "" and type(isCardObligatory) == "function" and type(hasGoodKarma) == "function" then
    ok1, obligatory = pcall(function() return isCardObligatory(card) end)
    ok2, hasKarma = pcall(function() return hasGoodKarma(effectiveColor) end)
    if DEBUG_KARMA and type(print) == "function" then
      print("[WLB EVT CTRL] karma check: obligatory="..tostring(ok1 and obligatory).." effectiveColor="..tostring(effectiveColor).." hasKarma="..tostring(ok2 and hasKarma))
    end
    if ok1 and obligatory == true and ok2 and hasKarma == true then
      showKarmaChoice = true
    end
  end

  -- Karma diagnostics: broadcast to chat when card is clicked so you can see why karma modal did/didn't show
  if state.karmaDiagnostics then
    local reason
    if not effectiveColor or effectiveColor == "" then
      reason = "normal (no effectiveColor)"
    elseif type(isCardObligatory) ~= "function" or type(hasGoodKarma) ~= "function" then
      reason = "normal (isCardObligatory or hasGoodKarma is nil)"
    elseif not ok1 then
      reason = "normal (isCardObligatory call failed)"
    elseif obligatory ~= true then
      reason = "normal (obligatory=false; card ID may be missing from name/description)"
    elseif not ok2 then
      reason = "normal (hasGoodKarma call failed)"
    elseif hasKarma ~= true then
      reason = "normal (hasKarma=false; no token in TokenEngine for this color)"
    else
      reason = "KARMA MODAL"
    end
    broadcastToAll(
      "[Karma diag] color=" .. tostring(effectiveColor or "") ..
      " obligatory=" .. tostring(obligatory) ..
      " hasKarma=" .. tostring(hasKarma) ..
      " → " .. reason,
      {0.9, 0.85, 0.6}
    )
  end

  uiSetTrackDescription(card)
  uiLift(card)
  uiClearButtons(card)

  if showKarmaChoice then
    uiState.karmaChoice[g] = true
    uiAttachKarmaChoice_MODAL(card)
  else
    uiAttachYesNo_MODAL(card)
  end
end

function uiCloseModal(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  uiState.modalOpen[g] = nil
  if uiState.karmaChoice then uiState.karmaChoice[g] = nil end
  if uiState.modalColor then uiState.modalColor[g] = nil end
  uiReturnHome(card)
  uiEnsureIdle(card)
end

function uiCloseModalSoft(card)
  if not isCard(card) then return end
  local g = card.getGUID()
  uiState.modalOpen[g] = nil
  if uiState.karmaChoice then uiState.karmaChoice[g] = nil end
  if uiState.modalColor then uiState.modalColor[g] = nil end
  uiReturnHome(card)
end

function refreshEventSlotUI()
  if not state.setup then return end
  for i=1,7 do
    local g = state.track.slots[i]
    if g and g ~= "" then
      local o = objByGUID(g)
      if isCard(o) and isObjNearSlot(o, i) then
        uiEnsureIdle(o)
      end
    end
  end
end

function refreshEventSlotUI_later(delaySec)
  Wait.time(function() refreshEventSlotUI() end, delaySec or 0.25)
end

-- Called by Event Engine when player cancels a card choice (e.g. VE Cancel). Closes modal and re-adds YES/click catcher so the card is interactable again.
function onCardCancelled(params)
  if type(params) ~= "table" then return end
  local g = params.card_guid or params.cardGuid or params.guid
  if not g or g == "" then return end
  local card = getObjectFromGUID(g)
  if card and isCard(card) then
    -- Ensure buttons are cleared (engine clears them, but ensure it's done before refresh)
    if uiClearButtons then uiClearButtons(card) end
    if uiCloseModal then uiCloseModal(card) end
  end
  -- Use a slightly longer delay to ensure all state is cleared before refresh
  refreshEventSlotUI_later(0.4)
end

-- === SECTION 7: TRACK + MOVE =================================================

local function refreshTrackedSlots()
  for i=1,7 do
    local g = state.track.slots[i]
    if g and g ~= "" then
      local obj = objByGUID(g)
      if (not obj) or (not isObjNearSlot(obj, i)) then
        state.track.slots[i] = nil
      end
    end
  end
end

local function teleportToSlot(obj, slotIdx)
  local p = slotWorldPos(slotIdx)
  if not obj or not p then return end

  if isCard(obj) then
    ensureTag(obj, TAG_EVT_CARD)
    uiState.modalOpen[obj.getGUID()] = nil
    uiState.homePos[obj.getGUID()] = nil
    uiClearButtons(obj)
    uiSetTrackDescription(obj)
  end

  pcall(function() obj.setPosition({p.x, p.y + DEAL_Y_OFFSET, p.z}) end)
end

local function teleportToUsed(obj, stackIndex)
  local p = usedWorldPos()
  if not obj or not p then return end

  if isCard(obj) then
    ensureTag(obj, TAG_EVT_CARD)
    uiState.modalOpen[obj.getGUID()] = nil
    uiState.homePos[obj.getGUID()] = nil
    uiClearButtons(obj)
    uiClearTrackDescription(obj)
  end

  pcall(function()
    obj.setPosition({p.x, p.y + USED_Y_OFFSET + (stackIndex or 0)*0.15, p.z})
  end)
end

-- === SECTION 8: REFILL + NEXT =================================================

local function findDeckAnywhereByTag(deckTag)
  local best, bestQty = nil, -1
  for _, o in ipairs(getAllObjects()) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Deck" and o.hasTag and o.hasTag(deckTag) then
        local q = safeQty(o)
        if q > bestQty then bestQty=q; best=o end
      end
    end
  end
  return best
end

local function firstCardOrDeckAtDeckPos()
  local dp = deckWorldPos()
  if not dp then return nil end
  local near = collectNearWorldPos(dp, DECK_DIST_EPS)
  for _,o in ipairs(near) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Deck" then return o end
    end
  end
  for _,o in ipairs(near) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Card" then return o end
    end
  end
  return nil
end

local function ensureDeckReadyForKind(kind)
  if not state.setup then return nil end
  local deckTag, cardTag, expectedName = kindTags(kind)

  local src = firstCardOrDeckAtDeckPos()
  if src then
    local srcTag = nil
    pcall(function() srcTag = src.tag end)
    if srcTag == "Deck" then
      if src.hasTag and src.hasTag(deckTag) then
        ensureTag(src, TAG_EVT_CARD)
        ensureTag(src, cardTag)
        pcall(function() src.setName(expectedName) end)
        forceFaceDown(src)
        return src
      end
    end
  end

  local d = findDeckAnywhereByTag(deckTag)
  if d then return d end

  for _,o in ipairs(getAllObjects()) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Deck" and o.getName and o.getName()==expectedName then
        ensureTag(o, deckTag)
        ensureTag(o, TAG_EVT_CARD)
        ensureTag(o, cardTag)
        return o
      end
    end
  end

  return nil
end

local function getDeckSource()
  return ensureDeckReadyForKind(state.deckKind)
end

local function refillEmptySlots()
  if not state.setup then warn("REFILL: setup=false"); return false end
  if state.resetInProgress then warn("REFILL blocked: resetInProgress"); return false end

  refreshTrackedSlots()

  local source = getDeckSource()
  if not source then
    warn("REFILL: no source deck for kind="..tostring(state.deckKind))
    return false
  end

  local sourceFaceDown = (source.is_face_down == true)
  local flipOnTake = sourceFaceDown

  local deckTag, cardTag, expectedName = kindTags(state.deckKind)
  local filled = 0

  for i=7,1,-1 do
    if not state.track.slots[i] then
      local slotIdx = i
      local p = slotWorldPos(slotIdx)
      if not p then break end

      local sourceTag = nil
      pcall(function() sourceTag = source.tag end)

      if sourceTag == "Deck" then
        ensureTag(source, deckTag)
        ensureTag(source, TAG_EVT_CARD)
        ensureTag(source, cardTag)
        pcall(function() source.setName(expectedName) end)

        source.takeObject({
          position = {p.x, p.y + DEAL_Y_OFFSET, p.z},
          smooth = false,
          flip = flipOnTake,
          callback_function = function(card)
            if not card or not isCard(card) then return end
            ensureEventCardTagsForKind(card, state.deckKind)

            pcall(function() card.setLock(true) end)
            forceFaceUp(card)
            uiSetTrackDescription(card)

            state.track.slots[slotIdx] = card.getGUID()
            saveState()

            refreshEventSlotUI_later(0.15)

            Wait.time(function()
              if card then pcall(function() card.setLock(false) end) end
            end, LOCK_TIME)
          end
        })
        filled = filled + 1

      elseif sourceTag == "Card" then
        ensureEventCardTagsForKind(source, state.deckKind)
        pcall(function() source.setPosition({p.x, p.y + DEAL_Y_OFFSET, p.z}) end)
        pcall(function() source.setLock(true) end)
        forceFaceUp(source)
        uiSetTrackDescription(source)

        state.track.slots[slotIdx] = source.getGUID()
        saveState()

        refreshEventSlotUI_later(0.15)

        Wait.time(function()
          if source then pcall(function() source.setLock(false) end) end
        end, LOCK_TIME)

        filled = filled + 1
        break
      end
    end
  end

  Wait.time(function()
    if state.resetInProgress then return end
    local src = getDeckSource()
    if src then
      local srcTag = nil
      pcall(function() srcTag = src.tag end)
      if srcTag == "Deck" then
        local dTag, cTag, eName = kindTags(state.deckKind)
        ensureTag(src, dTag)
        ensureTag(src, TAG_EVT_CARD)
        ensureTag(src, cTag)
        pcall(function() src.setName(eName) end)
        forceFaceDown(src)
      end
    end
  end, 0.35)

  log("REFILL done: filled="..tostring(filled).." kind="..tostring(state.deckKind))
  refreshEventSlotUI_later(0.35)
  return true
end

local function nextTurn()
  if not state.setup then warn("NEXT: setup=false"); return end
  if state.resetInProgress then warn("NEXT blocked: resetInProgress"); return end
  if nextBusy then warn("NEXT debounce"); return end
  nextBusy = true

  refreshTrackedSlots()
  local n = discardCount(state.players)

  local discarded = 0
  for i=1,n do
    local g = state.track.slots[i]
    if g then
      local obj = objByGUID(g)
      if obj then
        teleportToUsed(obj, discarded)
        -- Defer tag access and forceFaceUp after object has time to settle
        Wait.time(function()
          if obj then
            local objTag = nil
            pcall(function() objTag = obj.tag end)
            if objTag == "Card" then forceFaceUp(obj) end
          end
        end, 0.15)
        discarded = discarded + 1
      end
      state.track.slots[i] = nil
    end
  end

  local newSlots = {}
  local k = 1
  for i=n+1,7 do
    local g = state.track.slots[i]
    if g then
      local obj = objByGUID(g)
      if obj and isObjNearSlot(obj, i) then
        teleportToSlot(obj, k)
        -- Defer tag access and forceFaceUp after object has time to settle
        Wait.time(function()
          if obj then
            local objTag = nil
            pcall(function() objTag = obj.tag end)
            if objTag == "Card" then forceFaceUp(obj) end
          end
        end, 0.15)
        newSlots[k] = g
        k = k + 1
      end
    end
  end

  state.track.slots = newSlots
  saveState()

  log("NEXT discarded="..tostring(discarded).." compacted="..tostring(k-1).." n="..tostring(n))

  if state.mode == "AUTO" then
    Wait.time(function()
      if state.resetInProgress then nextBusy=false; return end
      Wait.time(function()
        if state.resetInProgress then nextBusy=false; return end
        refillEmptySlots()
        nextBusy=false
      end, 0.15)
    end, 0.20)
  else
    nextBusy = false
  end

  refreshEventSlotUI_later(0.45)
end

-- === SECTION 9: NEW GAME PIPELINE (FIXED SLOT COLLECTION) ====================

local function clearTrack()
  for i=1,7 do
    local g = state.track.slots[i]
    if g and g ~= "" then
      local o = objByGUID(g)
      if isCard(o) then
        uiClearButtons(o)
        uiClearTrackDescription(o)
      end
    end
  end
  state.track.slots = {}
  saveState()
end

local function collectFromHands()
  local out = {}
  for _,p in ipairs(Player.getPlayers()) do
    local ok, hand = pcall(function() return p.getHandObjects() end)
    if ok and type(hand)=="table" then
      for _,o in ipairs(hand) do
        if isCardOrDeck(o) then table.insert(out, o) end
      end
    end
  end
  return out
end

local function uniqueObjects(list)
  local uniq, seen = {}, {}
  for _,o in ipairs(list or {}) do
    if o and o.getGUID then
      local g = o.getGUID()
      if g and not seen[g] then
        seen[g] = true
        table.insert(uniq, o)
      end
    end
  end
  return uniq
end

-- FIX: collect slot contents by POSITION (independent of state.track)
local function collectCardsOnSlot(slotIdx)
  local out = {}
  local p = slotWorldPos(slotIdx)
  if not p then return out end
  for _, o in ipairs(getAllObjects()) do
    if isCardOrDeck(o) and isNearPos(o, p, SLOT_DIST_EPS) then
      table.insert(out, o)
    end
  end
  return out
end

local function collectAllCardsOnSlots()
  local pile = {}
  for i=1,7 do
    local list = collectCardsOnSlot(i)
    for _,o in ipairs(list) do table.insert(pile, o) end
  end
  return pile
end

local function collectAllCandidateEventObjects()
  local pile = {}

  -- (A) ALWAYS collect objects on slots 1-7 by position
  local slotObjs = collectAllCardsOnSlots()
  for _,o in ipairs(slotObjs) do table.insert(pile, o) end

  -- (B) Collect all event objects on table by heuristics (tags/prefix/names)
  for _,o in ipairs(getAllObjects()) do
    if isCardOrDeck(o) then
      local k = classifyKindByHeuristics(o)
      if k == "YOUTH" or k == "ADULT" then
        table.insert(pile, o)
      end
    end
  end

  -- (C) Collect near deck position + used position
  local dp = deckWorldPos()
  if dp then
    local near = collectNearWorldPos(dp, DECK_DIST_EPS)
    for _,o in ipairs(near) do
      if isCardOrDeck(o) then table.insert(pile, o) end
    end
  end

  local up = usedWorldPos()
  if up then
    local nearU = collectNearWorldPos(up, USED_DIST_EPS)
    for _,o in ipairs(nearU) do
      if isCardOrDeck(o) then table.insert(pile, o) end
    end
  end

  -- (D) Collect from hands
  local hand = collectFromHands()
  for _,o in ipairs(hand) do table.insert(pile, o) end

  return uniqueObjects(pile)
end

local function splitByKind(objects)
  local youth, adult, unknown = {}, {}, {}
  for _,o in ipairs(objects or {}) do
    local k = classifyKindByHeuristics(o)
    if k == "YOUTH" then table.insert(youth, o)
    elseif k == "ADULT" then table.insert(adult, o)
    else table.insert(unknown, o) end
  end
  return youth, adult, unknown
end

local function phase_tag_and_facedown(list, kind)
  local deckTag, cardTag, expectedName = kindTags(kind)
  for _,o in ipairs(list or {}) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Deck" then
        ensureTag(o, deckTag)
        ensureTag(o, TAG_EVT_CARD)
        ensureTag(o, cardTag)
        pcall(function() o.setName(expectedName) end)
        forceFaceDown(o)
      elseif objTag == "Card" then
        ensureTag(o, TAG_EVT_CARD)
        ensureTag(o, cardTag)
        uiClearButtons(o)
        uiClearTrackDescription(o)
        forceFaceDown(o)
      end
    end
  end
end

local function phase_move_to_park(list, kind, reason)
  local stack = 0
  for _,o in ipairs(list or {}) do
    if o and isCardOrDeck(o) then
      moveObjectToPark(o, kind, stack, reason)
      stack = stack + 1
    end
  end
end

local function phase_merge_on_park(kind)
  local deckTag, cardTag, expectedName = kindTags(kind)
  local base, bestQty = nil, -1
  local p = parkPosForKind(kind)

  -- pick biggest tagged deck in park area
  for _,o in ipairs(getAllObjects()) do
    if o then
      local objTag = nil
      pcall(function() objTag = o.tag end)
      if objTag == "Deck" and o.hasTag and o.hasTag(deckTag) and isNearPos(o, p, PARK_MERGE_EPS) then
        local q = safeQty(o)
        if q > bestQty then bestQty=q; base=o end
      end
    end
  end

  -- fallback: any biggest deck in park area
  if not base then
    for _,o in ipairs(getAllObjects()) do
      if o then
        local objTag = nil
        pcall(function() objTag = o.tag end)
        if objTag == "Deck" and isNearPos(o, p, PARK_MERGE_EPS) then
          local q = safeQty(o)
          if q > bestQty then bestQty=q; base=o end
        end
      end
    end
  end

  if not base then return nil end

  ensureTag(base, deckTag)
  ensureTag(base, TAG_EVT_CARD)
  ensureTag(base, cardTag)
  pcall(function() base.setName(expectedName) end)
  forceFaceDown(base)

  local baseGuid = nil
  pcall(function() baseGuid = (base.getGUID and base.getGUID()) or nil end)

  local near = {}
  for _,o in ipairs(getAllObjects()) do
    if o then
      local objTag = nil
      local objGuid = nil
      pcall(function() objTag = o.tag end)
      pcall(function() objGuid = (o.getGUID and o.getGUID()) or nil end)
      if (objTag == "Card" or objTag == "Deck") and objGuid and objGuid ~= baseGuid then
        if isNearPos(o, p, PARK_MERGE_EPS) then
          table.insert(near, o)
        end
      end
    end
  end

  if base.putObject then
    for _,o in ipairs(near) do
      if o and base then pcall(function() base.putObject(o) end) end
    end
    -- Give objects time to settle after merging before accessing them
    Wait.time(function()
      for _,o in ipairs(near) do if o then pcall(function() o.setLock(false) end) end end
      pcall(function() base.setLock(false) end)
    end, 0.25)
  else
    for _,o in ipairs(near) do if o then pcall(function() o.setLock(false) end) end end
    pcall(function() base.setLock(false) end)
  end

  return base
end

local function phase_shuffle(deckObj, kind)
  if not deckObj then return false end
  local objTag = nil
  pcall(function() objTag = deckObj.tag end)
  if objTag ~= "Deck" then return false end
  local deckTag, cardTag, expectedName = kindTags(kind)
  ensureTag(deckObj, deckTag)
  ensureTag(deckObj, TAG_EVT_CARD)
  ensureTag(deckObj, cardTag)
  pcall(function() deckObj.setName(expectedName) end)
  forceFaceDown(deckObj)
  if deckObj.shuffle then pcall(function() deckObj.shuffle() end) end
  return true
end

local function pipelineNewGame(kind, refill)
  if not state.setup then
    warn("NEWGAME: setup=false (board missing?)")
    return false
  end
  if state.resetInProgress then
    warn("NEWGAME blocked: resetInProgress=true")
    return false
  end

  state.resetInProgress = true
  state.jobId = (tonumber(state.jobId) or 0) + 1
  local jobId = state.jobId
  saveState()

  kind = tostring(kind or "YOUTH"):upper()
  if kind ~= "YOUTH" and kind ~= "ADULT" then kind = "YOUTH" end
  refill = (refill ~= false)

  state.deckKind = kind
  saveState()

  log("NEWGAME start jobId="..tostring(jobId).." activeKind="..tostring(kind).." refill="..tostring(refill))

  -- ✅ FIX: Collect BEFORE clearTrack() so we don't lose refs;
  -- and slot collection does NOT depend on track anyway.
  local preCollected = collectAllCandidateEventObjects()
  local youth, adult, unknown = splitByKind(preCollected)

  log("NEWGAME collected(pre): all="..tostring(#preCollected)..
      " youth="..tostring(#youth).." adult="..tostring(#adult).." unknown="..tostring(#unknown))

  if #unknown > 0 then
    warn("NEWGAME: unknown objects="..tostring(#unknown).." (missing tags/prefixes?)")
  end

  clearTrack()
  refreshEventSlotUI_later(0.10)

  Wait.time(function()
    if state.jobId ~= jobId then return end

    phase_tag_and_facedown(youth, "YOUTH")
    phase_tag_and_facedown(adult, "ADULT")

    Wait.time(function()
      if state.jobId ~= jobId then return end
      phase_move_to_park(youth, "YOUTH", "newgame_collect")
      log("NEWGAME moved youth to park.")
    end, PIPE_STEP_DELAY_SEC)

    Wait.time(function()
      if state.jobId ~= jobId then return end
      phase_move_to_park(adult, "ADULT", "newgame_collect")
      log("NEWGAME moved adult to park.")
    end, PIPE_STEP_DELAY_SEC * 2)

    Wait.time(function()
      if state.jobId ~= jobId then return end
      local yd = phase_merge_on_park("YOUTH")
      Wait.time(function()
        if state.jobId ~= jobId then return end
        if yd then
          local ydTag = nil
          pcall(function() ydTag = yd.tag end)
          if ydTag == "Deck" then
            phase_shuffle(yd, "YOUTH")
            log("NEWGAME merged+shuffled YOUTH deck qty="..tostring(safeQty(yd)))
          else
            warn("NEWGAME: could not resolve YOUTH deck after merge.")
          end
        end
      end, PIPE_SETTLE_SEC)
    end, PIPE_STEP_DELAY_SEC * 3)

    Wait.time(function()
      if state.jobId ~= jobId then return end
      local ad = phase_merge_on_park("ADULT")
      Wait.time(function()
        if state.jobId ~= jobId then return end
        if ad then
          local adTag = nil
          pcall(function() adTag = ad.tag end)
          if adTag == "Deck" then
            phase_shuffle(ad, "ADULT")
            log("NEWGAME merged+shuffled ADULT deck qty="..tostring(safeQty(ad)))
          else
            warn("NEWGAME: could not resolve ADULT deck after merge.")
          end
        end
      end, PIPE_SETTLE_SEC)
    end, PIPE_STEP_DELAY_SEC * 4)

    Wait.time(function()
      if state.jobId ~= jobId then return end

      local deckTag = (kind=="ADULT") and TAG_ADULT_DECK or TAG_YOUTH_DECK
      local chosen = findDeckAnywhereByTag(deckTag) or ensureDeckReadyForKind(kind)

      if not chosen then
        warn("NEWGAME: chosen deck missing for kind="..tostring(kind))
        state.resetInProgress = false
        saveState()
        return
      end
      local chosenTag = nil
      pcall(function() chosenTag = chosen.tag end)
      if chosenTag ~= "Deck" then
        warn("NEWGAME: chosen object is not a Deck for kind="..tostring(kind))
        state.resetInProgress = false
        saveState()
        return
      end

      rehomeDeckToDeckPos(chosen, kind, "newgame_final")

      Wait.time(function()
        if state.jobId ~= jobId then return end
        state.resetInProgress = false
        saveState()

        refreshEventSlotUI_later(0.25)

        if refill then
          Wait.time(function() refillEmptySlots() end, PIPE_SHORT_SEC)
        end

        log("NEWGAME done jobId="..tostring(jobId).." activeKind="..tostring(kind))
      end, PIPE_STEP_DELAY_SEC)

    end, PIPE_STEP_DELAY_SEC * 5)

  end, PIPE_SHORT_SEC)

  return true
end

-- === SECTION 10: STATUS + CONTROLLER UI ======================================

local function statusDump()
  local lines = {}
  table.insert(lines, "setup="..tostring(state.setup).." | players="..tostring(state.players).." | mode="..tostring(state.mode).." | discard="..tostring(discardCount(state.players)))
  table.insert(lines, "deckKind(active)="..tostring(state.deckKind).." | resetInProgress="..tostring(state.resetInProgress).." | jobId="..tostring(state.jobId))
  table.insert(lines, "obligatoryLock="..tostring(obligatoryLock))
  table.insert(lines, "EVENT_BOARD_GUID="..tostring(EVENT_BOARD_GUID))
  table.insert(lines, "EVENT_ENGINE_GUID="..tostring(EVENT_ENGINE_GUID))
  table.insert(lines, "TRACK: deck/used/slots are LOCAL vectors (no zones).")
  return table.concat(lines, "\n")
end

local function btn(label, fn, x, z)
  self.createButton({
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x, 0.25, z},
    width = 860,
    height = 230,
    font_size = 95
  })
end

function drawUI()
  self.clearButtons()

  local x1, x2, x3, x4 = -2.7, -0.9, 0.9, 2.7
  local r1, r2, r3 = 0.95, 0.45, -0.05

  btn("MODE: "..state.mode, "ui_toggleMode", x1, r1)
  btn("SETUP", "ui_setup", x2, r1)
  btn("REFILL", "ui_refill", x3, r1)
  btn("NEXT", "ui_next", x4, r1)

  btn("P2", "ui_p2", x1, r2)
  btn("P3", "ui_p3", x2, r2)
  btn("P4", "ui_p4", x3, r2)
  btn("STATUS", "ui_status", x4, r2)

  btn("KIND="..tostring(state.deckKind), "ui_noop", x1, r3)
  btn("SETUP="..tostring(state.setup), "ui_noop", x2, r3)
  btn("JOB="..tostring(state.jobId), "ui_noop", x3, r3)
  btn("NEWGAME "..tostring(state.deckKind), "ui_newgame", x4, r3)

  btn(state.karmaDiagnostics and "KARMA DIAG ON" or "KARMA DIAG OFF", "ui_karmaDiag", x1, -0.55)
end

function ui_toggleMode()
  if state.mode == "AUTO" then state.mode = "MANUAL" else state.mode = "AUTO" end
  saveState()
  drawUI()
  log("MODE="..tostring(state.mode))
end

function ui_p2() state.players=2; saveState(); drawUI(); log("PLAYERS=2") end
function ui_p3() state.players=3; saveState(); drawUI(); log("PLAYERS=3") end
function ui_p4() state.players=4; saveState(); drawUI(); log("PLAYERS=4") end

function ui_setup()
  state.setup = hasBoard()
  saveState()
  drawUI()
  if state.setup then
    broadcastToAll("[WLB EVT CTRL] SETUP OK ✅ (board found, vectors active).", {0.3,1,0.3})
  else
    broadcastToAll("[WLB EVT CTRL] SETUP FAILED ❌ (board missing or no positionToWorld).", {1,0.3,0.3})
  end
end

function ui_status()
  print("[WLB EVT CTRL] STATUS\n"..statusDump())
end

function ui_refill()
  Wait.time(function() refillEmptySlots() end, 0.15)
end

function ui_next()
  nextTurn()
end

function ui_newgame()
  WLB_EVT_NEWGAME({kind = state.deckKind, refill = true})
end

function ui_karmaDiag()
  state.karmaDiagnostics = not state.karmaDiagnostics
  saveState()
  drawUI()
  broadcastToAll(
    state.karmaDiagnostics and "[Karma] Diagnostics ON – click an event card to see why karma modal shows or not." or "[Karma] Diagnostics OFF.",
    {0.9, 0.85, 0.6}
  )
end

-- === SECTION 11: Card UI callbacks + Engine integration ======================
-- (getEngine, getPSC, hasGoodKarma, consumeGoodKarma, isCardObligatory are defined above, before uiOpenModal, so they are in scope when modal runs)

local function safeBroadcastTo(color, msg, rgb)
  rgb = rgb or {1,1,1}
  if color and Player[color] and Player[color].seated then
    broadcastToColor(msg, color, rgb)
  else
    broadcastToAll((color and ("["..tostring(color).."] ") or "")..tostring(msg), rgb)
  end
end

-- ---------- EXTRA AP (Controller-side) ---------------------------------------

-- Check if player owns CAR Hi-Tech card (for slot extra AP reduction)
local function hasCarReduction(color)
  if not color or color == "" then return false end
  
  -- Normalize color to match Shop Engine's storage format
  local normalizedColor = tostring(color)
  if type(color) == "string" and color ~= "" then
    normalizedColor = color:sub(1,1):upper() .. color:sub(2):lower()
  end
  
  local shopEngine = nil
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_SHOP_ENGINE) then
      shopEngine = o
      break
    end
  end
  
  if not shopEngine or not shopEngine.call then return false end
  
  local ok, hasCar = pcall(function()
    return shopEngine.call("API_ownsHiTech", {color=normalizedColor, kind="CAR"})
  end)
  
  return (ok and hasCar == true)
end

local function getApCtrl(color)
  if not color or color=="" then return nil end
  local t1 = COLOR_TAG_PREFIX..tostring(color):upper()
  local t2 = COLOR_TAG_PREFIX..tostring(color)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_AP_CTRL) then
      if o.hasTag(t1) or o.hasTag(t2) then return o end
    end
  end
  return nil
end

local function canSpendExtraAP(color, extra)
  extra = tonumber(extra) or 0
  if extra <= 0 then return true end
  local apCtrl = getApCtrl(color)
  if not apCtrl or not apCtrl.call then return false end
  local ok, can = pcall(function()
    return apCtrl.call("canSpendAP", { to="EVENT", amount=extra })
  end)
  return (ok and can == true) and true or false
end

local function spendExtraAP(color, extra)
  extra = tonumber(extra) or 0
  if extra <= 0 then return true end
  local apCtrl = getApCtrl(color)
  if not apCtrl or not apCtrl.call then return false end
  local ok, paid = pcall(function()
    return apCtrl.call("spendAP", { to="EVENT", amount=extra })
  end)
  return (ok and paid == true) and true or false
end

-- ---------- obligatory lock ---------------------------------------------------

local function refreshObligatoryLock()
  obligatoryLock = false

  local g1 = state.track.slots[1]
  if not g1 or g1 == "" then return end

  local c1 = objByGUID(g1)
  if (not c1) or (c1.tag ~= "Card") then
    state.track.slots[1] = nil
    saveState()
    return
  end

  if not isObjNearSlot(c1, 1) then
    state.track.slots[1] = nil
    saveState()
    return
  end

  local engine = getEngine()
  if not engine or not engine.call then
    return
  end

  local ok, ret = pcall(function()
    return engine.call("isObligatoryCard", { card_guid = g1 })
  end)

  obligatoryLock = (ok and ret == true) and true or false
end

local function slot1HasObligatory()
  refreshObligatoryLock()
  return obligatoryLock == true
end

local function getSlotIndexForCardGuid(cardGuid)
  for i=1,7 do
    if state.track.slots[i] == cardGuid then return i end
  end
  return nil
end

local function announceSlot1ObligatoryToCurrentTurn()
  if not slot1HasObligatory() then return end
  local c = "White"
  local ok, result = pcall(function()
    return (Turns and Turns.turn_color) or nil
  end)
  if ok and result then
    c = result
  end
  safeBroadcastTo(c,
    "⚠️ W SLOT 1 jest karta obligatory. Zanim zagrasz inne eventy, rozwiąż ją jako pierwszą.",
    {1,0.85,0.25}
  )
end

function evt_onCardClicked(card, player_color, alt_click)
  if not isCard(card) then return end
  if not isObjNearAnySlot(card) then return end
  if cardHasEngineModalUI(card) then return end
  uiOpenModal(card, player_color)
end

function evt_onNo(card, player_color, alt_click)
  if not isCard(card) then return end
  local g = card.getGUID()
  -- Karma choice modal: NO = "No, resolve card as usual"
  if uiState.karmaChoice and uiState.karmaChoice[g] then
    uiState.karmaChoice[g] = nil
    evt_onYes(card, player_color, alt_click)
    return
  end
  uiCloseModal(card)
end

function evt_onUseKarma(card, player_color, alt_click)
  if not isCard(card) then return end
  
  -- Use active turn color if available, otherwise fall back to player_color
  local playerColor = player_color
  local ok, result = pcall(function()
    return (Turns and Turns.turn_color and Turns.turn_color ~= "") and Turns.turn_color or nil
  end)
  if ok and result then
    playerColor = result
  end
  if not playerColor or playerColor == "" then
    uiCloseModal(card)
    return
  end
  
  -- Consume via PSC only (no token scan); fail if PSC missing
  local psc = getPSC()
  if not psc or not psc.call then
    safeBroadcastTo(playerColor, "⛔ PlayerStatusController not found. Cannot consume Good Karma.", {1,0.6,0.2})
    uiCloseModal(card)
    return
  end
  if not hasGoodKarma(playerColor) then
    safeBroadcastTo(playerColor, "⛔ Good Karma token not found. Card not skipped.", {1,0.6,0.2})
    uiCloseModal(card)
    return
  end
  consumeGoodKarma(playerColor)
  
  -- Get slot index and clear from tracking
  local cardGuid = card.getGUID()
  local slotIdx = getSlotIndexForCardGuid(cardGuid)
  if slotIdx then
    state.track.slots[slotIdx] = nil
    saveState()
  end
  
  -- Discard card to used pile without playing it
  teleportToUsed(card, 0)
  
  -- Close modal
  uiCloseModalSoft(card)
  
  -- Refresh slot UI and obligatory lock
  Wait.time(function()
    refreshTrackedSlots()
    refreshObligatoryLock()
    refreshEventSlotUI()
  end, 0.25)
  
  safeBroadcastTo(playerColor, "✨ Good Karma used: Obligatory card skipped without consequences. (Good Karma token consumed)", {1,0.84,0.0})
end

function evt_onYes(card, player_color, alt_click)
  if not isCard(card) then return "ERROR" end
  local cardGuid = card.getGUID()
  -- Karma choice modal: YES = "Use Good Karma" (skip card without consequences)
  if uiState.karmaChoice and uiState.karmaChoice[cardGuid] then
    uiState.karmaChoice[cardGuid] = nil
    evt_onUseKarma(card, player_color, alt_click)
    return "KARMA_USED"
  end

  if not isObjNearAnySlot(card) then
    uiCloseModal(card)
    return "IGNORED"
  end

  local slotIdx = getSlotIndexForCardGuid(cardGuid)
  if not slotIdx then
    uiCloseModal(card)
    return "ERROR"
  end

  if slotIdx ~= 1 and slot1HasObligatory() then
    safeBroadcastTo(player_color,
      "⛔ Najpierw musisz rozwiązać kartę obligatory z SLOT 1 (inne eventy są zablokowane).",
      {1,0.6,0.2}
    )
    uiCloseModal(card)
    return "BLOCKED"
  end

  local engine = getEngine()
  if not engine then
    safeBroadcastTo(player_color, "Event Engine not found.", {1,0.4,0.4})
    uiCloseModal(card)
    return "ERROR"
  end

  -- Clear Yes/No buttons and return card to slot, but keep modalOpen[g] so refreshEventSlotUI
  -- (e.g. from a pending Wait.time) does not call uiEnsureIdle and reattach the click catcher
  -- before the engine has run. We clear modal state only after the engine returns.
  uiClearButtons(card)
  uiReturnHome(card)

  -- Use active turn color if available, otherwise fall back to player_color from button click
  -- Original logic: (Turns and Turns.turn_color and Turns.turn_color ~= "") and Turns.turn_color or player_color
  -- Wrap in pcall to safely handle if Turns is nil or problematic
  local usedColor = player_color
  local ok, result = pcall(function()
    return (Turns and Turns.turn_color and Turns.turn_color ~= "") and Turns.turn_color or nil
  end)
  if ok and result then
    usedColor = result
  end
  local extra = (EXTRA_BY_SLOT[slotIdx] or 0)
  
  -- CAR reduction logic: 
  -- Event Engine reduces base AP by 1 if base > 0 and CAR owned
  -- If base == 0 and extra > 0, Event Controller reduces extra AP by 1 if CAR owned
  -- This ensures total reduction is always exactly -1 AP (not -2)
  
  -- Since we don't know base AP here (it's in Event Engine's TYPES), we'll let Event Engine handle base reduction
  -- Then after Event Engine returns, we'll check if we should reduce extra AP:
  -- Only reduce extra AP if CAR is owned AND extra > 0 (base AP reduction already handled in Event Engine if base > 0)
  
  -- NOTE: This isn't perfect - if base == 0, Event Engine won't reduce anything, so we need to reduce extra here
  -- But if base > 0, Event Engine reduces base, so we shouldn't reduce extra here
  -- Since we can't know base, we'll pass slot_extra_ap to Event Engine and let it coordinate total reduction

  -- 1) PRE-CHECK extra AP (without charging)
  if extra > 0 then
    if not canSpendExtraAP(usedColor, extra) then
      safeBroadcastTo(player_color,
        "⛔ You don't have enough AP for the extra cost from a further slot (+"..tostring(extra).." AP).",
        {1,0.6,0.2}
      )
      uiState.modalOpen[card.getGUID()] = nil
      karmaChoice = nil
      modalColor = nil
      uiEnsureIdle(card)
      return "BLOCKED"
    end
  end

  -- 2) Call Engine (Engine charges BASE AP)
  local ok, ret = pcall(function()
    return engine.call("playCardFromUI", {
      card_guid = cardGuid,
      player_color = usedColor,
      slot_idx = slotIdx,
      slot_extra_ap = extra,
    })
  end)

  if not ok then
    warn("Engine call failed for card="..tostring(cardGuid))
    uiState.modalOpen[card.getGUID()] = nil
    karmaChoice = nil
    modalColor = nil
    uiEnsureIdle(card)
    return "ERROR"
  end

  if ret == "BLOCKED" or ret == "ERROR" or ret == false or ret == nil then
    uiState.modalOpen[card.getGUID()] = nil
    karmaChoice = nil
    modalColor = nil
    uiEnsureIdle(card)
    return (ret == nil) and "ERROR" or ret
  end

  -- Success: clear modal state so refreshEventSlotUI_later can manage the card
  local g = card.getGUID()
  uiState.modalOpen[g] = nil
  karmaChoice = nil
  modalColor = nil

  -- 3) SUCCESS => charge extra AP now
  -- Event Engine has calculated total AP (base + slot extra) and applied CAR reduction once
  -- Get the adjusted slot extra AP value (CAR reduction already applied in Event Engine)
  local adjustedExtra = extra
  if extra > 0 and engine and engine.call then
    local ok, adjusted = pcall(function()
      return engine.call("getAdjustedSlotExtraAP", { card_guid = cardGuid })
    end)
    if ok and adjusted ~= nil then
      adjustedExtra = tonumber(adjusted) or 0
      if adjustedExtra ~= extra then
        log("CAR: Using Event Engine adjusted slot extra AP: "..tostring(extra).." -> "..tostring(adjustedExtra))
      end
    end
  end
  
  if adjustedExtra > 0 then
    local paid = spendExtraAP(usedColor, adjustedExtra)
    if not paid then
      warn("EXTRA AP spend failed after engine success. color="..tostring(usedColor).." extra="..tostring(extra))
      safeBroadcastTo(player_color,
        "⚠️ Card played, but failed to deduct extra AP cost (+"..tostring(extra).."). Check AP_CTRL.",
        {1,0.85,0.25}
      )
    end
  end

  log("YES delegated to Engine ret="..tostring(ret).." slot="..tostring(slotIdx)..
      " extra="..tostring(extra).." color="..tostring(usedColor).." card="..tostring(cardGuid))

  if slotIdx == 1 then
    Wait.time(function()
      refreshTrackedSlots()
      refreshObligatoryLock()
      saveState()
    end, 0.25)
  end

  refreshEventSlotUI_later(0.35)
  return ret
end

-- === SECTION 12: PUBLIC API ==================================================

-- Compatibility entry point:
-- Some older UI / scripts call EventController.playCardFromUI({card_guid, player_color, slot_idx}).
-- This wrapper executes the same flow as clicking YES on a track card.
function playCardFromUI(args)
  -- IMPORTANT:
  -- This function is called via <call/playCardFromUI> from other scripts.
  -- TTS can compile large scripts into multiple chunks; treat EVERY helper as potentially missing here.
  -- This implementation must never hard-crash (no "attempt to call a nil value").

  -- Signature so you can confirm the new code is running in TTS console.
  if type(print) == "function" then
    print("[WLB EVT CTRL] playCardFromUI v2 (chunk-safe)")
  end

  if type(getObjectFromGUID) ~= "function" then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: getObjectFromGUID missing")
    end
    return "ERROR"
  end

  if type(pcall) ~= "function" then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: pcall missing")
    end
    return "ERROR"
  end

  if type(args) ~= "table" then args = {} end

  local cardGuid = args.card_guid or args.cardGuid or args.guid
  if not cardGuid or cardGuid == "" then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: missing card_guid")
    end
    return "ERROR"
  end

  local card = getObjectFromGUID(cardGuid)
  if not card or card.tag ~= "Card" then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: card not found / not Card guid="..tostring(cardGuid))
    end
    return "ERROR"
  end

  local usedColor = args.player_color or args.color or args.playerColor
  if not usedColor or usedColor == "" then
    local ok, tc = pcall(function()
      return (Turns and Turns.turn_color and Turns.turn_color ~= "") and Turns.turn_color or nil
    end)
    usedColor = (ok and tc) or usedColor or "White"
  end

  -- Obligatory + Good Karma: must show karma modal, do not resolve directly
  if type(isCardObligatory) == "function" and type(hasGoodKarma) == "function" then
    local okObl, obligatory = pcall(function() return isCardObligatory(card) end)
    local okKar, hasKarma = pcall(function() return hasGoodKarma(usedColor) end)
    if okObl and obligatory == true and okKar and hasKarma == true then
      if type(uiOpenModal) == "function" then
        uiOpenModal(card, usedColor)
        return "KARMA_CHOICE"
      end
    end
  end

  -- Preferred: delegate to evt_onYes (same logic as clicking YES)
  if type(evt_onYes) == "function" then
    local okCall, ret = pcall(function()
      return evt_onYes(card, usedColor, false)
    end)
    if okCall then
      return ret or "DONE"
    end
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: evt_onYes crashed guid="..tostring(cardGuid).." err="..tostring(ret))
    end
    return "ERROR"
  end

  -- Fallback: call Event Engine directly (requires slot_idx in args)
  local slotIdx = tonumber(args.slot_idx or args.slot or args.slotIndex)
  if not slotIdx then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: missing slot_idx and evt_onYes not available")
    end
    return "ERROR"
  end

  local engine = getObjectFromGUID(EVENT_ENGINE_GUID)
  if not engine or not engine.call then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: Event Engine not found guid="..tostring(EVENT_ENGINE_GUID))
    end
    return "ERROR"
  end

  local extra = 0
  if type(EXTRA_BY_SLOT) == "table" then
    extra = tonumber(EXTRA_BY_SLOT[slotIdx] or 0) or 0
  end

  local okEng, retEng = pcall(function()
    return engine.call("playCardFromUI", {
      card_guid = cardGuid,
      player_color = usedColor,
      slot_idx = slotIdx,
      slot_extra_ap = extra,
    })
  end)

  if not okEng then
    if type(print) == "function" then
      print("[WLB EVT CTRL][WARN] playCardFromUI: engine call failed err="..tostring(retEng))
    end
    return "ERROR"
  end

  return retEng or "DONE"
end

function EVT_AUTO_REFILL_AFTER_RESET(params)
  params = params or {}
  local d = tonumber(params.delay) or (PIPE_STEP_DELAY_SEC + 0.2)
  Wait.time(function() refillEmptySlots() end, d)
end

function EVT_AUTO_NEXT_TURN()
  if slot1HasObligatory() then
    local c = "White"
    local ok, result = pcall(function()
      return (Turns and Turns.turn_color) or nil
    end)
    if ok and result then
      c = result
    end
    safeBroadcastTo(c,
      "⛔ Nie możesz zakończyć tury: w SLOT 1 jest karta obligatory. Rozwiąż ją w tej turze.",
      {1,0.6,0.2}
    )
    return false
  end

  nextTurn()

  Wait.time(function()
    if state.resetInProgress then return end
    announceSlot1ObligatoryToCurrentTurn()
  end, POST_NEXT_OBLIGATORY_DELAY)

  return true
end

function setPlayers(params)
  local n = clampPlayers(params and (params.players or params.n or params.count))
  state.players = n
  saveState()
  drawUI()
  log("API setPlayers -> "..tostring(state.players))
  return { ok=true, players=state.players, discard=discardCount(state.players) }
end

function setMode(params)
  local m = tostring(params and params.mode or ""):upper()
  if m ~= "AUTO" and m ~= "MANUAL" then m = "AUTO" end
  state.mode = m
  saveState()
  drawUI()
  log("API setMode -> "..tostring(state.mode))
  return { ok=true, mode=state.mode }
end

function API_setPlayers(params) return setPlayers(params) end
function API_setMode(params) return setMode(params) end

function WLB_EVT_NEWGAME(params)
  params = params or {}
  local kind = tostring(params.kind or "YOUTH"):upper()
  local refill = (params.refill ~= false)
  return pipelineNewGame(kind, refill)
end

function EVT_NEW_GAME_PREP(params) return WLB_EVT_NEWGAME(params) end

-- Youth→Adult (round 5→6): switch event deck to Adult only. No full reset (no collect, no park, no merge).
-- Current slot cards (youth) are gathered and returned to the youth deck (parked); slots are refilled from adult deck.
-- Youth and adult decks stay separate (no mixing). Player state is unchanged elsewhere.
function WLB_EVT_SWITCH_TO_ADULT(params)
  if state.deckKind == "ADULT" then return true end
  if state.resetInProgress then return false end

  local youthDeck = findDeckAnywhereByTag(TAG_YOUTH_DECK)
  for i = 1, 7 do
    local g = state.track.slots[i]
    if g and g ~= "" then
      local obj = objByGUID(g)
      if obj and isCard(obj) then
        uiClearButtons(obj)
        uiClearTrackDescription(obj)
        if obj.getGUID then
          uiState.modalOpen[obj.getGUID()] = nil
          uiState.homePos[obj.getGUID()] = nil
        end
        if youthDeck and youthDeck.putObject then
          pcall(function() youthDeck.putObject(obj) end)
        else
          teleportToUsed(obj, i - 1)
        end
      end
    end
    state.track.slots[i] = nil
  end

  state.deckKind = "ADULT"
  saveState()
  refreshEventSlotUI_later(0.15)
  Wait.time(function()
    if state.resetInProgress then return end
    refillEmptySlots()
    log("EVT_SWITCH_TO_ADULT: youth cards returned to youth deck (parked), deckKind=ADULT, slots refilled from adult deck")
  end, 0.35)
  return true
end

function EVT_SWITCH_TO_ADULT(params) return WLB_EVT_SWITCH_TO_ADULT(params or {}) end
function WLB_EVT_REFILL(_) return refillEmptySlots() end
function WLB_EVT_NEXT(_) return EVT_AUTO_NEXT_TURN() end

function WLB_EVT_SLOT_EXTRA_AP(params)
  local i = tonumber(params and params.slot_idx)
  return EXTRA_BY_SLOT[i] or 0
end

-- === SECTION 12.5: CALL FOR AUCTION (AD_47) ==================================
local AUCTION_COLORS = {"Yellow", "Blue", "Red", "Green"}

local function auctionCard()
  if not auctionState.active or not auctionState.eventCardGuid then return nil end
  return objByGUID(auctionState.eventCardGuid)
end

local function auctionUpdateDescription()
  local card = auctionCard()
  if not card or not card.setDescription then return end
  local parts = {}
  for _, c in ipairs(AUCTION_COLORS) do
    if auctionState.participants[c] then table.insert(parts, c) end
  end
  local joined = (#parts > 0) and table.concat(parts, ", ") or "(none)"
  pcall(function() card.setDescription("Auction L2. Joined: " .. joined) end)
end

-- owner: optional Object to own the button callbacks (default self). Pass explicitly so delayed callbacks have valid reference.
local function auctionClearAndAddButtons(buttons, owner)
  local card = auctionCard()
  if not card then return end
  local ctrl = (owner and type(owner.call) == "function") and owner or self
  pcall(function() card.clearButtons() end)
  for _, b in ipairs(buttons or {}) do
    pcall(function()
      card.createButton({
        click_function = b.fn,
        function_owner = ctrl,
        label = b.label,
        position = b.pos or {0, 0.35, 0},
        rotation = {0, 0, 0},
        width = b.w or 800,
        height = b.h or 200,
        font_size = b.font or 120,
        color = b.color or {0.2, 0.6, 0.2, 0.95},
        font_color = {1, 1, 1, 1},
        tooltip = b.tooltip or "",
      })
    end)
  end
end

local function auctionCancelBidderTimer()
  if auctionState.bidderTimerId then
    if Wait.stop then Wait.stop(auctionState.bidderTimerId) end
    auctionState.bidderTimerId = nil
  end
end

local function auctionCancelBidderTick()
  if auctionState.bidderTickId then
    if Wait.stop then Wait.stop(auctionState.bidderTickId) end
    auctionState.bidderTickId = nil
  end
end

local function auctionBuildSnapshot()
  local s = auctionState
  local participantsList = {}
  for _, c in ipairs(AUCTION_COLORS) do if s.participants[c] then table.insert(participantsList, c) end end
  local remaining = AUCTION_BIDDER_TIMER_SEC
  if s.state == "BIDDING" and s.bidderTurnStartTime and type(os) == "table" and os.clock then
    local elapsed = os.clock() - s.bidderTurnStartTime
    remaining = math.max(0, math.floor(AUCTION_BIDDER_TIMER_SEC - elapsed + 0.5))
  end
  return {
    state = s.state,
    currentPrice = s.currentPrice,
    currentBidderColor = s.currentBidderColor,
    leaderColor = s.leaderColor,
    participants = participantsList,
    activeBidders = (s.activeBidders and #s.activeBidders) or 0,
    timerSeconds = remaining,
    timerMaxSeconds = AUCTION_BIDDER_TIMER_SEC,
  }
end

-- Forward declarations so timer callback (different chunk in TTS) can call these
local auctionNextBidderInOrder, auctionResolve

-- Set by Global script on load via Auction_RegisterGlobal({ guid = self.getGUID() }) so auction UI is found without manual config.
local auctionRegisteredGlobalGUID = nil

function Auction_RegisterGlobal(params)
  params = params or {}
  auctionRegisteredGlobalGUID = (params.guid and params.guid ~= "") and params.guid or nil
end

-- In TTS, Global script is not on an object – you cannot tag it. Object scripts get a built-in "Global"
-- reference and call Global.call("functionName", params) to run Global script functions (see TurnController).
local function auctionGetGlobalObject()
  if Global and type(Global.call) == "function" then
    return Global
  end
  -- Fallbacks only if Global is not available (e.g. very old TTS or custom setup)
  if auctionRegisteredGlobalGUID then
    local g = getObjectFromGUID(auctionRegisteredGlobalGUID)
    if g and g.call then return g end
  end
  if EVT_GLOBAL_GUID and EVT_GLOBAL_GUID ~= "" then
    local g = getObjectFromGUID(EVT_GLOBAL_GUID)
    if g and g.call then return g end
  end
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_EVT_GLOBAL) and o.call then return o end
  end
  return nil
end

local function auctionUINotifyShow()
  local g = auctionGetGlobalObject()
  if g then
    pcall(function() g.call("UI_AuctionShow", auctionBuildSnapshot()) end)
  else
    broadcastToAll("Auction panel: Global script not reachable. Ensure Global script and Global UI (VocationsUI_Global.xml) are in TTS Global script/UI.", {1,0.6,0.2})
  end
end

local function auctionUINotifyUpdate()
  local g = auctionGetGlobalObject()
  if g then pcall(function() g.call("UI_AuctionUpdate", auctionBuildSnapshot()) end) end
end

local function auctionUINotifyHide()
  local g = auctionGetGlobalObject()
  if g then pcall(function() g.call("UI_AuctionHide") end) end
end

local function auctionStartBidderTimer()
  auctionCancelBidderTimer()
  auctionCancelBidderTick()
  if auctionState.state ~= "BIDDING" or not auctionState.currentBidderColor then return end
  auctionState.bidderTurnStartTime = (os and os.clock) and os.clock() or nil
  local color = auctionState.currentBidderColor
  auctionState.bidderTimerId = Wait.time(function()
    auctionState.bidderTimerId = nil
    auctionCancelBidderTick()
    if not auctionState.active or auctionState.state ~= "BIDDING" then return end
    if auctionState.currentBidderColor ~= color then return end
    broadcastToAll("Auction: " .. color .. " did not act in time – auto Pass.", {0.9,0.7,0.2})
    auction_doPass(color)
  end, AUCTION_BIDDER_TIMER_SEC)
  -- Update UI every second so timer countdown is visible
  local function tick()
    if not auctionState.active or auctionState.state ~= "BIDDING" then return end
    auctionState.bidderTickId = Wait.time(tick, 1)
    auctionUINotifyUpdate()
  end
  auctionState.bidderTickId = Wait.time(tick, 1)
end

-- Internal: perform pass for a color (used by timer and by UI/card callbacks via auction_pass_btn).
function auction_doPass(color)
  if not auctionState.active or auctionState.state ~= "BIDDING" then return end
  color = (color and type(color)=="string") and (color:sub(1,1):upper()..color:sub(2):lower()) or ""
  if color ~= auctionState.currentBidderColor then return end
  local ab = auctionState.activeBidders
  for i, c in ipairs(ab) do
    if c == color then table.remove(ab, i); break end
  end
  auctionState.currentBidderColor = auctionNextBidderInOrder()
  auctionUpdateDescription()
  auctionCancelBidderTimer()
  auctionCancelBidderTick()
  broadcastToAll("Auction: " .. color .. " passes. Next: " .. tostring(auctionState.currentBidderColor or "—"), {0.8,0.8,0.8})
  if #ab <= 1 then
    auctionResolve()
  else
    auctionStartBidderTimer()
    auctionUINotifyUpdate()
  end
end

local function auctionCleanup()
  auctionCancelBidderTimer()
  auctionCancelBidderTick()
  auctionUINotifyHide()
  local card = auctionCard()
  if card then
    pcall(function() card.setLock(false) end)
    pcall(function() card.clearButtons() end)
    pcall(function() card.setDescription("") end)
    teleportToUsed(card, 0)
  end
  auctionState.active = false
  auctionState.state = nil
  auctionState.initiatorColor = nil
  auctionState.eventCardGuid = nil
  auctionState.participants = {}
  auctionState.deposits = {}
  auctionState.currentPrice = AUCTION_MIN_PRICE
  auctionState.currentBidderColor = nil
  auctionState.leaderColor = nil
  auctionState.activeBidders = {}
  auctionState.finalOrder = nil
  auctionState.bidderTimerId = nil
  auctionState.bidderTickId = nil
  auctionState.bidderTurnStartTime = nil
end

function Auction_Start(params)
  params = params or {}
  local initiatorColor = params.initiatorColor or (Turns and Turns.turn_color)
  local cardGuid = params.cardGuid
  if not initiatorColor or not cardGuid then
    broadcastToAll("[Auction] Missing initiatorColor or cardGuid.", {1,0.5,0.2})
    return
  end
  if auctionState.active then
    broadcastToAll("[Auction] An auction is already in progress.", {1,0.5,0.2})
    return
  end
  local card = objByGUID(cardGuid)
  if not card or not isCard(card) then
    broadcastToAll("[Auction] Card not found.", {1,0.5,0.2})
    return
  end
  auctionState.active = true
  auctionState.state = "JOINING"
  auctionState.initiatorColor = initiatorColor
  auctionState.eventCardGuid = cardGuid
  auctionState.participants = {}
  auctionState.deposits = {}
  auctionState.currentPrice = AUCTION_MIN_PRICE
  auctionState.currentBidderColor = nil
  auctionState.leaderColor = nil
  auctionState.activeBidders = {}
  auctionState.finalOrder = nil

  pcall(function() card.setLock(true) end)
  -- Remove card from track slot so Next / refill don't move it to used pile
  local slotIdx = getSlotIndexForCardGuid(cardGuid)
  if slotIdx then
    state.track.slots[slotIdx] = nil
    saveState()
  end
  -- Place auction card at local position (AUCTION_CARD_LOCAL: x=10 on board); convert to world only for setPosition
  local p = auctionCardWorldPos()
  if p then
    pcall(function() card.setPosition({p.x, p.y, p.z}) end)
  end
  uiState.modalOpen[cardGuid] = nil
  uiState.homePos[cardGuid] = nil
  uiClearButtons(card)
  auctionUpdateDescription()
  -- Add "Pay 500 & Join" button after a short delay so the card has settled (avoids buttons not sticking)
  local ctrl = self
  Wait.time(function()
    if not auctionState.active or auctionState.state ~= "JOINING" or auctionState.eventCardGuid ~= cardGuid then return end
    auctionClearAndAddButtons({
      { fn = "auction_join", label = "Pay 500 & Join", pos = {0, 0.35, 0}, w = 1200, h = 220, font = 140, tooltip = "Pay 500 WIN deposit to join the auction" },
    }, ctrl)
  end, 0.3)
  broadcastToAll("🏠 Call for Auction started. " .. initiatorColor .. " is the initiator. Pay 500 & Join on the card until initiator's next turn.", {0.7,0.9,1})
end

function auction_join(card, player_color, alt_click)
  if not auctionState.active or auctionState.state ~= "JOINING" then return end
  local clicker = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if clicker == "" then return end
  -- Spectator (White): treat as the current turn player joining
  local joinColor = (clicker == "White") and (Turns and Turns.turn_color and Turns.turn_color ~= "" and (Turns.turn_color:sub(1,1):upper()..Turns.turn_color:sub(2):lower())) or clicker
  if not joinColor or joinColor == "" then
    safeBroadcastTo(clicker, "No current turn set. Cannot join auction.", {1,0.6,0.2})
    return
  end
  -- Only the player whose turn it is can join (one join per turn)
  local turnColor = (Turns and Turns.turn_color and Turns.turn_color ~= "") and (Turns.turn_color:sub(1,1):upper()..Turns.turn_color:sub(2):lower()) or nil
  if not turnColor or joinColor ~= turnColor then
    safeBroadcastTo(clicker, "It's not your turn to join the auction. Only the current turn player can click Pay 500 & Join.", {1,0.7,0.2})
    return
  end
  if auctionState.participants[joinColor] then
    safeBroadcastTo(joinColor, "You already joined the auction.", {1,0.8,0.2})
    return
  end
  -- Initiator must also pay 500 to join (same as others)
  if not auctionCanSpend(joinColor, AUCTION_JOIN_DEPOSIT) then
    safeBroadcastTo(joinColor, "You need 500 WIN to join. You don't have enough.", {1,0.6,0.2})
    return
  end
  if not auctionSpend(joinColor, AUCTION_JOIN_DEPOSIT) then
    safeBroadcastTo(joinColor, "Failed to pay 500 WIN.", {1,0.6,0.2})
    return
  end
  auctionState.participants[joinColor] = true
  auctionState.deposits[joinColor] = AUCTION_JOIN_DEPOSIT
  auctionUpdateDescription()
  broadcastToAll(joinColor .. " joined the auction (500 WIN deposit).", {0.5,1,0.5})
end

function Auction_OnTurnStart(params)
  params = params or {}
  local activeColor = params.activeColor
  local finalOrder = params.finalOrder
  if not auctionState.active or auctionState.state ~= "JOINING" then return end
  -- One full round: when initiator's turn comes again, start BIDDING immediately
  if not activeColor or activeColor ~= auctionState.initiatorColor then return end
  auctionState.state = "BIDDING"
  auctionState.finalOrder = finalOrder
  local order = (type(finalOrder)=="table" and #finalOrder>0) and finalOrder or AUCTION_COLORS
  auctionState.activeBidders = {}
  for _, c in ipairs(order) do
    if auctionState.participants[c] then
      table.insert(auctionState.activeBidders, c)
    end
  end
  auctionState.currentPrice = AUCTION_MIN_PRICE
  auctionState.leaderColor = nil
  auctionState.currentBidderColor = (#auctionState.activeBidders > 0) and auctionState.activeBidders[1] or nil

  if #auctionState.activeBidders == 1 then
    auctionState.state = "RESOLVED_ONE"
    auctionClearAndAddButtons({
      { fn = "auction_buy_btn", label = "Buy (1500 WIN)", pos = {-0.5, 0.35, 0}, w = 900, h = 180, font = 110, tooltip = "Pay 1000 WIN more (1500 total), get L2" },
      { fn = "auction_decline_btn", label = "Decline", pos = {0.5, 0.35, 0}, w = 500, h = 180, font = 120, color = {0.7,0.3,0.2,0.95}, tooltip = "Refund 500 WIN, no property" },
    })
    broadcastToAll("Auction: Only one participant. Buy L2 for 1500 WIN or decline (refund 500).", {0.7,1,0.7})
    return
  end

  -- BIDDING: no buttons on the card – only the board UI panel (top of screen). Clear card so the overlay is the only way to act.
  auctionClearAndAddButtons({})
  auctionUpdateDescription()
  broadcastToAll("Auction: Bidding started. Use the AUCTION PANEL at the top of the screen – Bid or Pass. Current price " .. auctionState.currentPrice .. " WIN. " .. tostring(auctionState.currentBidderColor or "?") .. " to act.", {0.7,1,0.7})
  auctionUINotifyShow()
  auctionStartBidderTimer()
end

function auction_buy_btn(card, player_color, alt_click)
  if not auctionState.active or auctionState.state ~= "RESOLVED_ONE" then return end
  player_color = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if #auctionState.activeBidders ~= 1 or auctionState.activeBidders[1] ~= player_color then return end
  local payMore = 1000
  if not auctionCanSpend(player_color, payMore) then
    safeBroadcastTo(player_color, "You need 1000 WIN more (1500 total). Cannot buy.", {1,0.6,0.2})
    return
  end
  if not auctionSpend(player_color, payMore) then return end
  local estate = getObjectFromGUID("fd8ce0")
  if estate and estate.call then
    pcall(function() estate.call("Auction_AssignL2", { color = player_color }) end)
  end
  broadcastToAll("Auction: " .. player_color .. " buys L2 for 1500 WIN.", {0.5,1,0.5})
  auctionCleanup()
end

function auction_decline_btn(card, player_color, alt_click)
  if not auctionState.active or auctionState.state ~= "RESOLVED_ONE" then return end
  player_color = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if #auctionState.activeBidders ~= 1 or auctionState.activeBidders[1] ~= player_color then return end
  auctionAdd(player_color, AUCTION_JOIN_DEPOSIT)
  broadcastToAll("Auction: " .. player_color .. " declined. 500 WIN refunded.", {0.8,0.8,0.8})
  auctionCleanup()
end

auctionNextBidderInOrder = function()
  local order = auctionState.finalOrder
  if not order or #order == 0 then order = AUCTION_COLORS end
  local ab = auctionState.activeBidders
  local current = auctionState.currentBidderColor
  local idx = nil
  for i, c in ipairs(order) do
    if c == current then idx = i; break end
  end
  if not idx then return ab[1] end
  for j = 1, #order do
    local k = ((idx - 1 + j) % #order) + 1
    local c = order[k]
    for _, b in ipairs(ab) do if b == c then return c end end
  end
  return nil
end

auctionResolve = function()
  auctionState.state = "RESOLVED"
  local ab = auctionState.activeBidders
  local winner = auctionState.leaderColor
  if #ab == 1 then
    winner = ab[1]
  elseif #ab == 0 then
    for c, _ in pairs(auctionState.deposits) do
      auctionAdd(c, AUCTION_JOIN_DEPOSIT)
    end
    broadcastToAll("Auction: Everyone passed. All deposits refunded.", {0.8,0.8,0.8})
    auctionCleanup()
    return
  end
  if not winner then winner = (#ab > 0) and ab[#ab] or nil end
  local payAmount = auctionState.currentPrice - AUCTION_JOIN_DEPOSIT
  if payAmount > 0 and winner then
    if not auctionCanSpend(winner, payAmount) then
      broadcastToAll("Auction: Winner " .. winner .. " cannot pay " .. payAmount .. " WIN. Refunding all.", {1,0.6,0.2})
      for c, _ in pairs(auctionState.deposits) do auctionAdd(c, AUCTION_JOIN_DEPOSIT) end
      auctionCleanup()
      return
    end
    auctionSpend(winner, payAmount)
  end
  -- Refund 500 WIN to every participant who is not the winner (all who had a deposit)
  for c, _ in pairs(auctionState.deposits) do
    if c ~= winner then
      auctionAdd(c, AUCTION_JOIN_DEPOSIT)
    end
  end
  -- Assign L2 property to winner via EstateEngine (money already taken above)
  local estate = getObjectFromGUID("fd8ce0")
  if estate and estate.call then
    pcall(function() estate.call("Auction_AssignL2", { color = winner }) end)
  else
    broadcastToAll("Auction: Winner " .. tostring(winner) .. " paid but L2 assignment failed (EstateEngine not found).", {1,0.6,0.2})
  end
  broadcastToAll("Auction: " .. tostring(winner) .. " wins L2 for " .. auctionState.currentPrice .. " WIN. Others refunded 500.", {0.5,1,0.5})
  auctionCleanup()
end

function auction_bid_btn(card, player_color, alt_click)
  if not auctionState.active or auctionState.state ~= "BIDDING" then return end
  player_color = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if player_color ~= auctionState.currentBidderColor then
    safeBroadcastTo(player_color or "White", "Not your turn to bid.", {1,0.7,0.2})
    return
  end
  local newPrice = auctionState.currentPrice + AUCTION_INCREMENT
  local needExtra = newPrice - AUCTION_JOIN_DEPOSIT
  local have = auctionGetMoney(player_color) or 0
  if needExtra > 0 and (have < needExtra) then
    safeBroadcastTo(player_color, "Insufficient funds. You need " .. needExtra .. " WIN (total " .. newPrice .. " minus 500 deposit). You have " .. tostring(have) .. " WIN.", {1,0.6,0.2})
    broadcastToAll("Auction: " .. player_color .. " cannot bid – insufficient funds.", {1,0.5,0.2})
    return
  end
  auctionCancelBidderTimer()
  auctionCancelBidderTick()
  auctionState.currentPrice = newPrice
  auctionState.leaderColor = player_color
  auctionState.currentBidderColor = auctionNextBidderInOrder()
  auctionUpdateDescription()
  broadcastToAll("Auction: " .. player_color .. " bids " .. newPrice .. " WIN. Next: " .. tostring(auctionState.currentBidderColor or "—"), {0.7,1,0.7})
  if auctionState.currentBidderColor == auctionState.leaderColor then
    auctionResolve()
  else
    auctionStartBidderTimer()
    auctionUINotifyUpdate()
  end
end

function auction_pass_btn(card, player_color, alt_click)
  if not auctionState.active or auctionState.state ~= "BIDDING" then return end
  player_color = (player_color and type(player_color)=="string") and (player_color:sub(1,1):upper()..player_color:sub(2):lower()) or ""
  if player_color ~= auctionState.currentBidderColor then return end
  auction_doPass(player_color)
end

-- Called by Global UI (and optionally by other objects). Params: { color = "Red" } etc.
function Auction_OnBid(params)
  params = params or {}
  auction_bid_btn(nil, params.color or params.playerColor, false)
end

function Auction_OnPass(params)
  params = params or {}
  auction_pass_btn(nil, params.color or params.playerColor, false)
end

-- === SECTION 13: LOAD / SAVE =================================================

function onLoad()
  loadState()

  state.setup = hasBoard()
  saveState()

  local yd = findDeckAnywhereByTag(TAG_YOUTH_DECK)
  local ad = findDeckAnywhereByTag(TAG_ADULT_DECK)
  local src = yd or ad
  if src and src.getRotation then
    desiredDeckRot = src.getRotation()
    log("DesiredDeckRot cached from deck guid="..tostring(src.getGUID()))
  else
    desiredDeckRot = nil
  end

  drawUI()

  print("[WLB EVT CTRL] Loaded v3.6.0 | setup="..tostring(state.setup)..
    " players="..tostring(state.players).." mode="..tostring(state.mode)..
    " deckKind="..tostring(state.deckKind).." discard="..tostring(discardCount(state.players)))

  Wait.time(function()
    refreshTrackedSlots()
    refreshObligatoryLock()
    refreshEventSlotUI()
  end, 0.35)

  -- OBLIGATORY WATCHDOG
  Wait.time(function()
    if not state.setup then return end
    if state.resetInProgress then return end
    refreshTrackedSlots()
    refreshObligatoryLock()
  end, OBLIG_WATCHDOG_SEC, -1)
end

function onSave()
  saveState()
  return self.script_state
end
