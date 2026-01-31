# Development Workflow Guide

## 📋 Overview

This guide explains the **best way to work** with your Tabletop Simulator scripts using external files.

---

## 🎯 The Reality: TTS Script Loading

**Short answer:** Tabletop Simulator **does NOT support loading external `.lua` files directly into object scripts**. Each object's script must be pasted into TTS.

**However:** External files are still **extremely valuable** for:
- ✅ Code editing with AI assistance (Cursor)
- ✅ Version control (Git)
- ✅ Code organization
- ✅ Collaboration
- ✅ Documentation

---

## 💡 Recommended Workflow

### **Standard Development Cycle**

1. **Edit in Cursor** (External File)
   - You: *"Add a button that calculates player scores"*
   - Me: I edit `scripts/object-scripts/XXXXXX_SomeController.lua`
   - File is saved automatically

2. **Copy Script to TTS**
   - Open file in Cursor: `Ctrl+A` → `Ctrl+C` (Select All → Copy)
   - Open TTS → Right-click object → Scripting Tab
   - Select all existing script: `Ctrl+A`
   - Paste new script: `Ctrl+V`
   - Click "Save & Apply"

3. **Test in Game**
   - Play the game
   - Test the new feature
   - Report issues back to me

4. **Iterate**
   - If bug: I fix in external file, you copy again
   - If working: Move to next feature!

---

## 🚀 Alternative: Global Script Approach (Advanced)

**Note:** This is more complex and changes your architecture. Only consider if you want everything centralized.

### How It Works:
- Move ALL logic to the **Global Script**
- Global Script contains one big file with functions for each object
- Objects call `Global.functionName()` instead of having their own scripts
- Global Script CAN use `dofile()` to load modules (with setup)

### Pros:
- Single source of truth
- Can use `dofile()` for code splitting
- Easier to share utilities

### Cons:
- **Requires massive refactoring** (rewrite all 42 scripts)
- All objects lose independent script space
- More complex debugging
- Harder to understand "which script does what"

### When to Use:
- Only if you're starting from scratch
- Not recommended for your existing 42-script project

---

## 📁 Current Project Structure

```
BoardGame_Project/
├── README.md                      ← Project overview
├── WORKFLOW_GUIDE.md             ← This file
├── scripts/
│   ├── WLB_DIAGNOSTIC_CTRL.lua  ← Diagnostic tool
│   └── object-scripts/           ← All object scripts
│       ├── 465776_YearToken.lua
│       ├── 465776_YearToken_DOC.md
│       ├── bccb71_CostsCalculator.lua
│       ├── bccb71_CostsCalculator_DOC.md
│       └── ... (42 scripts total)
```

---

## 🛠️ Best Practices

### ✅ DO:
- **Edit in external files** (Cursor with AI)
- **Copy entire scripts** when updating (don't merge manually)
- **Test immediately** after pasting
- **Report issues** with context ("Button doesn't appear", "Error in console")
- **Keep scripts organized** in folders
- **Version control** your external files (Git)

### ❌ DON'T:
- **Edit scripts directly in TTS** (hard to version control, no AI help)
- **Mix external + TTS edits** (one source of truth: external files)
- **Skip testing** (always test before moving on)
- **Edit multiple objects simultaneously** (one at a time is clearer)

---

## 🎯 Quick Reference

### Updating a Script

```bash
# 1. I modify: scripts/object-scripts/XXXXXX_SomeObject.lua
# 2. You copy the file content (Ctrl+A, Ctrl+C)
# 3. Paste into TTS object script tab (Ctrl+V)
# 4. Save & Apply
# 5. Test!
```

### Adding a New Script

```bash
# 1. You: "I need a new controller for X"
# 2. I: Create scripts/object-scripts/NEWGUID_NewController.lua
# 3. I: Create scripts/object-scripts/NEWGUID_NewController_DOC.md
# 4. You: Copy script, paste into TTS object, test
# 5. Update SCRIPTED_OBJECTS_CHECKLIST.md
```

### Fixing a Bug

```bash
# 1. You: "The Shop Engine crashes when buying item X"
# 2. I: Find scripts/object-scripts/d59e04_ShopEngine.lua
# 3. I: Fix the bug
# 4. You: Copy fixed script, paste into TTS, test
# 5. You: Confirm fix or report more issues
```

---

## 🤔 FAQ

**Q: Why can't TTS load files directly?**  
A: TTS was designed for embedded scripts. The Global Script can load files, but object scripts cannot. This is a TTS limitation.

**Q: Isn't copy-paste annoying?**  
A: Initially yes, but once you get used to it, it's actually faster than editing in TTS. Plus, you get AI assistance, version control, and better organization.

**Q: What if I edit in both places?**  
A: Don't! Pick ONE source of truth. We use external files as the master copy. If you must edit in TTS, copy it back to the external file immediately.

**Q: Can I automate the copy-paste?**  
A: Not easily. TTS doesn't have an API for this. Some users write Python scripts to inject code, but it's complex and error-prone. Manual copy-paste is the most reliable.

---

## 🎮 Development Priorities

Now that all scripts are documented:

1. **New Features** - Add missing game mechanics
2. **Bug Fixes** - Fix reported issues
3. **Code Quality** - Improve existing scripts
4. **Polish** - Translate to English, improve UX

**Ready to continue!** 🚀
