-- =========================================================
-- VOCATION SELECTION UI - OPTION A: Button Grid
-- Based on VOCATION_SELECTION_UI_ALTERNATIVE.md
-- =========================================================
-- This script implements Option A: Simple Button Grid
-- Layout: 2 columns × 3 rows on VocationsController tile
-- When a button is clicked, the vocation is assigned to the player
-- =========================================================

-- =========================================================
-- CONSTANTS
-- =========================================================
local COLORS = {"Yellow", "Blue", "Red", "Green"}

local VOC_PUBLIC_SERVANT = "PUBLIC_SERVANT"
local VOC_CELEBRITY = "CELEBRITY"
local VOC_SOCIAL_WORKER = "SOCIAL_WORKER"
local VOC_GANGSTER = "GANGSTER"
local VOC_ENTREPRENEUR = "ENTREPRENEUR"
local VOC_NGO_WORKER = "NGO_WORKER"

local ALL_VOCATIONS = {
  VOC_PUBLIC_SERVANT,
  VOC_CELEBRITY,
  VOC_SOCIAL_WORKER,
  VOC_GANGSTER,
  VOC_ENTREPRENEUR,
  VOC_NGO_WORKER,
}

-- Vocation display names
local VOCATION_NAMES = {
  [VOC_PUBLIC_SERVANT] = "Public Servant",
  [VOC_CELEBRITY] = "Celebrity",
  [VOC_SOCIAL_WORKER] = "Social Worker",
  [VOC_GANGSTER] = "Gangster",
  [VOC_ENTREPRENEUR] = "Entrepreneur",
  [VOC_NGO_WORKER] = "NGO Worker",
}

-- =========================================================
-- STATE MANAGEMENT
-- =========================================================
local selectionState = {
  activeColor = nil,  -- Which player is currently selecting
}

-- =========================================================
-- HELPER FUNCTIONS
-- =========================================================
local function normalizeColor(color)
  if not color then return nil end
  local c = string.gsub(tostring(color), "^%l", string.upper)
  for _, validColor in ipairs(COLORS) do
    if c == validColor then
      return validColor
    end
  end
  return nil
end

local function log(msg)
  print("[VOCATION_SELECTION_OPTION_A] " .. tostring(msg))
end

-- =========================================================
-- MAIN SELECTION UI FUNCTION
-- =========================================================
-- Shows button grid on VocationsController tile
-- Layout matches Option A from markdown:
--   [Public Servant]  [Celebrity]
--   [Social Worker]   [Gangster]
--   [Entrepreneur]    [NGO Worker]
function VOC_ShowSelectionUI(color)
  if not self or not self.clearButtons then
    log("Error: Cannot show buttons - self is invalid")
    return false
  end
  
  color = normalizeColor(color)
  if not color then
    log("Invalid color")
    return false
  end
  
  -- Clear existing buttons
  self.clearButtons()
  
  -- Set active selection state
  selectionState.activeColor = color
  
  log("Showing selection UI for " .. color)
  
  -- Title button (non-clickable)
  self.createButton({
    click_function = "noop",
    function_owner = self,
    label = "Choose Your Vocation",
    position = {0, 0.3, 1.2},
    width = 2000,
    height = 400,
    font_size = 200,
    color = {0.1, 0.1, 0.1, 1},
    font_color = {1, 1, 1, 1}
  })
  
  -- Vocation buttons in 2x3 grid layout (as per Option A)
  -- Positions match the markdown specification:
  -- Row 1: Public Servant (-1.2, 0.3, 0.3) | Celebrity (1.2, 0.3, 0.3)
  -- Row 2: Social Worker (-1.2, 0.3, -0.3) | Gangster (1.2, 0.3, -0.3)
  -- Row 3: Entrepreneur (-1.2, 0.3, -0.9) | NGO Worker (1.2, 0.3, -0.9)
  local vocations = {
    {id=VOC_PUBLIC_SERVANT, pos={-1.2, 0.3, 0.3}, func="VOC_SelectPublicServant"},
    {id=VOC_CELEBRITY, pos={1.2, 0.3, 0.3}, func="VOC_SelectCelebrity"},
    {id=VOC_SOCIAL_WORKER, pos={-1.2, 0.3, -0.3}, func="VOC_SelectSocialWorker"},
    {id=VOC_GANGSTER, pos={1.2, 0.3, -0.3}, func="VOC_SelectGangster"},
    {id=VOC_ENTREPRENEUR, pos={-1.2, 0.3, -0.9}, func="VOC_SelectEntrepreneur"},
    {id=VOC_NGO_WORKER, pos={1.2, 0.3, -0.9}, func="VOC_SelectNGOWorker"},
  }
  
  local buttonCount = 0
  
  for _, voc in ipairs(vocations) do
    -- Check if vocation is already taken
    local isTaken = false
    -- NOTE: This assumes state.vocations exists and tracks assigned vocations
    -- You may need to adjust this based on your actual state structure
    if state and state.vocations then
      for _, c in ipairs(COLORS) do
        if state.vocations[c] == voc.id then
          isTaken = true
          break
        end
      end
    end
    
    if not isTaken then
      local vocationName = VOCATION_NAMES[voc.id] or voc.id
      
      -- Create button for this vocation with specific click function
      self.createButton({
        click_function = voc.func,
        function_owner = self,
        label = vocationName,
        position = voc.pos,
        width = 1000,
        height = 400,
        font_size = 150,
        color = {0.2, 0.5, 1.0, 1},  -- Blue color
        font_color = {1, 1, 1, 1},
        tooltip = "Click to choose " .. vocationName
      })
      
      log("Created button for: " .. vocationName)
      buttonCount = buttonCount + 1
    else
      log("Skipping " .. (VOCATION_NAMES[voc.id] or voc.id) .. " - already taken")
    end
  end
  
  log("Created " .. buttonCount .. " vocation buttons")
  return true
end

-- =========================================================
-- INDIVIDUAL BUTTON CLICK HANDLERS
-- =========================================================
-- Each vocation has its own click handler for reliability
function VOC_SelectPublicServant(obj, color, alt_click)
  handleVocationButtonClick(VOC_PUBLIC_SERVANT, color)
end

function VOC_SelectCelebrity(obj, color, alt_click)
  handleVocationButtonClick(VOC_CELEBRITY, color)
end

function VOC_SelectSocialWorker(obj, color, alt_click)
  handleVocationButtonClick(VOC_SOCIAL_WORKER, color)
end

function VOC_SelectGangster(obj, color, alt_click)
  handleVocationButtonClick(VOC_GANGSTER, color)
end

function VOC_SelectEntrepreneur(obj, color, alt_click)
  handleVocationButtonClick(VOC_ENTREPRENEUR, color)
end

function VOC_SelectNGOWorker(obj, color, alt_click)
  handleVocationButtonClick(VOC_NGO_WORKER, color)
end

-- =========================================================
-- SHARED BUTTON CLICK HANDLER
-- =========================================================
-- Called by individual vocation button handlers
-- Assigns the vocation to the active player
local function handleVocationButtonClick(vocation, clickerColor)
  local selectingColor = selectionState.activeColor
  if not selectingColor then
    log("No active selection - button clicked out of turn")
    return
  end
  
  -- Verify it's the correct player clicking
  clickerColor = normalizeColor(clickerColor)
  if clickerColor ~= selectingColor then
    log("Wrong player clicked. Active: " .. tostring(selectingColor) .. ", Clicked: " .. tostring(clickerColor))
    broadcastToAll("Only " .. selectingColor .. " can choose a vocation right now.", {1, 0.5, 0.2})
    return
  end
  
  log("Vocation button clicked: " .. vocation .. " by " .. tostring(clickerColor))
  
  -- Assign vocation to player
  local success, err = assignVocationToPlayer(selectingColor, vocation)
  
  if success then
    -- Clean up selection UI
    VOC_CleanupSelection({color=selectingColor})
    
    local vocationName = VOCATION_NAMES[vocation] or vocation
    broadcastToAll(selectingColor .. " chose " .. vocationName, {0.3, 1, 0.3})
    log("Vocation assigned: " .. selectingColor .. " → " .. vocation)
    
    -- Notify TurnController (if exists)
    notifyVocationSelected(selectingColor, vocation)
  else
    local errMsg = err or "Unknown error"
    log("Failed to assign vocation: " .. errMsg)
    broadcastToAll(selectingColor .. ": Selection failed - " .. errMsg, {1, 0.5, 0.2})
  end
end

-- =========================================================
-- VOCATION ASSIGNMENT FUNCTION
-- =========================================================
-- Assigns a vocation to a player
-- Tries to use existing VOC_SetVocation if available, otherwise uses local implementation
function assignVocationToPlayer(color, vocation)
  color = normalizeColor(color)
  if not color then
    return false, "Invalid color"
  end
  
  if not vocation then
    return false, "Vocation not specified"
  end
  
  -- Try to use existing VOC_SetVocation function if available (when integrated)
  if VOC_SetVocation and type(VOC_SetVocation) == "function" then
    log("Using existing VOC_SetVocation function")
    return VOC_SetVocation({color = color, vocation = vocation})
  end
  
  -- Fallback: Local implementation
  log("Using local vocation assignment")
  
  -- Validate vocation
  local valid = false
  for _, v in ipairs(ALL_VOCATIONS) do
    if v == vocation then
      valid = true
      break
    end
  end
  
  if not valid then
    return false, "Invalid vocation"
  end
  
  -- Check exclusivity (can't choose if already taken)
  if state and state.vocations then
    for _, c in ipairs(COLORS) do
      if c ~= color and state.vocations[c] == vocation then
        return false, "Vocation already taken"
      end
    end
  end
  
  -- Initialize state if needed
  if not state then
    state = {}
  end
  if not state.vocations then
    state.vocations = {}
  end
  if not state.levels then
    state.levels = {}
  end
  
  -- Set vocation
  state.vocations[color] = vocation
  state.levels[color] = 1  -- Start at Level 1
  
  -- Save state (if saveState function exists)
  if saveState and type(saveState) == "function" then
    saveState()
  end
  
  log("Vocation set: " .. color .. " → " .. vocation)
  return true
end

-- =========================================================
-- CLEANUP FUNCTION
-- =========================================================
-- Cleans up the selection UI
function VOC_CleanupSelection(params)
  local color = normalizeColor(params and params.color)
  
  -- Clear buttons from controller
  if self and self.clearButtons then
    pcall(function() self.clearButtons() end)
    log("Cleared selection buttons")
  end
  
  -- Reset selection state
  selectionState.activeColor = nil
  
  log("Cleaned up selection for " .. tostring(color))
  return true
end

-- =========================================================
-- NOTIFICATION FUNCTION
-- =========================================================
-- Notifies TurnController that a vocation was selected
function notifyVocationSelected(color, vocation)
  -- Find TurnController
  local turnCtrl = nil
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag then
      if obj.hasTag("WLB_TURN_CTRL") or obj.hasTag("WLB_TURN_CONTROLLER") then
        turnCtrl = obj
        break
      end
    end
  end
  
  if turnCtrl and turnCtrl.call then
    pcall(function()
      turnCtrl.call("VOC_OnVocationSelected", {color = color, vocation = vocation})
    end)
    log("Notified TurnController of vocation selection")
  else
    log("TurnController not found - skipping notification")
  end
end

-- =========================================================
-- NO-OP FUNCTION
-- =========================================================
-- Used for non-clickable title button
function noop() end

-- =========================================================
-- INTEGRATION NOTES
-- =========================================================
-- To integrate this script with VocationsController.lua:
--
-- 1. Copy the functions into VocationsController.lua
-- 2. Replace assignVocationToPlayer() with calls to existing VOC_SetVocation()
-- 3. Ensure state management is shared between scripts
-- 4. Call VOC_ShowSelectionUI(color) from VOC_StartSelection() instead of showSelectionButtons()
-- 5. Make sure VOC_CleanupSelection() is called after selection completes
--
-- Example integration in VOC_StartSelection():
--   -- Replace showSelectionButtons(color) with:
--   VOC_ShowSelectionUI(color)
--
-- The button click handler VOC_ButtonSelectVocation will automatically
-- assign the vocation when a button is clicked.
