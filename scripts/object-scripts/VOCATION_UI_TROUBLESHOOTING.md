# Vocation UI Troubleshooting Guide

## 1. XML Declaration Line

**Answer: It's OPTIONAL in TTS.**

- ✅ **You can remove it** - TTS works fine without `<?xml version="1.0" encoding="utf-8"?>`
- ✅ **If you keep it** - It MUST be the very first line with NO whitespace before it
- ❌ **If you get an error with it** - There's invisible whitespace before it (spaces, tabs, or line breaks)

**Recommendation:** Since you removed it and there's no error, **keep it removed**. It's not necessary.

## 2. UI Not Appearing - Diagnostic Steps

### Step 1: Test if UI is Loaded
In TTS, open the console (F5) and type:
```
/exec VocationsController.call("VOC_TestUI")
```

**Expected Results:**
- ✅ `"✅ UI system is working! Panels are accessible."` = UI is loaded correctly
- ❌ `"❌ UI system not available - XML not loaded in UI tab"` = XML not in UI tab
- ❌ `"❌ UI panel not found - Check XML panel IDs match"` = Panel IDs don't match

### Step 2: Check UI Tab
1. Open VocationsController object
2. Go to **UI tab** (not Script tab)
3. Verify the XML is there (should start with `<ui>` or `<?xml`)
4. Click **"Save & Apply"**

### Step 3: Check Console for Errors
1. Press **F5** to open console
2. Look for errors when vocation selection should start
3. Check for messages like:
   - `"ERROR: UI system not available"`
   - `"Failed to show vocation selection UI"`

## 3. Error After Science Points Allocation

The error might be because:
1. **Vocation selection is trying to start but UI isn't loaded**
2. **TurnController is calling a function that doesn't exist**
3. **There's a nil value error in the selection flow**

### To Debug:
1. **Check the exact error message** in the console (F5)
2. **Look for the line number** where it fails
3. **Check if `startVocationSelection()` is being called** - you should see a log message

### Common Issues:

#### Issue A: "UI system not available"
**Fix:** Make sure `VocationsUI.xml` (without XML declaration) is in the **UI tab** of VocationsController

#### Issue B: "VOC_StartSelection is nil"
**Fix:** Reload the VocationsController script (Script tab → Save & Apply)

#### Issue C: "Panel not found"
**Fix:** Check that panel IDs in XML match:
- `vocationSelectionPanel`
- `vocationSummaryPanel`
- `sciencePointsPanel`

## 4. Quick Test Procedure

1. **Start a new Adult game**
2. **Complete dice rolls**
3. **Allocate Science Points for all players**
4. **Watch console (F5)** for messages
5. **Expected:** Message "✅ All Science Points allocated. Starting vocation selection..."
6. **Expected:** UI should appear for first player

## 5. Manual UI Test

To manually trigger the UI (for testing):
```
/exec VocationsController.call("VOC_StartSelection", {color="Yellow"})
```

This should show the selection UI for Yellow player. If it doesn't, the UI isn't loaded.

## Summary

- **XML Declaration:** Optional - you can remove it ✅
- **UI Not Working:** Test with `VOC_TestUI()` function
- **Error After Science Points:** Check console for exact error message
- **Most Common Issue:** XML not in UI tab, or panel IDs don't match
