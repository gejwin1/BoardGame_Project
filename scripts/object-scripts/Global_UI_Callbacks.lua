-- =========================================================
-- GLOBAL UI CALLBACKS FOR VOCATION SELECTION
-- This code should be added to your Global script
-- It routes Global UI callbacks to VocationsController
-- =========================================================

-- Helper function to find VocationsController
local function findVocationsController()
  local allObjects = getAllObjects()
  for _, obj in ipairs(allObjects) do
    if obj and obj.hasTag and obj.hasTag("WLB_VOCATIONS_CTRL") then
      return obj
    end
  end
  return nil
end

-- UI Callback: Vocation button clicked (from selection screen)
-- This is called by Global UI when a vocation button is clicked
function UI_SelectVocation(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_SelectVocation", player, value, id)
    end)
  else
    print("[Global] ERROR: VocationsController not found!")
  end
end

-- UI Callback: Confirm vocation selection
function UI_ConfirmVocation(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_ConfirmVocation", player, value, id)
    end)
  else
    print("[Global] ERROR: VocationsController not found!")
  end
end

-- UI Callback: Back to selection screen
function UI_BackToSelection(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_BackToSelection", player, value, id)
    end)
  else
    print("[Global] ERROR: VocationsController not found!")
  end
end

-- UI Callback: Science Points allocation (for future use)
function UI_AllocScience(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_AllocScience", player, value, id)
    end)
  else
    print("[Global] ERROR: VocationsController not found!")
  end
end

-- UI Callback: Continue to vocation selection (for future use)
function UI_ContinueToVocation(player, value, id)
  local vocCtrl = findVocationsController()
  if vocCtrl and vocCtrl.call then
    pcall(function()
      vocCtrl.call("UI_ContinueToVocation", player, value, id)
    end)
  else
    print("[Global] ERROR: VocationsController not found!")
  end
end
