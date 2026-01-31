
# Tabletop Simulator Board Game Project

## Welcome! 👋

This folder contains your Tabletop Simulator Lua scripts organized as external files.

## Why External Files?

✅ **Better organization** - All your scripts in one place  
✅ **Easy editing** - Use Cursor's AI assistance to modify code  
✅ **Version control** - Track changes to your scripts  
✅ **Faster workflow** - No need to re-type code  

---

## Current Project Status

✅ **Phase 1: Documentation** (Complete)
- All 42 scripted objects documented
- Component documentation in `scripts/object-scripts/*_DOC.md`

📋 **Phase 2: Documentation Structure** (In Progress)
- Documentation structure created
- Onboarding guides in progress
- Game design documentation in progress

🎮 **Phase 3: Development** (Ongoing)
- Adding new features
- Fixing bugs
- Improving existing scripts
- UI polish and translations

📊 **See [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) for detailed status and complete documentation**

---

## How to Use This Project

### 🆕 New Contributor?
1. **Start here**: Read **[PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)** - Complete project documentation
2. **Learn the workflow**: Read **[WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md)** for detailed development instructions

### 📚 Documentation
- **Main Documentation**: See **[PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)** for complete project documentation
- **Component Docs**: See `scripts/object-scripts/*_DOC.md` for individual component documentation
- **Workflow**: See `WORKFLOW_GUIDE.md` for development workflow

### 📖 Existing Contributor?
Read **[WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md)** for detailed workflow instructions!

### Quick Workflow:
1. **Tell me what you want** - Describe the feature or bug fix
2. **I edit the external file** - Changes saved in `scripts/object-scripts/`
3. **You copy script** - Open file in Cursor → `Ctrl+A` → `Ctrl+C`
4. **Paste into TTS** - Object Script tab → `Ctrl+A` → `Ctrl+V` → Save
5. **Test in game** - Verify it works, report back!

> **Note:** TTS cannot load external files directly. We edit externally, then copy-paste into TTS. This gives us AI assistance, version control, and better organization. See [WORKFLOW_GUIDE.md](WORKFLOW_GUIDE.md) for details.

---

## Folder Structure

```
BoardGame_Project/
├── DOCUMENTATION_TEMPLATE.md         ← Fill this out with your existing scripts
├── DOCUMENTATION_STRUCTURE_PROPOSAL.md ← Documentation structure proposal
├── README.md                          ← This file (project overview)
├── WORKFLOW_GUIDE.md                  ← Development workflow guide
├── docs/                              ← 📚 Main documentation folder
│   ├── 01_GAME_DESIGN/                ← Game rules, mechanics, cards
│   ├── 02_ARCHITECTURE/               ← Technical architecture docs
│   ├── 03_ONBOARDING/                 ← Getting started guides
│   ├── 04_DEVELOPMENT/                ← Development guides
│   └── 05_STATUS/                      ← Project status and roadmap
└── scripts/
    ├── object-scripts/                ← Individual object scripts
    └── SCRIPTED_OBJECTS_CHECKLIST.md  ← Complete component inventory
```

---

## Next Steps

1. **Fill out `DOCUMENTATION_TEMPLATE.md`** with all your existing scripts
2. Tell me when you're done documenting
3. I'll create the `.lua` files based on your documentation
4. Then we can start adding new features!

---

**Don't worry if you're not technical!** Just describe what your scripts do in plain English. I'll handle all the code details.
