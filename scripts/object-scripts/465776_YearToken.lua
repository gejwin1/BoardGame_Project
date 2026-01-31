-- =========================
-- TokenYear (Round Tracker) v3.0 - NO UI + NO LABEL
-- Token GUID: 465776
-- Tag: WLB_YEAR
-- Only:
-- - movement by localPositions[1..13]
-- - currentRound (+ currentColor tint)
-- - External API:
--   getRound, setRound, nextRound, prevRound,
--   resetToYouth, resetToAdult,
--   setColor, getColor
-- - No buttons, no label button, clears object name
-- =========================

local BOARD_GUID = "4aa064"
local MAX_ROUND = 13
local Y_OFFSET = 0.35

-- state
currentRound = 1
currentColor = "Yellow"   -- persisted tint (Yellow/Blue/Red/Green/White)

-- local positions relative to board: [1..13] = {lx, ly, lz}
local localPositions = {}

-- ===== Helpers =====
local function getBoard()
  local b = getObjectFromGUID(BOARD_GUID)
  if not b then
    broadcastToAll("❌ TokenYear: nie znaleziono CalendarBoard. Sprawdź BOARD_GUID.", {1,0.3,0.3})
    return nil
  end
  return b
end

local function clampRound(r)
  r = tonumber(r) or 1
  if r < 1 then return 1 end
  if r > MAX_ROUND then return MAX_ROUND end
  return r
end

local function tintForColor(color)
  color = tostring(color or ""):lower()
  if color == "yellow" then return {1, 0.95, 0.2} end
  if color == "blue"   then return {0.25, 0.55, 1} end
  if color == "red"    then return {1, 0.25, 0.25} end
  if color == "green"  then return {0.25, 1, 0.35} end
  if color == "white"  then return {1, 1, 1} end
  return {1, 1, 1}
end

local function applyTint()
  pcall(function()
    self.setColorTint(tintForColor(currentColor))
  end)
end

-- ===== Persist =====
function onSave()
  return JSON.encode({
    currentRound = currentRound,
    currentColor = currentColor,
    localPositions = localPositions
  })
end

function onLoad(saved)
  -- no buttons / no UI
  pcall(function() self.clearButtons() end)

  -- load state
  if saved and saved ~= "" then
    local ok, data = pcall(function() return JSON.decode(saved) end)
    if ok and data then
      currentRound = data.currentRound or 1
      currentColor = data.currentColor or "Yellow"
      localPositions = data.localPositions or {}
    end
  end

  -- remove any visible "name" clutter
  pcall(function() self.setName("") end)
  pcall(function() self.setDescription("") end)

  -- anti-sink
  local p = self.getPosition()
  self.setPosition({p.x, p.y + Y_OFFSET, p.z})

  applyTint()
  moveToRound(currentRound, true)
end

-- ===== Movement =====
function moveToRound(r, instant)
  local board = getBoard()
  if not board then return end

  local lp = localPositions[r]
  if not lp then
    broadcastToAll("⚠️ TokenYear: no saved position for round "..tostring(r)..".", {1,0.8,0.2})
    return
  end

  local localVec = Vector(lp[1], lp[2], lp[3])
  local worldTarget = board.positionToWorld(localVec)

  if instant then
    self.setPosition(worldTarget)
  else
    self.setPositionSmooth(worldTarget, false, true)
  end

  applyTint()
end

-- ===== External API =====
function getRound()
  return currentRound
end

function setRound(params)
  local r = params
  if type(params) == "table" then
    r = params.round or params.r or params[1]
  end
  if type(r) ~= "number" then r = tonumber(r) end
  if not r then return end
  currentRound = clampRound(math.floor(r + 0.5))
  moveToRound(currentRound, false)
end

function nextRound()
  currentRound = clampRound(currentRound + 1)
  moveToRound(currentRound, false)
end

function prevRound()
  currentRound = clampRound(currentRound - 1)
  moveToRound(currentRound, false)
end

function resetToYouth()
  setRound({round = 1})
end

function resetToAdult()
  setRound({round = 6})
end

function setColor(params)
  local c = params
  if type(params) == "table" then
    c = params.color or params.c or params[1]
  end
  if type(c) ~= "string" or c == "" then return end
  currentColor = c
  applyTint()
end

function getColor()
  return currentColor
end

-- Backward-compat safety (if something still calls setLabel)
function setLabel(_) end
