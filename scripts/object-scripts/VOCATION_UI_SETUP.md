# Vocation UI: Global vs Object

## Where to put each UI

| Location in TTS | File to use | What goes there |
|-----------------|-------------|------------------|
| **Global → UI tab** | `VocationsUI_Global.xml` | All vocation panels (selection, summary, science allocation). |
| **VocationsController object → UI tab** | `VocationsUI.xml` | Nothing vocation-related; leave empty/disabled. |

---

## Global UI (VocationsUI_Global.xml)

**Paste the full contents of `VocationsUI_Global.xml` into TTS: Global → UI.**

This is the **only** place the vocation UI lives. The VocationsController script uses `UI.setAttribute()` / `UI.getAttribute()`, which in TTS refer to **Global UI**, so all these elements must exist in Global:

- **vocationOverlay** – Root overlay that contains all vocation panels.
- **vocationSelectionPanel** – “Choose your vocation” screen:
  - Title, subtitle, science points text
  - 6 vocation card buttons (Public Servant, Celebrity, Social Worker, Gangster, Entrepreneur, NGO Worker) with images
  - Cancel button
- **vocationSummaryPanel** – After picking a vocation: shows the **explanation picture** (see below), title, Back and Confirm buttons.
- **sciencePointsPanel** – Science points allocation (K/S) for adult mode.

**Primary flow:** Vocation selection **starts with the Global UI** (6 vocation cards). When the player clicks a card, the summary panel opens with the **explanation image** for that vocation, then they can Confirm or Back.  
**Explanation images:** In `VocationsController.lua`, edit **`VOCATION_EXPLANATION_IMAGE`** and add your image URLs (one per vocation). Leave a vocation empty to use the card art instead.  
**If this XML is not in Global → UI**, the script falls back to controller buttons; panels must be in Global for the on-screen menu to appear.

---

## VocationsController Object UI (VocationsUI.xml)

**On the VocationsController object: Scripting → UI tab.**

Use `VocationsUI.xml` here. It is **intentionally minimal and disabled**:

- Root panel has `active="false"`.
- No vocation panels are defined here.

This avoids:

- Duplicate panel IDs (Global and Object would both have `vocationSelectionPanel`, etc.).
- Confusion about which UI the script is talking to (the script expects Global).

**You can:**

- Leave the Object UI as-is (empty/disabled).
- Or put **only** object-specific UI here (e.g. a small “Restore debug” or “Test” label) **with different IDs** than the Global UI (do not use `vocationSelectionPanel`, `vocationSummaryPanel`, etc. on the object).

---

## Quick reference

| What you want | Where |
|---------------|--------|
| Vocation selection/summary/science panels | **Global → UI** ← paste `VocationsUI_Global.xml` |
| VocationsController’s own UI | **Object → UI** ← use `VocationsUI.xml` (empty/disabled) |
| Buttons on the controller *object* (debug, vocation menu) | Created by **Lua** (`createButton` on the object), not by XML |
