# How to Test Vocation Selection (Option A Button Grid)

This guide explains how to test the Option A vocation selection feature (button grid on the VocationsController tile).

---

## Quick test (Option A button grid)

**Option A runs when the on-screen UI (Global XML) is not available.** So you can test it in either of these ways:

### Method 1: Use the debug button (recommended)

1. **Load the game** in Tabletop Simulator and place the **VocationsController** object (the one that has the vocation script).
2. **Find the debug buttons** on the VocationsController. You should see four buttons: **TEST SELECTION**, **TEST SUMMARY**, **TEST CALLBACK**, **FULL TEST**.
3. **Force Option A** by making sure the Global UI is not used:
   - Either do **not** add `VocationsUI_Global.xml` to the Global object’s UI tab, or
   - In the script, the code uses `if UI then` for the screen UI; if `UI` is nil (no Global UI), it falls back to Option A.
4. **Click "TEST SELECTION"**.
   - The clicker’s color becomes the selecting player (e.g. if Green clicks, Green is the selector).
   - The six vocation buttons appear on the controller in the Option A layout (2×3 grid):  
     **Public Servant | Celebrity**  
     **Social Worker | Gangster**  
     **Entrepreneur | NGO Worker**
5. **As the same color that clicked TEST SELECTION**, click one of the six vocation buttons.
   - That vocation is assigned to that player.
   - You should see a broadcast like: `Green chose Public Servant`.
   - Buttons are cleared and selection ends.

**Important:** Only the **player whose color started the selection** can successfully choose a vocation. If another color clicks a vocation button, they see: *"Only [Color] can choose a vocation right now."*

---

### Method 2: Call from the Object Lua console

1. Right‑click the **VocationsController** object → **Scripting** → **Lua** (or use the object’s script editor).
2. Run:
   ```lua
   VOC_StartSelection({color = "Green"})
   ```
   (Use `"Yellow"`, `"Blue"`, `"Red"`, or `"Green"` as needed.)
3. The Option A grid appears **if** the Global UI is not active (same as Method 1).
4. The **same player color** you passed (e.g. Green) must click one of the six vocation buttons on the controller to assign.

---

### Method 3: In-game flow (TurnController)

During the **Adult phase**, the TurnController runs vocation selection in Science Points order:

1. When it’s a player’s turn to choose, it calls `VOC_StartSelection({color = currentColor, points = pts})`.
2. If the Global UI is not available, **Option A** runs: the 2×3 button grid appears on the VocationsController.
3. That player clicks a vocation button on the controller to assign.

So you can also test by playing into the Adult phase and letting the TurnController start selection; again, Option A is used when there is no Global UI.

---

## What to check

| Step | What to verify |
|------|----------------|
| Start selection | Message: *"Choose your vocation! Click a button on the Vocations Controller."* (or similar). |
| Grid appears | Title "Choose Your Vocation" and 6 vocation buttons in 2 columns × 3 rows. |
| Taken vocations | If you run selection again for another player, vocations already chosen by others should **not** show (or should be disabled). |
| Wrong player | Another color clicks a button → message that only [correct color] can choose. |
| Correct player | Correct color clicks a button → vocation is set, broadcast e.g. *"Green chose Entrepreneur"*, buttons disappear. |
| After assign | Player has that vocation (e.g. Level 1 tile placed, state updated). |

---

## If Option A doesn’t appear

- **Screen UI instead of buttons:** The game is using the Global UI (`UI` is set). To test Option A, ensure the Global object does **not** have the vocation UI XML in its UI tab (or that the script path that sets `UI` is not active).
- **No buttons at all:** Check that the script on the **object** is the one that contains `VOC_ShowSelectionUI` and `VOC_StartSelection` (usually the main VocationsController script). Check the Lua/script log for errors when you click TEST SELECTION or call `VOC_StartSelection`.
- **Debug buttons gone:** Clicking TEST SELECTION calls `VOC_ShowSelectionUI`, which calls `self.clearButtons()`, so the debug buttons are removed while the Option A grid is shown. After you choose a vocation, the grid is cleared. Use **VOC_RestoreDebugButtons()** from the Object’s Lua console to bring the debug buttons back:
  ```lua
  VOC_RestoreDebugButtons()
  ```

---

## Restore debug buttons

If the controller has no buttons after testing:

1. Open the **VocationsController** object’s Lua/script.
2. Run:
   ```lua
   VOC_RestoreDebugButtons()
   ```
3. The four debug buttons should reappear.

---

## Summary

- Use **TEST SELECTION** (with Global UI off) or **VOC_StartSelection({color = "Green"})** to trigger Option A.
- Option A is the **fallback** when the on-screen UI is not available.
- The **player color** that starts selection must be the one that clicks a vocation button; that click assigns the vocation and ends the selection.
