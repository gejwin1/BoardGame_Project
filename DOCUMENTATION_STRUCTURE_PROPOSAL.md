# Documentation Structure Proposal

## 📋 Overview

This document proposes a comprehensive documentation structure to help onboard new collaborators and maintain clear project documentation. The structure is designed to be accessible to both technical and non-technical contributors.

---

## 🎯 Goals

1. **Onboarding**: Help new collaborators understand the project quickly
2. **Game Design**: Document game rules, mechanics, and design decisions
3. **Technical Architecture**: Explain how the codebase is organized
4. **Development Workflow**: Guide how to work with the project
5. **Status Tracking**: Keep track of what's done, what's in progress, and what's planned

---

## 📁 Proposed Documentation Structure

```
BoardGame_Project/
├── README.md                              ← Project overview (exists, enhance)
├── WORKFLOW_GUIDE.md                      ← Development workflow (exists, enhance)
│
├── docs/                                  ← NEW: Main documentation folder
│   ├── 01_GAME_DESIGN/
│   │   ├── GAME_OVERVIEW.md              ← What is the game? Core concept
│   │   ├── GAME_RULES.md                 ← Complete rulebook
│   │   ├── GAME_MECHANICS.md             ← Detailed mechanics explanation
│   │   ├── CARDS_REFERENCE.md            ← All card types and effects
│   │   └── PLAYER_GUIDE.md               ← How to play (for players)
│   │
│   ├── 02_ARCHITECTURE/
│   │   ├── SYSTEM_OVERVIEW.md            ← High-level system architecture
│   │   ├── COMPONENT_MAP.md              ← How components interact
│   │   ├── TAG_SYSTEM.md                 ← Tag-based communication explained
│   │   ├── API_REFERENCE.md              ← Key APIs between components
│   │   └── DATA_FLOW.md                  ← How data flows through systems
│   │
│   ├── 03_ONBOARDING/
│   │   ├── QUICK_START.md                ← 15-minute quick start guide
│   │   ├── SETUP_INSTRUCTIONS.md         ← Environment setup
│   │   ├── FIRST_TASKS.md                ← Suggested first tasks for new contributors
│   │   └── GLOSSARY.md                    ← Terms and abbreviations
│   │
│   ├── 04_DEVELOPMENT/
│   │   ├── CODING_STANDARDS.md            ← Code style and conventions
│   │   ├── TESTING_GUIDE.md               ← How to test changes
│   │   ├── DEBUGGING_GUIDE.md             ← Common issues and solutions
│   │   ├── ADDING_FEATURES.md             ← How to add new features
│   │   └── TROUBLESHOOTING.md             ← Common problems and fixes
│   │
│   └── 05_STATUS/
│       ├── PROJECT_STATUS.md              ← Overall project status
│       ├── FEATURE_ROADMAP.md             ← Planned features
│       ├── KNOWN_ISSUES.md                ← Current bugs and limitations
│       └── COMPLETION_CHECKLIST.md        ← What's done vs. what's needed
│
└── scripts/                               ← Existing code structure
    └── object-scripts/                    ← Individual component docs (exists)
```

---

## 📝 Detailed Documentation Plan

### 1. Game Design Documentation (`docs/01_GAME_DESIGN/`)

#### `GAME_OVERVIEW.md`
**Purpose**: High-level introduction to the game
**Contents**:
- Game name and concept
- Target audience
- Game type (life simulation, strategy, etc.)
- Core theme (work-life balance)
- Brief gameplay summary
- What makes it unique

**Example Structure**:
```markdown
# Game Overview

## Game Name
Work-Life Balance (WLB)

## Concept
A life simulation board game where players navigate through youth and adult phases, 
managing resources, making life choices, and balancing personal satisfaction with 
practical needs.

## Core Theme
Players experience the challenges of balancing work, education, relationships, 
health, and personal fulfillment across different life stages.

## Gameplay Summary
- 2-4 players
- 13 rounds total (Youth: rounds 1-5, Adult: rounds 6-13)
- Players manage: Money, Satisfaction, Health, Knowledge, Skills, Action Points
- Win condition: [To be documented]
```

#### `GAME_RULES.md`
**Purpose**: Complete rulebook
**Contents**:
- Setup instructions
- Turn structure
- Phase rules (Youth vs. Adult)
- Win conditions
- Special rules
- Edge cases

#### `GAME_MECHANICS.md`
**Purpose**: Deep dive into game mechanics
**Contents**:
- Action Point (AP) system
- Resource management (Money, Satisfaction, Stats)
- Event card system
- Shop system
- Estate/housing system
- Vocation system
- Status effects (Sick, Wounded, etc.)
- Turn progression
- Round structure

#### `CARDS_REFERENCE.md`
**Purpose**: Complete card catalog
**Contents**:
- Youth Event Cards (YD_01 to YD_39)
- Adult Event Cards (AD_01 to AD_81)
- Shop Cards (Consumables, Hi-Tech, Investments)
- Card effects reference
- Card types and categories

#### `PLAYER_GUIDE.md`
**Purpose**: How to play guide for players
**Contents**:
- Quick start guide
- First turn walkthrough
- Strategy tips
- Common mistakes to avoid
- FAQ for players

---

### 2. Architecture Documentation (`docs/02_ARCHITECTURE/`)

#### `SYSTEM_OVERVIEW.md`
**Purpose**: High-level technical architecture
**Contents**:
- System diagram (text or ASCII art)
- Major subsystems:
  - Turn Management System
  - Event System
  - Shop System
  - Estate System
  - Token System
  - UI System
- Technology stack (Tabletop Simulator, Lua)
- Design patterns used

**Example**:
```markdown
# System Overview

## Architecture Pattern
Tag-based component communication system

## Core Systems

### 1. Turn Controller (c9ee1a_TurnController)
- Central orchestrator
- Manages game state
- Coordinates other systems

### 2. Event System
- EventsController (1339d3): UI and track management
- EventEngine (7b92b3): Card processing and effects

### 3. Resource Controllers
- Money Controllers (4 players)
- AP Controllers (4 players)
- Stats Controllers (4 players)
- Satisfaction Tokens (4 players)

### 4. Game Systems
- Shop Engine (d59e04)
- Estate Engine (fd8ce0)
- Token Engine (61766c)
- Player Status Controller
```

#### `COMPONENT_MAP.md`
**Purpose**: Visual map of how components interact
**Contents**:
- Component dependency graph
- Communication flow
- Data dependencies
- Which components talk to which

#### `TAG_SYSTEM.md`
**Purpose**: Explain the tag-based communication
**Contents**:
- Why tags are used
- Tag naming conventions
- Common tags:
  - `WLB_COLOR_*` (player colors)
  - `WLB_LAYOUT` (layout objects)
  - `WLB_*_CTRL` (controllers)
  - `SAT_TOKEN` (satisfaction tokens)
- How to add new tags
- Tag best practices

#### `API_REFERENCE.md`
**Purpose**: Key APIs between components
**Contents**:
- Turn Controller APIs
- Event Engine APIs
- Shop Engine APIs
- Token Engine APIs
- How to call APIs from other scripts
- API versioning (if applicable)

#### `DATA_FLOW.md`
**Purpose**: How data flows through the system
**Contents**:
- Turn start → Event processing → Shop → Actions → Turn end
- State management
- Persistence (what saves, what doesn't)
- Global state vs. local state

---

### 3. Onboarding Documentation (`docs/03_ONBOARDING/`)

#### `QUICK_START.md`
**Purpose**: Get started in 15 minutes
**Contents**:
- Prerequisites (Tabletop Simulator, basic Lua knowledge)
- Project structure overview
- How to open the project
- How to make your first change
- How to test it
- Next steps

**Example**:
```markdown
# Quick Start Guide

## Prerequisites
- Tabletop Simulator installed
- Basic understanding of Lua (or willingness to learn)
- Access to the game save file

## 15-Minute Setup

1. **Open the project** (5 min)
   - Open Tabletop Simulator
   - Load the game save
   - Open Cursor/editor with this project folder

2. **Make a small change** (5 min)
   - Pick a simple script (e.g., Money Controller)
   - Change a display message
   - Copy script to TTS
   - Test in game

3. **Understand the workflow** (5 min)
   - Read WORKFLOW_GUIDE.md
   - Understand: Edit → Copy → Paste → Test

## Next Steps
- Read GAME_OVERVIEW.md to understand the game
- Read SYSTEM_OVERVIEW.md to understand the code
- Pick a small task from FIRST_TASKS.md
```

#### `SETUP_INSTRUCTIONS.md`
**Purpose**: Detailed setup instructions
**Contents**:
- Development environment setup
- Required tools
- Project structure explanation
- How to sync code with TTS
- Testing setup
- Common setup issues

#### `FIRST_TASKS.md`
**Purpose**: Suggested tasks for new contributors
**Contents**:
- Easy tasks (documentation, small fixes)
- Medium tasks (feature additions)
- Hard tasks (system refactoring)
- How to pick a task
- How to claim a task
- Task difficulty ratings

**Example Tasks**:
```markdown
# First Tasks for New Contributors

## 🟢 Easy (Good for First Contribution)
1. **Document a card effect** - Add missing card documentation
2. **Fix a typo** - Correct text in UI messages
3. **Add a comment** - Improve code documentation
4. **Test a feature** - Playtest and report issues

## 🟡 Medium (Requires Some Understanding)
1. **Add a new shop card effect** - Implement a consumable card
2. **Improve error messages** - Better user feedback
3. **Add a diagnostic tool** - Help with debugging

## 🔴 Hard (Requires Deep Understanding)
1. **Refactor a system** - Improve code structure
2. **Add a new game system** - Major feature addition
3. **Optimize performance** - Improve game speed
```

#### `GLOSSARY.md`
**Purpose**: Terms and abbreviations
**Contents**:
- AP = Action Points
- SAT = Satisfaction
- WLB = Work-Life Balance
- GUID = Global Unique Identifier
- TTS = Tabletop Simulator
- YD = Youth Deck
- AD = Adult Deck
- CSHOP = Consumable Shop
- HSHOP = Hi-Tech Shop
- ISHOP = Investment Shop
- L0-L4 = Housing Levels
- PSC = Player Status Controller
- etc.

---

### 4. Development Documentation (`docs/04_DEVELOPMENT/`)

#### `CODING_STANDARDS.md`
**Purpose**: Code style and conventions
**Contents**:
- Lua style guide
- Naming conventions
- Comment standards
- File organization
- Version numbering
- Code review guidelines

#### `TESTING_GUIDE.md`
**Purpose**: How to test changes
**Contents**:
- Testing workflow
- What to test
- How to test in TTS
- Test scenarios
- Regression testing
- Reporting bugs

#### `DEBUGGING_GUIDE.md`
**Purpose**: Debugging strategies
**Contents**:
- Using TTS console
- Common error patterns
- Diagnostic tools available
- How to use scanners
- Logging strategies
- Debugging tips

#### `ADDING_FEATURES.md`
**Purpose**: How to add new features
**Contents**:
- Feature planning checklist
- Where to add code
- How to integrate with existing systems
- Testing new features
- Documentation requirements
- Example: Adding a new card type

#### `TROUBLESHOOTING.md`
**Purpose**: Common problems and solutions
**Contents**:
- "Script doesn't work after copy-paste"
- "Object not found errors"
- "Tag not working"
- "UI not appearing"
- "State not persisting"
- Solutions and workarounds

---

### 5. Status Documentation (`docs/05_STATUS/`)

#### `PROJECT_STATUS.md`
**Purpose**: Overall project health
**Contents**:
- Current phase (Development, Testing, Polish, etc.)
- Completion percentage
- Recent achievements
- Current focus areas
- Blockers (if any)

**Example**:
```markdown
# Project Status

## Current Phase
**Development** - Core systems implemented, adding features and polish

## Completion Status
- ✅ Core Systems: 90% (Turn, Events, Shop, Estate, Token)
- 🟡 UI/UX: 70% (Functional but needs polish)
- 🟡 Content: 60% (All cards exist, some effects incomplete)
- 🔴 Testing: 30% (Needs comprehensive playtesting)
- 🔴 Documentation: 40% (Technical docs exist, design docs needed)

## Recent Achievements
- ✅ Turn Controller v2.9.2 released
- ✅ Shop Engine v1.3.4 with all consumables
- ✅ Event Engine v1.7.2 with full card support

## Current Focus
- Vocation system implementation
- UI polish and translations
- Bug fixes from playtesting

## Blockers
- None currently
```

#### `FEATURE_ROADMAP.md`
**Purpose**: Planned features
**Contents**:
- Short-term (next 2-4 weeks)
- Medium-term (next 1-3 months)
- Long-term (future ideas)
- Feature priorities
- Dependencies between features

#### `KNOWN_ISSUES.md`
**Purpose**: Current bugs and limitations
**Contents**:
- Critical bugs
- Minor bugs
- Known limitations
- Workarounds
- Bug reporting process

#### `COMPLETION_CHECKLIST.md`
**Purpose**: What's done vs. what's needed
**Contents**:
- System implementation status
- Card implementation status
- UI element status
- Documentation status
- Testing status
- Polish status

---

## 🚀 Implementation Priority

### Phase 1: Essential (Week 1)
1. ✅ Create `docs/` folder structure
2. ✅ Write `GAME_OVERVIEW.md` (basic version)
3. ✅ Write `QUICK_START.md`
4. ✅ Write `GLOSSARY.md`
5. ✅ Enhance `README.md` with links to new docs

### Phase 2: Core Documentation (Week 2-3)
1. ✅ Write `SYSTEM_OVERVIEW.md`
2. ✅ Write `COMPONENT_MAP.md`
3. ✅ Write `TAG_SYSTEM.md`
4. ✅ Write `GAME_MECHANICS.md` (basic version)
5. ✅ Write `PROJECT_STATUS.md`

### Phase 3: Detailed Documentation (Week 4+)
1. ✅ Complete `GAME_RULES.md`
2. ✅ Complete `CARDS_REFERENCE.md`
3. ✅ Write `API_REFERENCE.md`
4. ✅ Write development guides
5. ✅ Write `FEATURE_ROADMAP.md`

---

## 💡 Tips for Creating Documentation

### For Game Design Docs:
- **Start simple**: Begin with basic overview, expand later
- **Use examples**: Show, don't just tell
- **Include visuals**: ASCII diagrams, tables, lists
- **Player perspective**: Write for someone who's never seen the game

### For Technical Docs:
- **Start high-level**: Overview before details
- **Show relationships**: How things connect
- **Include code examples**: Real examples from the codebase
- **Keep it current**: Update when code changes

### For Onboarding Docs:
- **Be welcoming**: Friendly, encouraging tone
- **Start small**: Don't overwhelm with everything at once
- **Provide paths**: "If you're X, read Y first"
- **Include checklists**: Clear steps to follow

---

## 📋 Next Steps

1. **Review this proposal** - Does this structure work for you?
2. **Prioritize sections** - Which docs are most urgent?
3. **Start with Phase 1** - Create folder structure and essential docs
4. **Iterate** - Add more docs as needed, refine existing ones

---

## ❓ Questions to Consider

Before creating docs, think about:
- **Who is the audience?** (Technical developers? Game designers? Players?)
- **What do they need to know?** (How to code? How to play? How the game works?)
- **What's the goal?** (Onboarding? Reference? Learning?)
- **How will it be maintained?** (Who updates it? When?)

---

## 🎯 Success Criteria

Good documentation should:
- ✅ Help new contributors get started quickly
- ✅ Answer common questions without asking
- ✅ Stay up-to-date with the codebase
- ✅ Be easy to find and navigate
- ✅ Be written in clear, accessible language

---

**Ready to start?** Let's begin with Phase 1 and create the essential documentation structure!
