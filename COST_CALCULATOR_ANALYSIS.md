# Cost Calculator – Full Integration Analysis

## 1. Costs Calculator Script (bccb71_CostsCalculator.lua)

### replaceRentCost (lines 445–478)

- **Purpose:** Replace all rent-related costs with one line (e.g. "Level 2 rent: 350"), no deltas.
- **API:** `replaceRentCost({ color, amount, label })`
  - `color` – required, must be "Yellow"|"Blue"|"Red"|"Green"
  - `amount` – rent total (0 = no rent)
  - `label` – e.g. "Level 2 rent: 350", nil if amount=0
- **Logic:**
  - Removes items where `label` starts with "Rent " OR (starts with "Level " AND contains "rent")
  - Covers: "Rent L0", "Rent L0→L2", "Level 2 rent: 350", etc.
  - Updates `costsDue[c]` by subtracting removed total and adding `amount`
  - Adds one new rent item if `amount > 0` and `label` is set
- **Visibility:** Top-level function, callable via `obj.call("replaceRentCost", params)` from other objects.

### resolveColor (lines 80–89)

- Uses `params.color` or `params.playerColor` or `params.pc`
- `fallbackToActive=false` in replaceRentCost → explicit color required
- If `params.color` is nil or not in {"Yellow","Blue","Red","Green"}, returns nil → replaceRentCost exits without updating

### Compatibility with Other Features

- **addCost** – Still used for Baby, Loan, Property Tax, etc.; adds entries to `costsBreakdown`.
- **clearCost** – Clears costs and earnings for a color; does not conflict with rent.
- **resetNewGame** – Resets all costs; compatible.
- **doPay** – Reads `costsDue` and `getCosts(color)`, deducts money; rent stored via replaceRentCost is paid correctly.
- **onSave/onLoad** – Persists `costsDue`, `costsBreakdown`; rent entries are included.
- **buildBreakdownTooltip** – Merges by label; single rent line like "Level 2 rent: 350" displays correctly.

## 2. Callers and Their Status

| Caller | Function | Status |
|--------|----------|--------|
| TurnController | replaceRentCost | Uses replaceRentCost – correct |
| EstateEngine (rent/buy/return) | replaceRentCost | Uses replaceRentCost – correct |
| EstateEngine API_UpdateRentalCostsForVocationChange | addCost (delta) | Uses addCost with delta – adds extra line; should use replaceRentCost |
| ShopEngine EstateInvest | addCost (delta) | Uses addCost with delta – adds "Rent L0→L2" line; should use replaceRentCost |
| EventEngine (Baby) | addCost | Uses addCost – correct (not rent) |
| EventEngine (Property Tax) | addCost | Uses addCost – correct (not rent) |
| PlayerBoardController_Shared (salary) | addCost | Uses addCost (earnings) – correct |

## 3. Inconsistencies (FIXED)

1. **API_UpdateRentalCostsForVocationChange** – Now uses `replaceRentCost` with discounted amount and label like "Level 0 rent: 25".
2. **ShopEngine EstateInvest** – Now uses `replaceRentCost` with final rent and label like "Level 2 rent: 350".

## 4. Robustness

- **Color format:** `resolveColor` requires exact "Yellow","Blue","Red","Green". Callers (TurnController, EstateEngine) use the same format from game state. If TTS or a caller sends different casing or keys, replaceRentCost will not update.
- **Fallback:** Using `fallbackToActive=true` when `params.color` is missing could help if parameters are lost across objects in TTS, but risks updating the wrong player. Safer to keep `fallbackToActive=false` and ensure callers always pass color.
