# Vocation UI Setup Instructions for Tabletop Simulator

## Overview
The UI XML file needs to be attached to the **VocationsController** object in TTS. This is where all the UI handler functions (`UI_SelectVocation`, `UI_ConfirmVocation`, etc.) are defined.

## Step-by-Step Instructions

### 1. Find the VocationsController Object
- In your TTS game, locate the object that has the **`VocationsController.lua`** script attached to it
- This object should have the tag **`WLB_VOCATIONS_CTRL`**
- If you're not sure which object it is, you can search for objects with that tag

### 2. Open the Object's Scripting Window
- Right-click on the VocationsController object
- Select **"Scripting"** from the context menu
- This opens the scripting window with two tabs: **"Script"** and **"UI"**

### 3. Attach the UI XML File
- Click on the **"UI"** tab in the scripting window
- You'll see a text area for UI XML code
- Open the file **`VocationsUI.xml`** (the combined UI file)
- **Copy the entire contents** of `VocationsUI.xml`
- **Paste it into the UI tab** of the VocationsController object
- Click **"Save & Apply"** or **"Apply"** to save the changes

### 4. Verify the Setup
- The UI tab should now contain the XML code with three panels:
  - `vocationSelectionPanel` (selection screen)
  - `vocationSummaryPanel` (summary screen)
  - `sciencePointsPanel` (allocation screen - for future use)
- All panels start with `visibility="false"` (hidden by default)
- The Lua script will show/hide them as needed

## Important Notes

### ✅ What You Need:
- **One file**: `VocationsUI.xml` (the combined file)
- **One object**: The VocationsController object
- **One location**: The UI tab of that object's scripting window

### ❌ What You DON'T Need:
- You do NOT need to attach UI XML to multiple objects
- You do NOT need to attach it to Global script
- You do NOT need the separate XML files (`VocationSelectionUI.xml`, `VocationSummaryUI.xml`, etc.) - those were just for organization

### How It Works:
1. The **Lua script** (`VocationsController.lua`) contains the handler functions
2. The **UI XML** (`VocationsUI.xml`) defines the visual panels and buttons
3. When buttons are clicked, TTS calls the handler functions in the Lua script
4. The Lua script controls panel visibility using `UI.setAttribute("panelId", "visibility", "true/false")`

## Testing

After setup, test the flow:
1. Start an Adult mode game
2. Complete dice rolls for turn order
3. Allocate Science Points (existing flow)
4. When all players finish, the vocation selection UI should appear automatically
5. Click a vocation button → Summary should appear
6. Click "Confirm" → Vocation is set, next player's turn

## Troubleshooting

### UI doesn't appear:
- Check that `VocationsUI.xml` is pasted in the UI tab
- Verify the VocationsController object has the Lua script attached
- Check the TTS console for errors (F5 to open)

### Buttons don't work:
- Verify the button `onClick` attributes match the function names in Lua
- Check that functions are defined as global (not `local`) in the Lua script

### Panels overlap or look wrong:
- All panels are positioned independently
- Only one panel should be visible at a time (controlled by Lua)
- If multiple panels show, check the `visibility` attributes

## File Structure Summary

```
VocationsController Object (in TTS)
├── Script Tab
│   └── VocationsController.lua (contains UI handlers)
└── UI Tab
    └── VocationsUI.xml (contains all UI panels)
```

That's it! One object, two tabs, everything connected.
