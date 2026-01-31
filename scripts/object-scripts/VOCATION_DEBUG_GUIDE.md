# VocationsController Debug Guide

## Debug Buttons

After loading the VocationsController, you'll see 4 debug buttons on the object:

1. **TEST SELECTION** - Tests starting vocation selection
2. **TEST SUMMARY** - Tests showing summary panel directly
3. **TEST CALLBACK** - Tests callback routing from Global to Controller
4. **FULL TEST** - Tests complete flow: start → click → summary

## How to Use Debug Buttons

### Step 1: Load the Script
- Copy updated `VocationsController.lua` to VocationsController object
- The debug buttons will appear automatically

### Step 2: Test Individual Components

#### Test Selection Panel
1. Click **TEST SELECTION** button
2. Should see: Selection panel with 6 vocation images
3. Check logs for: `✅ Selection started successfully`

#### Test Summary Panel Directly
1. Click **TEST SUMMARY** button
2. Should see: Summary panel with GANGSTER vocation details
3. Check logs for: `✅ Summary panel shown successfully`

#### Test Callback Routing
1. Click **TEST CALLBACK** button
2. This simulates what happens when you click a vocation card
3. Check logs for: Full callback flow and summary panel activation

#### Full Flow Test
1. Click **FULL TEST** button
2. This tests: Start selection → Click vocation → Show summary
3. Should see: Summary panel appear automatically
4. Check logs for: `✅ Full test PASSED!`

## Troubleshooting

### Problem: Buttons don't appear
**Solution:** 
- Check that `self.createButton` is available
- Check logs for: `✅ Debug buttons created`

### Problem: TEST SUMMARY works but clicking cards doesn't
**Solution:**
- This means `showSummaryUI()` works, but callback routing is broken
- Use **TEST CALLBACK** to diagnose
- Check logs for: `=== UI_SelectVocation CALLED IN VOCATIONSCONTROLLER ===`

### Problem: Images are colored/tinted
**Solution:**
- Fixed! Code no longer sets `color` attribute on buttons with images
- Uses `opacity` instead for disabled state
- If still seeing colors, check that XML doesn't have color attributes on image buttons

### Problem: Summary panel doesn't appear
**Check these in order:**

1. **Is UI XML loaded?**
   - Check logs: `✅ UI Panel 'vocationSummaryPanel' found`
   - If not: Copy `VocationsUI_Global.xml` to Global → UI tab

2. **Is callback being called?**
   - Check logs: `=== UI_SelectVocation CALLED IN VOCATIONSCONTROLLER ===`
   - If not: Check Global script routing

3. **Is color being passed correctly?**
   - Check logs: `player/color: Green` (should be string, not nil)
   - If nil: Problem with Global → Controller argument passing

4. **Is showSummaryUI being called?**
   - Check logs: `Calling showSummaryUI for Green -> GANGSTER`
   - If not: Check validation logic (activeColor, etc.)

5. **Is pcall failing?**
   - Check logs: `ERROR: showSummaryUI pcall failed: ...`
   - This will show exact error (missing panel, wrong attribute, etc.)

## Expected Log Flow

When clicking a vocation card, you should see:

```
[WLB] UI_SelectVocation CALLED: player=Green, value=-1, id=btnGangster
[WLB] UI_SelectVocation: Successfully routed to VocationsController (color-only)
[VOC_CTRL] === UI_SelectVocation CALLED IN VOCATIONSCONTROLLER ===
[VOC_CTRL] player/color: Green
[VOC_CTRL] player type: string
[VOC_CTRL] id: btnGangster
[VOC_CTRL] Normalized color: Green
[VOC_CTRL] Mapped to vocation: GANGSTER
[VOC_CTRL] Calling showSummaryUI for Green -> GANGSTER
[VOC_CTRL] === showSummaryUI CALLED ===
[VOC_CTRL] showSummaryUI: Panel exists, current active state: false
[VOC_CTRL] showSummaryUI: Overlay set to active
[VOC_CTRL] showSummaryUI: Selection panel set to inactive
[VOC_CTRL] showSummaryUI: Summary panel set to active
[VOC_CTRL] ✅ Summary panel is ACTIVE - should be visible now!
```

## Manual Testing Commands

You can also test via console/chat:

```lua
-- Start selection for Green player
VOC_StartSelection({color="Green"})

-- Test showing summary directly
-- (Call showSummaryUI internally, or use TEST SUMMARY button)

-- Check UI state
-- (Use TEST UI button or check logs)
```

## Image Coloring Fix

**Problem:** Images appeared with colored tints/shades

**Root Cause:** Code was setting `color` attribute on buttons with images, which tints the image

**Fix Applied:**
- Removed `UI.setAttribute(btnId, "color", ...)` for image buttons
- Use `opacity` attribute instead for disabled state
- Images now display with natural colors

**If still seeing colors:**
- Check XML doesn't have `color` attribute on buttons with `image` attribute
- Verify Lua code isn't setting colors (should use opacity only)

## Next Steps

1. **Test with debug buttons** - Use all 4 buttons to isolate the problem
2. **Check logs** - Compare with expected log flow above
3. **Report findings** - Tell me which button works and which doesn't
4. **Check specific error** - If pcall fails, the error message will tell us exactly what's wrong
