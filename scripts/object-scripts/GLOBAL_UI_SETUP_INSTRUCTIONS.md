# Global UI Setup Instructions

## Overview
This document explains how to switch from Object UI to Global UI for the Vocation Selection system. Global UI provides screen-fixed positioning that doesn't move with objects.

## Files Created

1. **`VocationsUI_Global.xml`** - The UI XML file for Global UI
2. **`Global_UI_Callbacks.lua`** - Callback routing functions for Global script
3. **`VocationsController.lua`** - Updated to use Global UI (UI. instead of self.UI.)

## Setup Steps

### Step 1: Add UI XML to Global UI Tab

1. Open Tabletop Simulator
2. Click on **Global** in the scripting window (or press F12)
3. Click on the **UI** tab
4. **Clear all existing content** (CTRL+A, then Delete)
5. Open the file `VocationsUI_Global.xml`
6. **Copy the entire contents** (CTRL+A, CTRL+C)
7. **Paste into the Global UI tab** (CTRL+V)
8. Click **Save & Apply**

### Step 2: Add Callback Functions to Global Script

1. In the Global scripting window, go to the **Script** tab (not UI tab)
2. **Add the following code** at the end of your Global script (or create a new Global script if you don't have one):

```lua
-- =========================================================
-- GLOBAL UI CALLBACKS FOR VOCATION SELECTION
-- Routes Global UI callbacks to VocationsController
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
```

3. Click **Save & Apply**

### Step 3: Update VocationsController

The `VocationsController.lua` file has already been updated to use Global UI. Make sure you have the latest version that uses `UI.` instead of `self.UI.`.

### Step 4: Remove Old Object UI (Optional)

If you previously had the XML in VocationsController's UI tab, you can now remove it:
1. Select the VocationsController object
2. Go to its **UI** tab
3. Clear all content (CTRL+A, Delete)
4. Click **Save & Apply**

## Testing

1. Load your game in TTS
2. The UI should now be screen-fixed (doesn't move when you move the VocationsController object)
3. Test the vocation selection by triggering `VOC_StartSelection` or clicking the "TEST UI" button on VocationsController

## Key Differences: Object UI vs Global UI

| Feature | Object UI | Global UI |
|---------|-----------|-----------|
| **Position** | Relative to object | Screen-fixed |
| **Moves with object** | Yes | No |
| **XML Location** | Object's UI tab | Global → UI tab |
| **Lua API** | `self.UI.*` | `UI.*` |
| **Callbacks** | In object script | In Global script (routed to object) |

## Troubleshooting

### UI doesn't appear
- Check that `VocationsUI_Global.xml` is in Global → UI tab
- Verify the XML has no syntax errors
- Check console for error messages

### Callbacks don't work
- Ensure `Global_UI_Callbacks.lua` code is in Global script
- Verify VocationsController has tag `WLB_VOCATIONS_CTRL`
- Check console for "VocationsController not found" errors

### UI still moves with object
- Make sure you're using Global UI, not Object UI
- Verify you pasted XML into Global → UI tab, not object's UI tab
