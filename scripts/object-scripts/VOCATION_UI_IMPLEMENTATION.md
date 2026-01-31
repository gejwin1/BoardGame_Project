# Vocation Selection UI Implementation

## Overview
This document describes the UI XML-based vocation selection system implemented for the Adult period start flow.

## Files Created

### 1. UI XML Files
- **`VocationSelectionUI.xml`**: Main selection screen with 6 vocation buttons
- **`VocationSummaryUI.xml`**: Detailed vocation info with Confirm/Back buttons
- **`SciencePointsAllocationUI.xml`**: Science Points distribution UI (for future use)

### 2. Modified Files
- **`VocationsController.lua`**: Added UI handlers and state management
- **`c9ee1a_TurnController.lua`**: Updated flow to trigger vocation selection AFTER Science Points allocation

## Flow

### Adult Period Start Sequence:
1. **Dice Rolls** → Determine turn order
2. **Science Points Allocation** → Players distribute bonus pool into K/S
3. **Vocation Selection** → Players choose vocations (in Science Points order)
   - Selection UI appears
   - Player clicks a vocation button
   - Summary UI appears with details
   - Player can Confirm or go Back
   - After confirmation, next player's turn

## UI Handlers

### In VocationsController.lua:

#### `UI_SelectVocation(player, value, id)`
- Called when player clicks a vocation button
- Shows the Vocation Summary UI for that vocation
- Validates that it's the active player

#### `UI_ConfirmVocation(player, value, id)`
- Called when player clicks "Confirm Choice"
- Sets the vocation for the player
- Places Level 1 tile on player board
- Notifies TurnController to advance to next player
- Hides all UI panels

#### `UI_BackToSelection(player, value, id)`
- Called when player clicks "← Back"
- Returns to the selection screen
- Hides summary, shows selection again

## UI State Management

The `uiState` table tracks:
- `activeColor`: Currently selecting player
- `currentScreen`: "selection", "summary", or nil
- `previewedVocation`: Vocation being previewed

## Integration Points

### TurnController Integration:
- `adultApply()` now triggers `startVocationSelection()` when all players finish allocating Science Points
- `VOC_OnVocationSelected()` callback advances to next player

### VocationsController Integration:
- `VOC_StartSelection()` now uses UI system (with fallback to buttons)
- `showSelectionUI()` displays the selection panel
- `showSummaryUI()` displays the summary panel
- Button states update to disable taken vocations

## Button IDs in XML

The vocation buttons use these IDs:
- `btnPublicServant` → PUBLIC_SERVANT
- `btnCelebrity` → CELEBRITY
- `btnSocialWorker` → SOCIAL_WORKER
- `btnGangster` → GANGSTER
- `btnEntrepreneur` → ENTREPRENEUR
- `btnNGOWorker` → NGO_WORKER

## Testing Checklist

- [ ] UI panels appear when vocation selection starts
- [ ] All 6 vocation buttons are visible and clickable
- [ ] Clicking a vocation shows the summary panel
- [ ] Summary shows correct vocation data (Level 1, salary, promotion reqs)
- [ ] "Back" button returns to selection screen
- [ ] "Confirm" button sets vocation and advances to next player
- [ ] Taken vocations are disabled (grayed out)
- [ ] Race condition protection (can't confirm already-taken vocation)
- [ ] UI hides after all players have selected

## Notes

- The UI system uses TTS's built-in UI XML interface
- UI panels are shown/hidden via `UI.setAttribute("panelId", "visibility", "true/false")`
- Button callbacks receive `(player, value, id)` parameters
- The system falls back to button-based UI if UI XML is not available
