-- =========================================================
-- QUICK TEST GAME STARTER
-- Attach this script to a separate tile for fast game setup (testing).
-- Flow: Start new game (always Adult) → How many players? (2/3/4) → Each player picks vocation (6 options).
-- No dice roll, no delegate, no science points. Then hands off to TurnController to run the game.
-- =========================================================

local DEBUG = true
local TAG_TURN_CTRL = "WLB_TURN_CTRL"
local TAG_VOCATIONS_CTRL = "WLB_VOCATIONS_CTRL"
local VOC_CTRL_GUID = "37f7a7"  -- Match TurnController / Global

local DEFAULT_COLORS = {"Yellow", "Blue", "Red", "Green"}

-- Six original vocations (display name -> internal name for VocationsController)
local VOCATIONS = {
  { label = "Gangster",       vocation = "GANGSTER" },
  { label = "Social Worker", vocation = "SOCIAL_WORKER" },
  { label = "Public Servant", vocation = "PUBLIC_SERVANT" },
  { label = "NGO Worker",     vocation = "NGO_WORKER" },
  { label = "Entrepreneur",   vocation = "ENTREPRENEUR" },
  { label = "Celebrity",     vocation = "CELEBRITY" },
}

local UIY = 0.25
local BTN_W = 1800
local BTN_H = 400
local BTN_FS = 180

local state = {
  step = "HOME",       -- HOME | PLAYERS | VOCATION
  playersN = 4,
  colors = {},
  vocationIndex = 1,   -- which player is choosing (1..playersN)
}

local function log(msg)
  if DEBUG then print("[QUICK START] " .. tostring(msg)) end
end

local function findOneWithTag(tag)
  if not tag or tag == "" then return nil end
  for _, o in ipairs(getAllObjects()) do
    if o and o.hasTag and o.hasTag(tag) then return o end
  end
  return nil
end

local function getTurnController()
  return findOneWithTag(TAG_TURN_CTRL) or findOneWithTag("WLB_TURN_CONTROLLER")
end

local function getVocationsController()
  local o = getObjectFromGUID(VOC_CTRL_GUID)
  if o then return o end
  return findOneWithTag(TAG_VOCATIONS_CTRL)
end

local function vocationsCall(fnName, params)
  local voc = getVocationsController()
  if not voc or not voc.call then
    log("VocationsController not found or no call")
    return false, "VocationsController not found"
  end
  local ok, ret = pcall(function() return voc.call(fnName, params or {}) end)
  return ok, ret
end

local function clampPlayers(n)
  n = tonumber(n) or 4
  if n < 2 then n = 2 elseif n > 4 then n = 4 end
  return n
end

-- Reset state and show HOME
local function reset()
  state.step = "HOME"
  state.playersN = 4
  state.colors = {}
  state.vocationIndex = 1
  drawUI()
end

-- Call TurnController to run the game (vocations already set by this script)
local function runQuickStartGame()
  local turnCtrl = getTurnController()
  if not turnCtrl or not turnCtrl.call then
    broadcastToAll("❌ Turn Controller not found (tag " .. TAG_TURN_CTRL .. ").", {1, 0.3, 0.3})
    return
  end
  local params = {
    playersN = state.playersN,
    finalOrder = state.colors,
  }
  local ok, err = pcall(function() return turnCtrl.call("API_QuickStartGame", params) end)
  if not ok or err == false then
    broadcastToAll("❌ Quick start failed: " .. tostring(err), {1, 0.3, 0.3})
    log("API_QuickStartGame error: " .. tostring(err))
    return
  end
  broadcastToAll("✅ Game started (Adult, quick test).", {0.5, 1, 0.5})
  reset()
end

local function onVocationChosen(vocationKey)
  local color = state.colors[state.vocationIndex]
  if not color then return end
  local ok, err = vocationsCall("VOC_SetVocation", { color = color, vocation = vocationKey })
  if not ok then
    broadcastToAll("❌ Set vocation failed: " .. tostring(err), {1, 0.3, 0.3})
    return
  end
  state.vocationIndex = state.vocationIndex + 1
  if state.vocationIndex > state.playersN then
    runQuickStartGame()
  else
    drawUI()
  end
end

function drawUI()
  self.clearButtons()

  if state.step == "HOME" then
    self.createButton({
      label = "START NEW GAME\n(Adult, quick test)",
      click_function = "ui_startNewGame",
      function_owner = self,
      position = {0, UIY, 0},
      width = BTN_W, height = BTN_H, font_size = BTN_FS,
      tooltip = "Skip dice and science — set players and vocations, then start.",
    })
    return
  end

  if state.step == "PLAYERS" then
    self.createButton({ label = "How many players?", click_function = "noop", function_owner = self, position = {0, UIY, 0.9}, width = BTN_W, height = 320, font_size = 160, tooltip = "" })
    self.createButton({ label = "2 PLAYERS", click_function = "ui_players", function_owner = self, position = {0, UIY, 0.35}, width = BTN_W, height = BTN_H, font_size = BTN_FS, tooltip = "Yellow, Blue" })
    self.createButton({ label = "3 PLAYERS", click_function = "ui_players3", function_owner = self, position = {0, UIY, -0.25}, width = BTN_W, height = BTN_H, font_size = BTN_FS, tooltip = "Yellow, Blue, Red" })
    self.createButton({ label = "4 PLAYERS", click_function = "ui_players4", function_owner = self, position = {0, UIY, -0.85}, width = BTN_W, height = BTN_H, font_size = BTN_FS, tooltip = "Yellow, Blue, Red, Green" })
    return
  end

  if state.step == "VOCATION" then
    local color = state.colors[state.vocationIndex]
    if not color then
      reset()
      return
    end
    self.createButton({
      label = state.vocationIndex .. ") " .. color .. " — choose vocation",
      click_function = "noop",
      function_owner = self,
      position = {0, UIY, 1.0},
      width = BTN_W,
      height = 320,
      font_size = 140,
      tooltip = "",
    })
    local z = 0.5
    for i, v in ipairs(VOCATIONS) do
      local fn = "ui_voc_" .. i
      _G[fn] = (function(vocKey)
        return function() onVocationChosen(vocKey) end
      end)(v.vocation)
      self.createButton({
        label = v.label,
        click_function = fn,
        function_owner = self,
        position = {0, UIY, z},
        width = BTN_W,
        height = 360,
        font_size = 160,
        tooltip = v.label,
      })
      z = z - 0.55
    end
    return
  end
end

function noop() end

function ui_startNewGame()
  state.step = "PLAYERS"
  state.colors = {}
  state.vocationIndex = 1
  drawUI()
end

function ui_players()  setPlayers(2) end
function ui_players3() setPlayers(3) end
function ui_players4() setPlayers(4) end

function setPlayers(n)
  n = clampPlayers(n)
  state.playersN = n
  state.colors = {}
  for i = 1, n do
    state.colors[i] = DEFAULT_COLORS[i]
  end
  state.vocationIndex = 1
  state.step = "VOCATION"
  vocationsCall("VOC_ResetForNewGame", {})
  broadcastToAll("Quick start: " .. tostring(n) .. " players. Choose vocations in order.", {0.7, 1, 0.7})
  drawUI()
end

function onLoad()
  drawUI()
end
