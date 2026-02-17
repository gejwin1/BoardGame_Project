# Vocation Summary Tables – Functionality and Implementation Status

This document describes all vocation summary elements: **passive** (no buttons, display-only or automatic) and **with buttons** (active abilities).

---

## Bug Reports & Fix Tracking

**Purpose:** Record what was reported as broken (exact user description), whether a fix was attempted, and current status. This helps the assistant and testers know precisely what was broken and what still needs verification.

| # | What was reported (user description) | Fix attempted? | Status |
|---|-------------------------------------|----------------|--------|
| 1 | **Health Monitor:** Error when clicking "Check health" – "attempt to call a number value" (Shop Engine hitech_onHMonitorUse). | Yes | Fix applied; **not yet tested** |
| 2 | **Gangster Steal hi-tech:** Message showed "White" instead of player color (e.g. Red); card did not move to gangster; success message but no actual effect. | Yes | Fix applied (effectsTarget, card move); **not yet tested** |
| 3 | **Gangster False money production:** No AP taken; message said "White gains 2000" but player was Red; no money given; no investigation; no heat raise. | Yes | Fix applied (effectsTarget, AP bypass removed); **not yet tested** |
| 4 | **Gangster Enforce citywide lockdown:** No AP taken; nothing happened for anyone. | Yes | Fix applied (effectsTarget, AP bypass); **not yet tested** |
| 5 | **Shop Engine onLoad:** Error "attempt to call a nil value" – refreshShopBoardDoublePricesUI was nil when drawUI ran. | Yes | Fix applied (function defined before drawUI); **not yet tested** |
| 6 | **Event Engine – Obligatory card ROLL:** Error when clicking ROLL on obligatory event card – "attempt to call a number value" (Time.time used as function). | Yes | Fix applied (Time.time vs Time.time()); **not yet tested** |
| 7 | **VE Crime from adult event card:** Error when selecting crime victim (e.g. Yellow) – "attempt to call a nil value" in VECrimeTargetSelected (Vocations Controller). User: "I chose a player which should be a victim and then this happened." | Yes | Fix applied (pass-through + direct call from handleTargetSelection); **not yet tested** |
| 8 | **Social Worker L1 Practical Workshop:** Bug at the very end of the event, during distribution of awards (when shutting the UI). Error: "attempt to call a nil value" in HandleInteractionResponse (VocationsController chunk_4, line 1870). Cause: addAwardToken was nil due to TTS script chunking. | Yes | Fix applied (safeAddAwardToken helper + API_AddAwardToken callable fallback); **not yet tested** |
| 9 | **End Turn confirm (ui_confirmEndTurnYes):** Error when clicking "Yes" to confirm end turn – "cannot convert a table to a clr type System.String" in WLB TURN CTRL (c9ee1a), chunk_4:(268) at round end. **Root cause:** `findOneByTags({TAG_VOCATIONS_CTRL})` passed a table to `hasTag()`; TTS expects a string. | Yes | **Fixed** – changed to `findOneByTags(TAG_VOCATIONS_CTRL)` |
| 10 | **First round, first player (e.g. Red):** Costs Calculator shows "Loan: 297" and other costs from previous game. Player did not take a loan. **Root cause:** ShopEngine's `pipeline_RESET` did not clear `S.investments`; loans/debentures/stock from previous game persisted and were charged at turn start. | Yes | **Fixed** – added `S.investments = { Yellow={}, Blue={}, Red={}, Green={} }` to pipeline_RESET |
| 11 | **Die roll (all events/shop/lottery):** First physical roll ignored, ~10 sec wait, then "automatic" second roll (no physical die) used. Affects all players. **Root cause:** EventEngine/ShopEngine always routed via VOC_RollDieForPlayer; non-Entrepreneur path had timing/bridge issues. | Yes | **Fixed** – use direct physical roll by default; only use VOC path when `VOC_CanUseEntrepreneurReroll(color)==true` (Entrepreneur L2 during their turn) |

**How to use this section:**
- When the user reports something doesn't work, add a row with their **exact description** of what failed.
- Set **Fix attempted?** to **Yes** or **No**.
- Set **Status** to one of: **Fix applied; not yet tested** | **Fixed; confirmed in game** | **Not yet fixed** | **Won't fix**.
- When a fix is verified in game, change status to **Fixed; confirmed in game**.

---

## Status Legend (Vocation Items)

- 🟡 **Probably working** – Code exists; not yet confirmed in-game.
- ✅ **Confirmed working** – Manually tested and verified in game.
- ⚠️ **Partly implemented** – Incomplete or uncertain.

**How to update:** When you confirm an item works in game, change 🟡 to ✅ and increment the **Confirmed** count in the summary table.

| Vocation       | Total | Probably working | Confirmed | Status    |
|----------------|-------|------------------|-----------|-----------|
| Public Servant | 13    | 13               | 0         | Pending   |
| Celebrity      | 8     | 8                | 0         | Pending   |
| Social Worker  | 11    | 11               | 0         | Pending   |
| NGO Worker     | 13    | 13               | 3         | Pending   |
| Entrepreneur   | 10    | 10               | 0         | Pending   |
| Gangster       | 12    | 11               | 0         | 1 partly  |
| **Total**      | **67**| **66**           | **3**     | 1 partly  |

**Note:** Special awards (L3 promotion conditions: taxes, community events, campaigns, crimes not caught, house+hi-tech, 10 AP+4000 VIN) may not be fully working end-to-end; not yet confirmed that any vocation can successfully receive a special award in game.

---

## 1. PUBLIC SERVANT — **13 total, 13 probably working — Pending confirmation**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | Per-level salary (L1: 100, L2: 200, L3: 300 VIN per AP work). | 🟡 Fully implemented (work AP → money). |
| **Promotion** | L1/L2: standard (Knowledge + Skills + Experience tokens). L3: award – successfully collect taxes twice at any level. | 🟡 Fully implemented (experience tokens, round-end check, award condition). |
| **Tax waiver** | One tax waiver per vocation level (use on own tax once per level). Shown as text on summary: "Tax can be waived" / "Tax obligation". | 🟡 Fully implemented (`summaryTaxWaiverStatus` in UI). |
| **Work obligation** | L1: 2–4 AP work/year for experience token. L2: same + SAT penalty if outside 2–4. L3: same + double SAT penalty; no special award if outside range. | 🟡 Fully implemented (VOC_OnRoundEnd). |
| **Experience tokens** | Count shown on summary ("Experience: X (need Y for next level)") for promotion. | 🟡 Fully implemented (`summaryExperienceTokens`). |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Income Tax Campaign (L1)** | Spend 2 AP; others pay tax (or refuse); Public Servant can waive own tax once per level; die roll for resolution. | 🟡 Fully implemented |
| **Health Monitor Access (L1 perk)** | Place Health Monitor tile for Public Servant (once). | 🟡 Fully implemented |
| **Anti-burglary Alarm (L1/L2 perk)** | Place Alarm tile for Public Servant (once). | 🟡 Fully implemented |
| **New Car (L1/L3 perk)** | Place Car tile for Public Servant (once). | 🟡 Fully implemented |
| **Hi-Tech Tax Campaign (L2)** | Spend 2 AP; tax campaign with waiver option; die roll. | 🟡 Fully implemented |
| **Property Tax Campaign (L3)** | Spend 2 AP; property tax campaign with waiver option; die roll. | 🟡 Fully implemented |
| **Special: Policy** | (Event/vocation card.) | 🟡 Fully implemented |
| **Special: Bottleneck** | (Event/vocation card.) | 🟡 Fully implemented |

---

## 2. CELEBRITY — **8 total, 8 probably working — Pending confirmation**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | L1: 30, L2: 150, L3: 800 VIN per AP work. | 🟡 Fully implemented |
| **Promotion** | Work-based: 10 AP work at level + Knowledge/Skills; L3 also requires 4000 VIN. | 🟡 Fully implemented (workAP tracking, pay 4000 at L3). |
| **Experience tokens** | Celebrity does **not** use experience tokens (work-based promotion). Summary does not show experience count for Celebrity. | 🟡 Implemented (correctly excluded). |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Live Street Performance (L1)** | Spend 2 AP; others Join (1 AP, +2 SAT) or Refuse; Entrepreneur not asked; if anyone joined: Celebrity gets +1 Skill, +150 VIN, die 1–3 → +2 SAT, 4–6 → +4 SAT. | 🟡 Fully implemented |
| **Meet & Greet (L2)** | Spend 1 AP + 200 VIN; others Join (1 AP) or Refuse; die roll; participants +1 Knowledge, +1 SAT; Celebrity SAT from die; if no one joined, Celebrity loses SAT. | 🟡 Fully implemented |
| **Extended Charity Stream (L3)** | Spend 2 AP; others donate 200 VIN for +2 SAT each; Celebrity gets +2 SAT and +1 AP obligation per donor; no money to Celebrity. | 🟡 Fully implemented |
| **Special: Fan Talent Collaboration** | (Event card.) | 🟡 Fully implemented |
| **Special: Meetup** | (Event card.) | 🟡 Fully implemented |

---

## 3. SOCIAL WORKER — **11 total, 11 probably working — Pending confirmation**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | L1: 70, L2: 150, L3: 250 VIN per AP work. | 🟡 Fully implemented |
| **Promotion** | L1/L2: standard (Knowledge + Skills + Experience). L3: award – two community events with at least one participant each. | 🟡 Fully implemented |
| **Experience tokens** | Shown on summary. | 🟡 Fully implemented |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Community Event: Practical workshop (L1)** | Spend 2 AP; others may join (1 AP); then choose +1 Knowledge or +1 Skill; initiator +1 SAT per participant. | 🟡 Fully implemented |
| **Use Good Karma (L1)** | Once per game: use Good Karma status for benefit. | 🟡 Fully implemented |
| **Community Wellbeing Session (L2)** | Spend 2 AP; others join (1 AP); participants +2 SAT; initiator +1 SAT per participant, +2 if anyone joined. | 🟡 Fully implemented |
| **Once per game: one consumable from shop free (L2)** | Take one consumable from shop at no cost. | 🟡 Fully implemented |
| **Expose social case (L3)** | Spend 3 AP; others Join (Knowledge) or Refuse (Ignorant); Refuse +1 SAT; Join +1 Knowledge; initiator +3 SAT. | 🟡 Fully implemented |
| **Once per game: one hi-tech from shop free (L3)** | Take one hi-tech from shop at no cost. | 🟡 Fully implemented |
| **Special: Homeless Shelter** | (Event card.) | 🟡 Fully implemented |
| **Special: Removal** | (Event card.) | 🟡 Fully implemented |

---

## 4. NGO WORKER — **13 total, 13 probably working — Pending confirmation**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | L1: 80, L2: 240, L3: 450 VIN per AP work. | 🟡 Fully implemented |
| **Promotion** | L1/L2: standard. L3: award – 2 social campaigns OR 1 campaign + 10 AP voluntary work. | 🟡 Fully implemented |
| **NGO Worker pays no income tax** | Handled in tax logic. | 🟡 Fully implemented |
| **Experience tokens** | Shown on summary. | 🟡 Fully implemented |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Charity campaign (L1)** | Spend 2 AP; die roll; participants pay or refuse; effects by result. | ✅ Confirmed working |
| **Take Good Karma (free) (L1)** | Once per level: take Good Karma card from shop (or events deck). Works when card is visible; no card on table = no effect. | ✅ Confirmed working |
| **Voluntary work (L1/L2/L3)** | Spend AP (L1: 2, L2: 3, L3: 1); gain SAT. | 🟡 Fully implemented |
| **Crowdfunding campaign (L2)** | Spend 2 AP; die roll; pool for Hi-Tech purchases. | 🟡 Fully implemented |
| **Take Trip (free) (L2)** | Once per level: take one Trip card from shop for free. | 🟡 Fully implemented |
| **Advocacy / pressure campaign (L3)** | No die; others vote YES/NO; effects by votes. | 🟡 Fully implemented |
| **Use Investment (free, up to 1000 VIN) (L3)** | Once per level: use one Investment from shop up to 1000 VIN free. | 🟡 Fully implemented |
| **Special: Crisis Appeal** | (Event card.) | 🟡 Fully implemented |
| **Special: Scandal** | Misused donation scandal (event card). | ✅ Confirmed working |

---

## 5. ENTREPRENEUR — **10 total, 10 probably working — Pending confirmation**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | L1: 150, L2: 300, L3: 500 VIN per AP work. | 🟡 Fully implemented |
| **Promotion** | L1/L2: standard. L3: award – buy L3 or L4 house + 2 High-Tech items. | 🟡 Fully implemented |
| **Experience tokens** | Shown on summary. | 🟡 Fully implemented |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Flash Sale Promotion (L1)** | Spend 1 AP; in turn order each player may buy one consumable at 30% off (BUY / RESIGN on each C card); shelf refills after each purchase; Entrepreneur +1 SAT per **other** player who buys. | 🟡 Fully implemented (initiator fix, SAT only for others, refill via API, vertical buttons). |
| **Talk to shop owner (L1)** | Spend 1 AP; other players pay **double** for consumables and hi-tech until Entrepreneur's next turn; reminder "DOUBLE PRICES!" on shop board. | 🟡 Fully implemented |
| **Commercial training course (L2)** | Spend 2 AP; die roll; participants get bonuses; Entrepreneur gains from result. | 🟡 Fully implemented |
| **Use your network (L2)** | Passive: on every die roll during their turn (vocation, shop, events), Entrepreneur may choose Reroll (1 AP, once) or Go on. | 🟡 **Fully implemented** (VOC_RollDieForPlayer; halt on Shop/Event die rolls). |
| **Reposition event cards (L3)** | Spend 2 AP; pick 3 event-lane cards (MOVE on each non-empty slot 1–7); then MOVE TO + slot buttons (1, 2, 7 etc.) on those cards; assign each to a destination; cards reorder. | 🟡 **Fully implemented** (EventsController: select 3 → assign 3 destinations; buttons on cards only). |
| **Special: Aggressive Expansion** | (Event card.) | 🟡 Fully implemented |
| **Special: Employee Training** | (Event card.) | 🟡 Fully implemented |

---

## 6. GANGSTER — **12 total, 11 probably working, 1 partly**

### Passive (no buttons)
| Element | Description | Status |
|--------|-------------|--------|
| **Salary** | L1: 80, L2: 200, L3: 450 VIN per AP work. | 🟡 Fully implemented |
| **Promotion** | L1/L2: standard. L3: award – 2 crimes without getting caught (or 3 with one caught). | ⚠️ Partly implemented (promotion logic may need award-condition tracking). |
| **Heat & Investigation** | After successful crime: investigate first at **current** heat, then heat +1. Punishment by result (dismiss, warning, fine, conviction). | 🟡 Fully implemented (order fixed: investigate then +1 heat). |
| **Experience tokens** | Shown on summary. | 🟡 Fully implemented |

### With buttons (action buttons)
| Button | Description | Status |
|--------|-------------|--------|
| **Crime action: Steal hi-tech from shop (L1)** | Spend 3 AP; choose one open hi-tech (STEAL on card); roll die: 1–2 fail, 3–4 success + investigation, 5–6 success + heat only; card to gangster and H row refills. | 🟡 **Fully implemented** (ShopEngine STEAL on H cards; VocationsController roll + investigation/heat). |
| **Crime against player (L1)** | Choose target; die roll; steal/wound by result; heat + investigation. | 🟡 Fully implemented |
| **Crime action: False money production (L2)** | Spend 3 AP; roll die: 1–2 fail, 3–4 success +1000 VIN, 5–6 great success +2000 VIN; 3–6 = crime → investigation + heat. | 🟡 **Fully implemented** |
| **Crime against player (L2)** | As L1 with higher amounts. | 🟡 Fully implemented |
| **Crime action: Enforce citywide lockdown (L3)** | Spend 2 AP; all opponents start their next turn with 1 AP moved to inactive; gangster rolls: 1-2 +200 VIN, 3-4 +500 VIN, 5-6 +1000 VIN and +2 SAT; crime → investigation + heat. | 🟡 **Fully implemented** (lockdown via VOC_OnTurnStarted in TurnController). |
| **Crime against player (L3)** | As L1/L2 with highest tier. | 🟡 Fully implemented |
| **Special: Robin Hood Job** | Choose target; spend 2 AP; die roll; steal from target, donate to orphanage; initiator +SAT. | 🟡 Fully implemented |
| **Special: Protection** | (Event card.) | 🟡 Fully implemented |

---

## Summary of implementation status

### Probably working (🟡 – code exists, not yet confirmed in game)
- All **Public Servant** actions and passive (tax campaigns, perks, waiver, work obligation, experience).
- All **Celebrity** actions (Street Performance, Meet & Greet, Charity Stream, specials).
- All **Social Worker** actions and perks (workshop, Good Karma, wellbeing, free consumable/hi-tech, expose case, specials).
- All **NGO Worker** actions (charity, crowdfunding, advocacy, voluntary work, Take Good Karma/Trip/Investment, specials).
- **Entrepreneur**: Flash Sale Promotion, Talk to shop owner, Commercial training course, Use your network (L2 passive), Reposition event cards (L3), both specials.
- **Gangster**: Steal hi-tech from shop (L1), False money production (L2), Enforce citywide lockdown (L3), all "Crime against player" (L1/L2/L3), Robin Hood, Protection; heat/investigation order and logic.

### Partly implemented / uncertain
- **Gangster L3 promotion** award condition (2 crimes not caught / 3 with one caught).
- **All vocation L3 special awards** – Not confirmed that any vocation can successfully receive a special award in game (taxes collected, community events, campaigns, crimes not caught, house+hi-tech, 10 AP+4000 VIN).

### Confirmed working (✅)
- **NGO Worker**: Charity campaign (L1), Take Good Karma (free) (L1), Special: Scandal (Misused donation).

---

## Summary table UI elements (with and without buttons)

- **With buttons:** Panel `vocationActionButtons` with up to 5 buttons (`btnAction1`–`btnAction5`). Labels and visibility come from `getVocationActions()`; clicks go to `executeVocationActionById(actionId, params)`.
- **Without buttons (passive text):**
  - **Public Servant only:** `summaryTaxWaiverStatus` – "Tax can be waived" / "Tax obligation".
  - **All except Celebrity:** `summaryExperienceTokens` – "Experience: X (need Y for next level)" when applicable.
- **Common:** Summary panel shows vocation name, explanation image, and (when not in preview) Back/Confirm. In preview mode, only Exit is shown and action buttons are hidden.

---

---

## Documentation Workflow

When reporting or fixing issues:

1. **User reports "X doesn't work"** → Add a row in **Bug Reports & Fix Tracking** with the user's exact description.
2. **Fix is attempted** → Set "Fix attempted?" to **Yes**; set Status to **Fix applied; not yet tested**.
3. **Fix is verified in game** → Change Status to **Fixed; confirmed in game**.
4. **No fix yet** → Set "Fix attempted?" to **No**; Status to **Not yet fixed**.

*Document generated from VocationsController and related scripts. Last sync with code: vocation summary tables and action router.*
