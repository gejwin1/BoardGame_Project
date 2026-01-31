# Shop Engine Dice Refactor Plan

## Goal
Change dice-requiring shop cards to use manual die rolling with "ROLL DICE" button.

## Current Flow
1. Click card → YES/NO modal
2. Click YES → Effect applied immediately (dice auto-rolled)

## Desired Flow  
1. Click card → YES/NO modal
2. Click YES → If dice needed, show "ROLL DICE" button (don't auto-roll)
3. Player manually rolls physical die
4. Player clicks "ROLL DICE" → Script reads die value → Applies effect

## Cards Requiring Dice
- **PILLS**: Addiction risk (normal) or cure attempt (if already addicted)
- **CURE**: Healing success/failure
- **FAMILY**: Child chance
- **NATURE_TRIP**: Satisfaction bonus

## Implementation Steps
1. ✅ Add pendingDice state
2. ✅ Add uiAttachRollDiceButton() function
3. 🔄 Modify applyConsumableEffect() to:
   - Check if dice needed
   - If yes and rollValue==nil: show button, return "WAIT_DICE"
   - If rollValue provided: process effect
4. 🔄 Modify attemptBuyCard() to handle "WAIT_DICE" return (don't stash card yet)
5. 🔄 Add shop_onRollDice() callback:
   - Read die value using tryReadDieValue()
   - Call applyConsumableEffect() again with rollValue
   - Stash card after effect completes
6. 🔄 Update all dice-requiring effects (PILLS, CURE, FAMILY, NATURE_TRIP)

## Notes
- `rollD6()` function will be replaced with direct die reading in button callback
- Need to ensure card stays on table until dice roll completes
