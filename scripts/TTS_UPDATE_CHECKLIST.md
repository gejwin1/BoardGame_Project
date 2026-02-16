# Tabletop Simulator – Files to Update After Merge

Use this list when pasting the merged project files into Tabletop Simulator. Only **Lua scripts** go into TTS; the **.md** files are documentation only.

---

## Scripts to insert into Tabletop Simulator (5 files)

These are the **object scripts** that were part of the merge. Update the corresponding object in TTS by replacing its Lua script with the file from your project.

| # | File | In TTS: find object by… |
|---|------|--------------------------|
| 1 | [VocationsController.lua](object-scripts/VocationsController.lua) | Object that runs the Vocations system (often named/tagged “Vocations” or “VocationsController”). |
| 2 | [bccb71_CostsCalculator.lua](object-scripts/bccb71_CostsCalculator.lua) | Object whose GUID starts with **bccb71** (Costs Calculator). |
| 3 | [c9ee1a_TurnController.lua](object-scripts/c9ee1a_TurnController.lua) | Object whose GUID starts with **c9ee1a** (Turn Controller). |
| 4 | [d59e04_ShopEngine.lua](object-scripts/d59e04_ShopEngine.lua) | Object whose GUID starts with **d59e04** (Shop Engine). |
| 5 | [fd8ce0_EstateEngine.lua](object-scripts/fd8ce0_EstateEngine.lua) | Object whose GUID starts with **fd8ce0** (Estate Engine). |

**How to update in TTS:**  
For each row: select the object → open its **Scripting** tab → replace the Lua code with the contents of the corresponding file above, then save.

---

## Documentation only (do not paste into TTS)

| File | Purpose |
|------|--------|
| [Adult_Vocation_Event_Cards.md](object-scripts/Adult_Vocation_Event_Cards.md) | Reference / design notes. |
| [VOCATION_SUMMARIES_AND_BUTTONS.md](object-scripts/VOCATION_SUMMARIES_AND_BUTTONS.md) | Reference / design notes. |

---

## Quick checklist

- [ ] [VocationsController.lua](object-scripts/VocationsController.lua) → Vocations controller object  
- [ ] [bccb71_CostsCalculator.lua](object-scripts/bccb71_CostsCalculator.lua) → Object GUID `bccb71...`  
- [ ] [c9ee1a_TurnController.lua](object-scripts/c9ee1a_TurnController.lua) → Object GUID `c9ee1a...`  
- [ ] [d59e04_ShopEngine.lua](object-scripts/d59e04_ShopEngine.lua) → Object GUID `d59e04...`  
- [ ] [fd8ce0_EstateEngine.lua](object-scripts/fd8ce0_EstateEngine.lua) → Object GUID `fd8ce0...`  

After updating all five scripts in TTS, save your game so the merged behaviour (including assistant’s NGO/SW and your PS perks) is in the table.
