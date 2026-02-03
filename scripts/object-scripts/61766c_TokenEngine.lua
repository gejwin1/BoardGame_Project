-- =========================================================
-- WLB TOKEN ENGINE v2.4.0 (AUTO TARGET: active turn OR explicit color)
--
-- KEY CHANGE:
--  - No more manual UI_COLOR and no Y/B/R/G selector buttons.
--  - Target color resolution:
--      1) If args.color provided -> ALWAYS use it (victim/other player cases)
--      2) Else if button clicker is a seated player color -> use pc
--      3) Else use Turns.turn_color (active turn)
--      4) Else fallback to lastKnownTurnColor or "Yellow"
--
-- This allows:
--  - EventEngine / PlayerStatusController to always pass explicit target when needed
--  - "hurt other player" works (pass victim color)
--  - Normal "apply to active player" works even if caller omits color
--
-- Everything else (POOL, recycle lane, family, 6 status slots compact, etc.) stays.
-- =========================================================

local DEBUG = true

-- =========================
-- CONFIG
-- =========================
local BAG_GUID = "c10019"

-- Tags
local TAG_BOARD        = "WLB_BOARD"
local TAG_PLAYER_TOKEN = "WLB_PLAYER_TOKEN"
local TAG_STATUS_TOKEN = "WLB_STATUS_TOKEN"
local TAG_ESTATE_CARD  = "WLB_ESTATE_CARD"

local function TAG_COLOR(c) return "WLB_COLOR_"..c end
local function ESTATE_NAME(levelName) return "ESTATE_"..levelName end -- ESTATE_L1 etc.

-- Family token tags (must exist on tokens in the BAG)
local TAG_MARRIAGE   = "WLB_STATUS_MARRIAGE"
local TAG_CHILD_BOY  = "WLB_STATUS_CHILD_BOY"
local TAG_CHILD_GIRL = "WLB_STATUS_CHILD_GIRL"

-- Board status tags (must exist on tokens in the BAG)
local TAG_STATUS_GOODKARMA   = "WLB_STATUS_GOOD_KARMA"
local TAG_STATUS_EXPERIENCE  = "WLB_STATUS_EXPERIENCE"
local TAG_STATUS_DATING      = "WLB_STATUS_DATING"
local TAG_STATUS_SICK        = "WLB_STATUS_SICK"
local TAG_STATUS_WOUNDED     = "WLB_STATUS_WOUNDED"
local TAG_STATUS_ADDICTION   = "WLB_STATUS_ADDICTION"
local TAG_STATUS_VOUCH_C     = "WLB_STATUS_VOUCH_C"   -- 25% discount Consumables
local TAG_STATUS_VOUCH_H     = "WLB_STATUS_VOUCH_H"   -- 25% discount Hi-Tech
local TAG_STATUS_VOUCH_P     = "WLB_STATUS_VOUCH_P"   -- 20% discount Properties

-- Order of board statuses (slot 1..8) - canonical ordering (visual compact first-in)
local STATUS_ORDER = {
  TAG_STATUS_GOODKARMA,
  TAG_STATUS_EXPERIENCE,
  TAG_STATUS_DATING,
  TAG_STATUS_SICK,
  TAG_STATUS_WOUNDED,
  TAG_STATUS_ADDICTION,
  TAG_STATUS_VOUCH_C,
  TAG_STATUS_VOUCH_H,
  TAG_STATUS_VOUCH_P,
}

-- Multi-statuses:
-- - these can exist in multiple copies for the same player
-- - they should be STACKED in the SAME slot position (Y+offset per extra token)
local MULTI_STATUS = {
  [TAG_STATUS_GOODKARMA]  = true,
  [TAG_STATUS_EXPERIENCE] = true,
  [TAG_STATUS_ADDICTION]  = true,
  [TAG_STATUS_VOUCH_C]   = true,
  [TAG_STATUS_VOUCH_H]   = true,
  [TAG_STATUS_VOUCH_P]   = true,
}

-- Vertical lift between stacked status tokens on the board (0.35 avoids collider overlap → no fly-away)
local STATUS_STACK_Y = 0.35
-- Extra delay before placing newest token in same slot (avoids re-place + fly-away)
local STACK_EXTRA_DELAY = 0.85
-- Timing
local STEP_DELAY = 0.30
local HOUSING_RETURN_DELAY = 0.30

-- PRIME parking (near engine)
local PARK_ROWSIZE    = 8
local PARK_SPACING_X  = 1.10
local PARK_SPACING_Z  = 1.25
local PARK_LIFT_Y     = 0.35
local PARK_STACK_Y    = 0.05
local TAKE_DELAY      = 0.08

-- RECYCLE lane for removed STATUS tokens (keeps table tidy, avoids BAG mid-game)
local RECYCLE_OFFSET_X = 0.0
local RECYCLE_OFFSET_Z = 3.5
local RECYCLE_STACK_Y  = 0.03

-- Supported colors
local COLORS = {"Yellow","Blue","Red","Green"}

-- =========================
-- STATE
-- =========================
local POOL = {}          -- tag -> {tokens...}
local primed = false

-- FAMILY[color] = { marriage=tok|nil, kids={}, housing={level="L0".."L4", estate=nil} }
local FAMILY = {}

-- STATUSES[color] = { active = { [tag]=tok, ... } }
local STATUSES = {}

-- Auto-target helpers
local lastKnownTurnColor = "Yellow"

-- =========================
-- SLOT TABLES (family placement)
-- =========================
local FAMILY_SLOTS_BOARD = {
  Yellow = { L0 = {
    [1] = {x= 0.351, y=1.112, z=-1.808}, -- player
    [2] = {x=-0.757, y=1.112, z= 0.059}, -- partner
    [3] = {x=-0.803, y=1.112, z= 2.157},
    [4] = {x= 0.409, y=1.112, z= 2.278},
    [5] = {x= 3.015, y=1.112, z= 0.920},
    [6] = {x= 2.994, y=1.112, z=-1.185},
  }},
}

-- Estate slots (as provided)
local FAMILY_SLOTS_CARD = {
  L1 = {
    [1] = {x=-0.340, y=6.362, z=-0.967},
    [2] = {x=-0.390, y=6.363, z=-0.002},
    [3] = {x= 0.915, y=1.112, z= 0.720},
    [4] = {x= 0.914, y=1.112, z=-0.885},
    [5] = {x=-0.092, y=6.360, z= 1.244},
    [6] = {x=-0.750, y=6.356, z= 1.188},
  },
  L2 = {
    [1] = {x=-0.037, y=6.362, z=-0.929},
    [2] = {x=-0.744, y=6.359, z=-0.842},
    [3] = {x=-0.441, y=6.362, z=-0.100},
    [4] = {x= 0.914, y=1.112, z=-0.885},
    [5] = {x=-0.092, y=6.360, z= 1.244},
    [6] = {x=-0.750, y=6.356, z= 1.188},
  },
  L3 = {
    [1] = {x=-0.059, y=6.362, z=-0.993},
    [2] = {x=-0.753, y=6.357, z=-0.817},
    [3] = {x=-0.135, y=6.362, z=-0.059},
    [4] = {x=-0.740, y=6.360, z=-0.052},
    [5] = {x=-0.418, y=6.362, z= 0.751},
    [6] = {x= 0.914, y=1.112, z=-0.885},
  },
  L4 = {
    [1] = {x=-0.049, y=6.362, z=-0.960},
    [2] = {x=-0.756, y=6.361, z=-0.875},
    [3] = {x=-0.128, y=6.363, z=-0.031},
    [4] = {x=-0.752, y=6.361, z=-0.050},
    [5] = {x=-0.135, y=6.362, z= 0.735},
    [6] = {x=-0.743, y=6.360, z= 0.741},
  },
}

-- SAFE PARK (Yellow reference; cloned)
local SAFE_PARK_BOARD = {
  Yellow = {
    [1] = {x=7.365, y=1.112, z=-4.522},
    [2] = {x=7.315, y=1.112, z=-1.931},
    [3] = {x=7.324, y=1.112, z=-0.313},
    [4] = {x=7.234, y=1.112, z= 0.996},
    [5] = {x=4.994, y=1.112, z= 1.006},
    [6] = {x=5.369, y=1.112, z= 2.931},
  }
}

-- Board status slots (Yellow reference; cloned)
local STATUS_SLOTS_BOARD = {
  Yellow = { L0 = {
    -- Updated coordinates (per your latest scanner measurements) - 8 slots
    [1] = {x=-1.183, y=1.371, z=-7.600},
    [2] = {x=-1.103, y=1.371, z=-5.096},
    [3] = {x=-3.109, y=1.371, z=-7.499},
    [4] = {x=-3.075, y=1.371, z=-5.309},
    [5] = {x=-5.114, y=1.371, z=-7.590},
    [6] = {x=-5.087, y=1.371, z=-5.072},
    [7] = {x=-1.969, y=1.371, z=-6.313},
    [8] = {x=-4.197, y=1.371, z=-6.331},
  }},
}

-- =========================
-- UTILS
-- =========================
local function dprint(...)
  if DEBUG then print("[WLB_TOKEN_ENGINE]", ...) end
end

local function isSupportedColor(c)
  for _,x in ipairs(COLORS) do
    if x == c then return true end
  end
  return false
end

local function getTurnColor()
  if Turns and Turns.turn_color and Turns.turn_color ~= "" and isSupportedColor(Turns.turn_color) then
    return Turns.turn_color
  end
  return nil
end

local function resolveTargetColor(explicitColor, pc)
  -- 1) explicitColor wins always (victim scenarios)
  if explicitColor and explicitColor ~= "" and isSupportedColor(explicitColor) then
    return explicitColor
  end

  -- 2) if UI clicker is a seated player color, use it (manual testing)
  if pc and pc ~= "" and isSupportedColor(pc) and Player[pc] and Player[pc].seated then
    return pc
  end

  -- 3) active turn color
  local tc = getTurnColor()
  if tc then
    lastKnownTurnColor = tc
    return tc
  end

  -- 4) fallback
  return lastKnownTurnColor or "Yellow"
end

local function shallowCloneSlots(src)
  if type(src) ~= "table" then return nil end
  local out = {}
  for k,v in pairs(src) do
    if type(v) == "table" and v.x ~= nil then
      out[k] = {x=v.x, y=v.y, z=v.z}
    elseif type(v) == "table" then
      out[k] = shallowCloneSlots(v)
    else
      out[k] = v
    end
  end
  return out
end

local function cloneYellowToAll()
  for _,c in ipairs(COLORS) do
    if c ~= "Yellow" and (not FAMILY_SLOTS_BOARD[c]) then
      FAMILY_SLOTS_BOARD[c] = shallowCloneSlots(FAMILY_SLOTS_BOARD["Yellow"])
    end
    if c ~= "Yellow" and (not STATUS_SLOTS_BOARD[c]) then
      STATUS_SLOTS_BOARD[c] = shallowCloneSlots(STATUS_SLOTS_BOARD["Yellow"])
    end
    if c ~= "Yellow" and (not SAFE_PARK_BOARD[c]) then
      SAFE_PARK_BOARD[c] = shallowCloneSlots(SAFE_PARK_BOARD["Yellow"])
    end
  end
end

local function ensureFamily(color)
  FAMILY[color] = FAMILY[color] or { marriage=nil, kids={}, housing={level="L0", estate=nil} }
  return FAMILY[color]
end

local function ensureStatuses(color)
  STATUSES[color] = STATUSES[color] or { active = {} }
  return STATUSES[color]
end

local function getBag()
  return getObjectFromGUID(BAG_GUID)
end

local function parkBasePos()
  local p = self.getPosition()
  return {p[1] + 6.0, p[2] + PARK_LIFT_Y, p[3]}
end

local function parkPosForIndex(i)
  local base = parkBasePos()
  local row = math.floor((i-1)/PARK_ROWSIZE)
  local col = (i-1) % PARK_ROWSIZE
  local y = base[2] + (i * PARK_STACK_Y)
  return { base[1] + col*PARK_SPACING_X, y, base[3] + row*PARK_SPACING_Z }
end

-- RECYCLE parking (for removed statuses)
local function recycleBasePos()
  local base = parkBasePos()
  return { base[1] + RECYCLE_OFFSET_X, base[2], base[3] + RECYCLE_OFFSET_Z }
end

local function recyclePosForIndex(i)
  local base = recycleBasePos()
  local row = math.floor((i-1)/PARK_ROWSIZE)
  local col = (i-1) % PARK_ROWSIZE
  local y = base[2] + (i * RECYCLE_STACK_Y)
  return { base[1] + col*PARK_SPACING_X, y, base[3] + row*PARK_SPACING_Z }
end

local function worldFromLocal(parentObj, ref)
  return parentObj.positionToWorld({ref.x, ref.y, ref.z})
end

local function safePlace(obj, worldPos, worldRot)
  if not obj or not worldPos then return end
  worldRot = worldRot or {0, 180, 0}

  -- Lock briefly so physics doesn't push the token away on overlap
  pcall(function() obj.setLock(true) end)

  -- Move without collision (collide=false), fast (true) to avoid "fly-away" from collider overlap
  if obj.setPositionSmooth then
    pcall(function() obj.setPositionSmooth(worldPos, false, true) end)
  else
    pcall(function() obj.setPosition(worldPos) end)
  end
  if obj.setRotationSmooth then
    pcall(function() obj.setRotationSmooth(worldRot, false, true) end)
  else
    pcall(function() obj.setRotation(worldRot) end)
  end

  -- After a few frames: zero velocities and unlock so token stays put
  Wait.frames(function()
    pcall(function() if obj.setVelocity then obj.setVelocity({0,0,0}) end end)
    pcall(function() if obj.setAngularVelocity then obj.setAngularVelocity({0,0,0}) end end)
    pcall(function() obj.setLock(false) end)
  end, 3)
end

local function placeTokensSequential(parentObj, tokensInOrder, slotsTable, delayStep)
  delayStep = delayStep or STEP_DELAY
  for i, tok in ipairs(tokensInOrder) do
    local slot = slotsTable[i]
    if tok and slot then
      local delay = (i-1) * delayStep
      Wait.time(function()
        safePlace(tok, worldFromLocal(parentObj, slot))
      end, delay)
    end
  end
end

local function moveTokensToSafeParkSequential(boardObj, tokensInOrder, safeSlots, delayStep)
  delayStep = delayStep or STEP_DELAY
  for i, tok in ipairs(tokensInOrder) do
    local slot = safeSlots[i]
    if tok and slot then
      local delay = (i-1) * delayStep
      Wait.time(function()
        safePlace(tok, worldFromLocal(boardObj, slot))
      end, delay)
    end
  end
end

local function returnTokenToBag(tok)
  if not tok then return end
  local bag = getBag()
  if not bag then return end
  pcall(function() if tok.unlock then tok.unlock() end end)
  pcall(function() bag.putObject(tok) end)
end

local function poolCountAll()
  local n = 0
  for _, list in pairs(POOL) do
    if type(list) == "table" then n = n + #list end
  end
  return n
end

local function recycleStatusTokenToPool(statusTag, tok)
  if (not statusTag) or (not tok) then return end

  POOL[statusTag] = POOL[statusTag] or {}
  table.insert(POOL[statusTag], tok)

  local idx = poolCountAll()
  safePlace(tok, recyclePosForIndex(idx))

  pcall(function() if tok.unlock then tok.unlock() end end)
end

-- =========================
-- FINDERS
-- =========================
local function findPlayerBoard(color)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_BOARD) and o.hasTag(TAG_COLOR(color)) then
      return o
    end
  end
  return nil
end

local function findPlayerToken(color)
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_PLAYER_TOKEN) and o.hasTag(TAG_COLOR(color)) then
      return o
    end
  end
  return nil
end

local function findEstateCardByLevel(levelName)
  local wantName = ESTATE_NAME(levelName)
  local matches = {}
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(TAG_ESTATE_CARD) then
      if (o.getName() or "") == wantName then
        table.insert(matches, o)
      end
    end
  end
  if #matches == 1 then return matches[1] end
  if #matches == 0 then
    print("[WLB_TOKEN_ENGINE] ERROR: Estate card not found: "..wantName.." (tag "..TAG_ESTATE_CARD..")")
  else
    print("[WLB_TOKEN_ENGINE] ERROR: Multiple estate cards found for "..wantName..": "..#matches)
  end
  return nil
end

-- =========================
-- POOL (status tokens) - built after PRIME
-- =========================
local function poolAddByTags(obj)
  if not obj or not obj.hasTag then return end
  if not obj.hasTag(TAG_STATUS_TOKEN) then return end

  for _, t in ipairs(obj.getTags()) do
    if t ~= TAG_STATUS_TOKEN then
      POOL[t] = POOL[t] or {}
      table.insert(POOL[t], obj)
    end
  end
end

local function requestTokenByTag(tag)
  if not primed then
    dprint("POOL not primed yet. Use PRIME first.")
    return nil
  end
  local list = POOL[tag]
  if not list or #list == 0 then
    dprint("No token available for tag:", tag)
    return nil
  end
  local tok = table.remove(list, 1)
  pcall(function() if tok and tok.unlock then tok.unlock() end end)
  return tok
end

function primeTokenPool()
  local bag = getBag()
  if not bag then
    print("[WLB_TOKEN_ENGINE] ERROR: Bag not found: "..BAG_GUID)
    return
  end

  local content = bag.getObjects()
  if not content or #content == 0 then
    print("[WLB_TOKEN_ENGINE] Bag empty or no objects.")
    POOL, primed = {}, true
    return
  end

  dprint("Priming pool from bag. Count:", #content)
  POOL, primed = {}, false

  local idx = 0
  local function takeNext()
    idx = idx + 1
    if idx > #content then
      primed = true
      dprint("Prime complete.")
      return
    end
    local entry = content[idx]
    bag.takeObject({
      guid     = entry.guid,
      position = parkPosForIndex(idx),
      rotation = {0,180,0},
      smooth   = false,
      callback_function = function(obj)
        pcall(function() if obj and obj.unlock then obj.unlock() end end)
        poolAddByTags(obj)
        Wait.time(takeNext, TAKE_DELAY)
      end
    })
  end
  takeNext()
end

function collectAllStatusTokensToBag()
  local bag = getBag()
  if not bag then
    print("[WLB_TOKEN_ENGINE] ERROR: Bag not found: "..BAG_GUID)
    return
  end

  local collected = 0
  for _, obj in ipairs(getAllObjects()) do
    if obj and obj ~= bag and obj.hasTag then
      if obj.hasTag(TAG_STATUS_TOKEN) and (not obj.hasTag(TAG_PLAYER_TOKEN)) then
        pcall(function() if obj.unlock then obj.unlock() end end)
        pcall(function() bag.putObject(obj) end)
        collected = collected + 1
    end
  end
  end

  POOL, primed = {}, false
  print("[WLB_TOKEN_ENGINE] Collected status tokens to bag:", collected)
end

-- =========================
-- FAMILY: build ordered list for slots
-- =========================
local function buildOrderedFamilyTokens(color)
  local f = ensureFamily(color)
  local ordered = {}

  ordered[1] = findPlayerToken(color)

  local idx = 2
  if f.marriage then
    ordered[idx] = f.marriage
    idx = idx + 1
  end

  for _, kid in ipairs(f.kids) do
    if idx > 6 then break end
    ordered[idx] = kid
    idx = idx + 1
  end

  local compact = {}
  for i=1,6 do
    if ordered[i] then table.insert(compact, ordered[i]) end
  end
  return compact
end

-- =========================
-- FAMILY: place back to housing
-- =========================
local function placeFamilyNow(color)
  local f = ensureFamily(color)

  if f.housing.level == "L0" then
    local board = findPlayerBoard(color)
    if not board then dprint("No board for:", color); return end
    local slots = FAMILY_SLOTS_BOARD[color] and FAMILY_SLOTS_BOARD[color].L0
    if not slots then dprint("No L0 family slots for:", color); return end
    placeTokensSequential(board, buildOrderedFamilyTokens(color), slots, HOUSING_RETURN_DELAY)
    return
  end

  local estate = f.housing.estate or findEstateCardByLevel(f.housing.level)
  f.housing.estate = estate
  if not estate then return end

  local slots = FAMILY_SLOTS_CARD[f.housing.level]
  if not slots then dprint("No slots for:", f.housing.level); return end

  placeTokensSequential(estate, buildOrderedFamilyTokens(color), slots, HOUSING_RETURN_DELAY)
end

-- =========================
-- BOARD STATUSES: compact ordering in 6 slots
-- =========================
function TE_RefreshStatuses(color)
  local board = findPlayerBoard(color)
  if not board then dprint("No board for:", color); return end
  local slots = STATUS_SLOTS_BOARD[color] and STATUS_SLOTS_BOARD[color].L0
  if not slots then dprint("No STATUS slots for:", color); return end

  local s = ensureStatuses(color)
  local step = 0
  local slotWriteIdx = 0

  -- Compact placement in 6 slots, but stack multi-tokens in the SAME slot.
  for _, tag in ipairs(STATUS_ORDER) do
    local tok = s.active[tag]
    if tok then
      slotWriteIdx = slotWriteIdx + 1
      local slot = slots[slotWriteIdx]
      if not slot then break end

      if type(tok) == "table" then
        -- Multi-status: place ONLY the newest token to avoid re-placing others (re-place caused 2nd token to fly away)
        local n = 0
        for _, t in ipairs(tok) do if t then n = n + 1 end end
        if n == 1 then
          step = step + 1
          local t = tok[1]
          local delay = (step - 1) * STEP_DELAY
          Wait.time(function()
            safePlace(t, worldFromLocal(board, slot))
          end, delay)
        elseif n >= 2 then
          step = step + 1
          local newest = tok[n]
          local localPos = { x = slot.x, y = slot.y + ((n - 1) * STATUS_STACK_Y), z = slot.z }
          -- Place only newest token after a delay so first token(s) stay put (no re-place = no fly-away)
          local delay = (step - 1) * STEP_DELAY + STACK_EXTRA_DELAY
          Wait.time(function()
            safePlace(newest, worldFromLocal(board, localPos))
          end, delay)
        end
      else
        -- Single token status
        step = step + 1
        local delay = (step-1) * STEP_DELAY
        Wait.time(function()
          safePlace(tok, worldFromLocal(board, slot))
        end, delay)
      end
    end
  end
end

function TE_HasStatus(color, statusTag)
  -- Query if player has a specific status (checks internal state)
  if not color or not isSupportedColor(color) then
    dprint("TE_HasStatus: invalid color:", tostring(color))
    return false
  end
  local s = ensureStatuses(color)
  
  -- Check for multi-status (can be array) vs regular status (single token)
  local tok = s.active[statusTag]
  if not tok then return false end
  
  if MULTI_STATUS[statusTag] then
    -- Multi-status can be array - check if it has any tokens
    if type(tok) == "table" then
      return #tok > 0
    end
    -- Single token or non-array value means it exists
    return tok ~= nil
  else
    -- Regular status: single token means it exists
    return tok ~= nil
  end
end

function TE_AddStatus(color, statusTag)
  if not primed then print("[WLB_TOKEN_ENGINE] PRIME first."); return end
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_AddStatus: invalid color:", tostring(color))
    return
  end

  local s = ensureStatuses(color)
  
  -- Multi-status supports multiple tokens (array), other statuses are single token
  if MULTI_STATUS[statusTag] then
    -- Multi-status: allow multiple tokens
    local hadAlready = (s.active[statusTag] ~= nil)
    if not hadAlready then
      local activeCount = 0
      for _, _ in pairs(s.active) do activeCount = activeCount + 1 end
      if activeCount >= 8 then
        print("[WLB_TOKEN_ENGINE] ERROR: Max 8 statuses already active for "..tostring(color))
        return
      end
    end

    if not s.active[statusTag] then
      s.active[statusTag] = {}  -- Initialize as array
    elseif type(s.active[statusTag]) ~= "table" then
      -- Convert existing single token to array (backward compatibility)
      local oldTok = s.active[statusTag]
      s.active[statusTag] = {}
      if oldTok then
        table.insert(s.active[statusTag], oldTok)
      end
    end
    
    local tok = requestTokenByTag(statusTag)
    if not tok then return end
    table.insert(s.active[statusTag], tok)
    TE_RefreshStatuses(color)
  else
    -- Regular status: single token only
    if s.active[statusTag] then
      dprint("Status already active:", color, statusTag)
      TE_RefreshStatuses(color)
      return
    end

    local activeCount = 0
    for _, _ in pairs(s.active) do activeCount = activeCount + 1 end
    if activeCount >= 8 then
      print("[WLB_TOKEN_ENGINE] ERROR: Max 8 statuses already active for "..tostring(color))
      return
    end

    local tok = requestTokenByTag(statusTag)
    if not tok then return end
    s.active[statusTag] = tok
    TE_RefreshStatuses(color)
  end
end

function TE_RemoveStatus(color, statusTag)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_RemoveStatus: invalid color:", tostring(color))
    return
  end
  local s = ensureStatuses(color)
  local tok = s.active[statusTag]
  if not tok then
    dprint("Status not active:", color, statusTag)
    return
  end

  -- Multi-status supports multiple tokens (array), remove one
  if MULTI_STATUS[statusTag] and type(tok) == "table" and #tok > 0 then
    local removedTok = table.remove(tok, #tok)  -- Remove last token
    if removedTok then
      recycleStatusTokenToPool(statusTag, removedTok)
    end
    if #tok == 0 then
      s.active[statusTag] = nil  -- Clean up empty array
    end
  else
    -- Regular status: remove single token
    s.active[statusTag] = nil
    if type(tok) == "table" then
      -- Backward-compat: handle case where multi-status was stored as array unexpectedly
      local removedTok = table.remove(tok, #tok)
      if removedTok then
        recycleStatusTokenToPool(statusTag, removedTok)
      end
    else
      recycleStatusTokenToPool(statusTag, tok)
    end
  end
  TE_RefreshStatuses(color)
end

function TE_GetStatusCount(color, statusTag)
  if not color or not isSupportedColor(color) then return 0 end
  local s = ensureStatuses(color)
  local tok = s.active[statusTag]
  if not tok then return 0 end
  if type(tok) == "table" then return #tok end
  return 1
end

function TE_RemoveStatusCount(color, statusTag, count)
  if not color or not isSupportedColor(color) or not statusTag then return end
  count = math.max(0, math.floor(tonumber(count) or 0))
  if count == 0 then return end
  for _ = 1, count do
    if not TE_HasStatus(color, statusTag) then break end
    TE_RemoveStatus(color, statusTag)
  end
end

function TE_ClearStatuses(color)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_ClearStatuses: invalid color:", tostring(color))
    return
  end

  local s = ensureStatuses(color)
  for tag, tok in pairs(s.active) do
    -- Handle multi-status array or regular single token
    if MULTI_STATUS[tag] and type(tok) == "table" then
      -- Multi-status is an array - recycle all tokens
      for _, t in ipairs(tok) do
        recycleStatusTokenToPool(tag, t)
      end
    else
      -- Regular status: single token
      recycleStatusTokenToPool(tag, tok)
    end
  end

  s.active = {}
  TE_RefreshStatuses(color)
end

-- =========================
-- FAMILY: public API
-- =========================
function TE_AddMarriage(color)
  if not primed then print("[WLB_TOKEN_ENGINE] PRIME first."); return end
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_AddMarriage: invalid color:", tostring(color))
    return
  end

  local f = ensureFamily(color)
  if f.marriage then
    dprint("Marriage already active for", color)
    return
  end
  local tok = requestTokenByTag(TAG_MARRIAGE)
  if not tok then return end
  f.marriage = tok
  placeFamilyNow(color)
end

function TE_AddChild(color, sex)
  if not primed then print("[WLB_TOKEN_ENGINE] PRIME first."); return end
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_AddChild: invalid color:", tostring(color))
    return
  end

  local f = ensureFamily(color)

  local tag
  if sex == "BOY" then tag = TAG_CHILD_BOY
  elseif sex == "GIRL" then tag = TAG_CHILD_GIRL
  else
    tag = (math.random() < 0.5) and TAG_CHILD_BOY or TAG_CHILD_GIRL
  end

  local tok = requestTokenByTag(tag)
  if not tok then return end
  table.insert(f.kids, tok)
  placeFamilyNow(color)
end

function TE_RemoveOneChild(color)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_RemoveOneChild: invalid color:", tostring(color))
    return
  end
  local f = ensureFamily(color)
  if #f.kids == 0 then return end
  local tok = table.remove(f.kids, #f.kids)
  returnTokenToBag(tok) -- family still returns to bag (unchanged behavior)
  placeFamilyNow(color)
end

function TE_SetHousing(color, levelName, estateObjOrNil)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_SetHousing: invalid color:", tostring(color))
    return
  end
  local f = ensureFamily(color)
  f.housing.level = levelName
  f.housing.estate = estateObjOrNil
end

-- =========================
-- SAFE PARK / RETURN (family)
-- =========================
function TE_RemoveTokensToSafePark(color)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_RemoveTokensToSafePark: invalid color:", tostring(color))
    return
  end

  local board = findPlayerBoard(color)
  if not board then dprint("No board for:", color); return end
  local safeSlots = SAFE_PARK_BOARD[color]
  if not safeSlots then dprint("No SAFE PARK slots for:", color); return end

  local tokens = buildOrderedFamilyTokens(color)
  moveTokensToSafeParkSequential(board, tokens, safeSlots, STEP_DELAY)
end

function TE_ReturnTokensFromSafePark(color)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_ReturnTokensFromSafePark: invalid color:", tostring(color))
    return
  end
  placeFamilyNow(color)
end

-- =========================================================
-- ARG WRAPPERS for object.call compatibility (StatusCtrl/EventEngine)
-- IMPORTANT: now color is OPTIONAL -> auto-resolved to active turn when omitted
-- =========================================================

function TE_AddStatus_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local tag = args.statusTag or args.tag
  if not tag then
    print("[WLB_TOKEN_ENGINE] TE_AddStatus_ARGS missing tag")
    return false
  end
  TE_AddStatus(color, tag)
  return true
end

function TE_RemoveStatus_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local tag = args.statusTag or args.tag
  if not tag then
    print("[WLB_TOKEN_ENGINE] TE_RemoveStatus_ARGS missing tag")
    return false
  end
  TE_RemoveStatus(color, tag)
  return true
end

function TE_ClearStatuses_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  TE_ClearStatuses(color)
  return true
end

function TE_RefreshStatuses_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  TE_RefreshStatuses(color)
  return true
end

function TE_AddMarriage_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  TE_AddMarriage(color)
  return true
end

function TE_AddChild_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local sex = args.sex -- "BOY"/"GIRL"/nil
  TE_AddChild(color, sex)
  return true
end

function TE_HasStatus_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local statusTag = args.statusTag or args.tag
  return TE_HasStatus(color, statusTag)
end

function TE_GetStatusCount_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local statusTag = args.statusTag or args.tag
  return TE_GetStatusCount(color, statusTag) or 0
end

function TE_RemoveStatusCount_ARGS(args)
  args = args or {}
  local color = resolveTargetColor(args.color, nil)
  local statusTag = args.statusTag or args.tag
  local count = math.max(0, math.floor(tonumber(args.count) or 0))
  TE_RemoveStatusCount(color, statusTag, count)
  return true
end

-- =========================
-- UI HELPERS
-- =========================
local function uiBroadcast(pc, msg, col)
  col = col or {1,1,1}
  pcall(function()
    if pc and pc ~= "" and Player[pc] and Player[pc].seated then
      broadcastToColor(msg, pc, col)
    else
      broadcastToAll(msg, col)
    end
  end)
end

-- =========================
-- UI BUTTONS (AUTO TARGET)
--  - For UI clicks: default target = pc; if pc not a player color -> active turn
-- =========================
local function makeBtn(label, fn, x, z, w, h, fs, bg)
  self.createButton({
    label = label,
    click_function = fn,
    function_owner = self,
    position = {x,0.2,z},
    width = w, height = h,
    font_size = fs,
    color = bg or {0.2,0.2,0.2},
    font_color = {1,1,1}
  })
end

-- PRIME/COLLECT
function btnPrime(_,pc)   primeTokenPool(); uiBroadcast(pc,"PRIME started.",{0.7,1,0.7}) end
function btnCollect(_,pc) collectAllStatusTokensToBag(); uiBroadcast(pc,"COLLECT done (pool reset).",{1,0.8,0.6}) end

-- Family actions (auto target)
function btnAddMarr(_,pc)
  local c = resolveTargetColor(nil, pc)
  TE_AddMarriage(c)
  uiBroadcast(pc,"Marriage + ("..c..")",{0.8,0.9,1})
end

function btnAddKid(_,pc)
  local c = resolveTargetColor(nil, pc)
  TE_AddChild(c, nil)
  uiBroadcast(pc,"Child + ("..c..")",{0.8,0.9,1})
end

-- Housing (auto target)
function btnH0(_,pc) local c=resolveTargetColor(nil,pc); TE_SetHousing(c,"L0",nil); uiBroadcast(pc,"Housing("..c..")=L0",{1,1,0.6}) end
function btnH1(_,pc) local c=resolveTargetColor(nil,pc); TE_SetHousing(c,"L1",nil); uiBroadcast(pc,"Housing("..c..")=L1",{1,1,0.6}) end
function btnH2(_,pc) local c=resolveTargetColor(nil,pc); TE_SetHousing(c,"L2",nil); uiBroadcast(pc,"Housing("..c..")=L2",{1,1,0.6}) end
function btnH3(_,pc) local c=resolveTargetColor(nil,pc); TE_SetHousing(c,"L3",nil); uiBroadcast(pc,"Housing("..c..")=L3",{1,1,0.6}) end
function btnH4(_,pc) local c=resolveTargetColor(nil,pc); TE_SetHousing(c,"L4",nil); uiBroadcast(pc,"Housing("..c..")=L4",{1,1,0.6}) end

function btnRemoveTokens(_,pc)
  local c = resolveTargetColor(nil, pc)
  TE_RemoveTokensToSafePark(c)
  uiBroadcast(pc,"REMOVE TOKENS ("..c..")",{1,0.9,0.6})
end

function btnReturnTokens(_,pc)
  local c = resolveTargetColor(nil, pc)
  TE_ReturnTokensFromSafePark(c)
  uiBroadcast(pc,"RETURN TOKENS ("..c..")",{0.7,1,0.7})
end

-- Status add (auto target)
function btnAddGK(_,pc)   local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_GOODKARMA) end
function btnAddEXP(_,pc)  local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_EXPERIENCE) end
function btnAddDATE(_,pc) local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_DATING) end
function btnAddSICK(_,pc) local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_SICK) end
function btnAddWND(_,pc)  local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_WOUNDED) end
function btnAddADD(_,pc)  local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_ADDICTION) end
function btnAddVouchC(_,pc) local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_VOUCH_C) end
function btnAddVouchH(_,pc) local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_VOUCH_H) end
function btnAddVouchP(_,pc) local c=resolveTargetColor(nil,pc); TE_AddStatus(c, TAG_STATUS_VOUCH_P) end

-- Status remove (auto target)
function btnRemGK(_,pc)   local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_GOODKARMA) end
function btnRemEXP(_,pc)  local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_EXPERIENCE) end
function btnRemDATE(_,pc) local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_DATING) end
function btnRemSICK(_,pc) local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_SICK) end
function btnRemWND(_,pc)  local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_WOUNDED) end
function btnRemADD(_,pc)  local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_ADDICTION) end
function btnRemVouchC(_,pc) local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_VOUCH_C) end
function btnRemVouchH(_,pc) local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_VOUCH_H) end
function btnRemVouchP(_,pc) local c=resolveTargetColor(nil,pc); TE_RemoveStatus(c, TAG_STATUS_VOUCH_P) end
function btnClearStatuses(_,pc) local c=resolveTargetColor(nil,pc); TE_ClearStatuses(c) end

-- =========================
-- START GAME: place player tokens on L0 (slot 1) for active colors
-- =========================
function TE_PlacePlayerTokenToL0(color)
  if not color or not isSupportedColor(color) then
    print("[WLB_TOKEN_ENGINE] TE_PlacePlayerTokenToL0: invalid color:", tostring(color))
    return false
  end
  -- ensure housing is L0 (start apartment)
  TE_SetHousing(color, "L0", nil)
  -- place family arrangement; with no family, it places just PLAYER token in slot [1]
  placeFamilyNow(color)
  return true
end

function API_placePlayerTokens(args)
  args = args or {}
  local colors = args.colors

  if type(colors) ~= "table" or #colors == 0 then
    -- fallback: place for all supported colors (safe, ale jeśli wolisz tylko aktywnych, podawaj listę z TurnCtrl)
    colors = COLORS
  end

  for _, c in ipairs(colors) do
    TE_PlacePlayerTokenToL0(c)
  end

  return true
end


-- =========================
-- PUBLIC API (for TurnCtrl / EventCtrl)
-- =========================
function API_collect(args)
  collectAllStatusTokensToBag()
  return true
end

function API_prime(args)
  primeTokenPool()
  return true
end


-- =========================
-- LIFECYCLE
-- =========================
function onLoad()
  math.randomseed(os.time())

  cloneYellowToAll()
  for _,c in ipairs(COLORS) do
    ensureFamily(c)
    ensureStatuses(c)
  end

  -- Cache turn color if available
  local tc = getTurnColor()
  if tc then lastKnownTurnColor = tc end

  -- Row 0: PRIME / COLLECT (no color selector anymore)
  makeBtn("PRIME",   "btnPrime",   -0.85, -1.10, 1200, 220, 150, {0.1,0.35,0.1})
  makeBtn("COLLECT", "btnCollect",  0.85, -1.10, 1200, 220, 150, {0.45,0.1,0.1})

  -- Row 1: Family
  makeBtn("M+", "btnAddMarr", -0.75, -0.72, 580, 240, 170, {0.12,0.22,0.42})
  makeBtn("K+", "btnAddKid",   0.75, -0.72, 580, 240, 170, {0.12,0.22,0.42})

  -- Row 2 (Housing)
  local x = {-1.60,-0.80,0.00,0.80,1.60}
  local labels = {"H0","H1","H2","H3","H4"}
  local fns = {"btnH0","btnH1","btnH2","btnH3","btnH4"}
  for i=1,5 do
    makeBtn(labels[i], fns[i], x[i], -0.32, 360, 220, 140, {0.10,0.25,0.35})
  end

  -- Row 3 (Family move)
  makeBtn("REMOVE TOKENS", "btnRemoveTokens", -0.85, 0.10, 780, 260, 120, {0.35,0.25,0.05})
  makeBtn("RETURN TOKENS", "btnReturnTokens",  0.85, 0.10, 780, 260, 120, {0.05,0.30,0.25})

  -- Row 4 (Status add) -- 9 statuses
  local sx = {-1.70,-1.02,-0.34,0.34,1.02,1.70, 2.38, 3.06, 3.74}
  local sLabs = {"+GK","+EXP","+DATE","+SICK","+WND","+ADD","+VC","+VH","+VP"}
  local sFns  = {"btnAddGK","btnAddEXP","btnAddDATE","btnAddSICK","btnAddWND","btnAddADD","btnAddVouchC","btnAddVouchH","btnAddVouchP"}
  for i=1,9 do
    makeBtn(sLabs[i], sFns[i], sx[i], 0.55, 300, 200, 120, {0.20,0.20,0.20})
  end

  -- Row 5 (Status remove + clear) -- 9 statuses + CLEAR
  local rx = {-1.70,-1.02,-0.34,0.34,1.02,1.70, 2.38, 3.06, 3.74, 4.40}
  local rLabs = {"-GK","-EXP","-DATE","-SICK","-WND","-ADD","-VC","-VH","-VP","CLEAR"}
  local rFns  = {"btnRemGK","btnRemEXP","btnRemDATE","btnRemSICK","btnRemWND","btnRemADD","btnRemVouchC","btnRemVouchH","btnRemVouchP","btnClearStatuses"}
  for i=1,10 do
    local btnColor = (i==10) and {0.45,0.12,0.12} or {0.12,0.12,0.12}
    local btnWidth = (i==10) and 360 or 300
    makeBtn(rLabs[i], rFns[i], rx[i], 0.82, btnWidth, 200, 110, btnColor)
  end

  print("[WLB_TOKEN_ENGINE] Loaded v2.4.0 | AUTO TARGET (pc -> turn -> fallback="..tostring(lastKnownTurnColor)..")")
end
