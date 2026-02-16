# Vocation Summary UI – Buttons and Special Functions

This document describes all six vocation summaries: their UI buttons (label, behavior, implementation status) and passive perks. It is intended so that implementations can be completed or added later in a consistent way.

**Structure:** One part per vocation. Each part lists levels 1–3, the buttons at that level (community events + level perks), and any passive perks that do not have a button.

---

## Part 1. Social Worker

### Level 1 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Community Event: Practical workshop** | Community event. Run the practical workshop (who joins, then reward choice). | **Implemented** | `actionId`: `SW_L1_PRACTICAL_WORKSHOP`. Starts modal/flow for participants and rewards; AP cost 2. |
| 2 | **Use Good Karma** | Level 1 perk. On click: the player **receives one Good Karma token**. | **To implement** | Good Karma is already defined elsewhere (obligatory cards: “Use Good Karma to avoid results?”; token consumed when used). This button only **grants** one Good Karma token to the Social Worker. No consumption here. |

### Level 2 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Community Wellbeing Session** | Community event. Run the community wellbeing session. | **Implemented** (or partly) | `actionId`: `SW_L2_COMMUNITY_WELLBEING`. AP cost 2; participants and effects handled in VocationsController. |
| 2 | **Once per game: one consumable from shop free** | Level 2 perk. Once in the game, the player may take **one consumable from the shop for free**. | **To implement** | Give the player **consumable discount tokens**. Each token = **25%** discount (e.g. 4 tokens = 100% = one free consumable). When buying a consumable, spend tokens to reduce cost. Track “once per game” (e.g. one-time grant of tokens, or flag that this perk was used). |

### Level 3 – Two buttons + passive perk

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Expose social case** | Community event. Full description: **“Exposed a disturbing social case”**. Presents a choice to the players. | **Implemented** | `actionId`: `SW_L3_EXPOSE_CASE`. Title in code: “EXPOSE DISTURBING SOCIAL CASE”. AP cost 3. |
| 2 | **Once per game: one hi-tech from shop free** | Level 3 perk. Once in the game, the player may take **one hi-tech item from the shop for free**. | **To implement** | Give the player **hi-tech discount tokens**. Each token = **25%** discount (e.g. 4 tokens = 100% = one free hi-tech). When buying a hi-tech item, spend tokens to reduce cost. Track “once per game” (e.g. one-time grant of tokens, or flag that this perk was used). |

### Passive perk (no button)

| Perk | Description | Implementation status | Implementation notes |
|------|-------------|------------------------|------------------------|
| **Rent discount** | Social Worker pays only **50% of rent** for any **rented apartment**. | **To implement** | Passive. No button. Must be applied wherever rent is calculated/charged (e.g. Estate Engine, Turn Controller, or cost calculator). When the payer is Social Worker and the dwelling is a rented apartment, apply 50% of the normal rent. |

---

## Part 2. Celebrity

**Button layout:** One button per level (level action only). Level 1 → one button; Level 2 → one button; Level 3 → one button.

### Level 1 – One button

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Live Street Performance** | Level action. Run the live street performance / stream. | **Partly implemented** | `actionId`: `CELEB_L1_STREET_PERF`. Cost: 2 AP. Effects: participants gain +2 or +4 Satisfaction (D6); if someone participated, Celebrity gains +1 Skill & +150 VIN. Complete/finish as needed. |

**Passive perk (no button):** After buying any **hi-tech item**, the Celebrity receives **30% of its price back next round**. See “Hi-tech cashback” below for rules that apply to all levels.

### Level 2 – One button

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Meet & Greet** | Level action. Run the Meet & Greet. | **Implemented** (or partly) | `actionId`: `CELEB_L2_MEET_GREET`. Cost: 1 AP & 200 VIN. Effects: each participant +1 Knowledge & +1 Satisfaction; Celebrity +3 or +5 Satisfaction (D6); if no one joins, Celebrity loses 2 or 4 Satisfaction. |

**Passive perk (no button):** After buying any hi-tech item, receive **50% of its price back next round** (same cashback system; percentage depends on level at purchase).

**Obligation:** The player **must play at least 1 event card per turn**. The **Celebrity level action** (e.g. Meet & Greet) **counts as one** event for this obligation. If the obligation is not met (fewer than 1 “event” that turn), the player **loses 3 Satisfaction**. Apply this “additional rule” at end of turn (or wherever turn obligations are checked).

### Level 3 – One button

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Extended Charity Stream** | Level action. Run the charity stream. | **Partly implemented** | `actionId`: `CELEB_L3_CHARITY_STREAM`. Cost: 2 AP. Effects: per donation, donor +2 Satisfaction; Celebrity +2 Satisfaction & +1 AP obligation; Celebrity receives no money. Complete/finish as needed. |

**Passive perk (no button):** After buying any hi-tech item, receive **70% of its price back next round** (same cashback system).

**Obligation:** The player **must play at least 2 event cards per turn**. The **Celebrity level action** (e.g. Charity Stream) **counts as one** of those events. So the player needs at least one more “event” (e.g. an event card) in addition to the level action. **Each missing event** (short of 2) causes a loss of **3 Satisfaction**. Same “additional rule” as Level 2: check at end of turn and apply -3 Satisfaction per missing event.

---

### Celebrity: Hi-tech cashback (all levels) – implementation note

- **Rule:** When a Celebrity buys a hi-tech item, they receive a **refund** of X% of the item’s price **next round**. X = 30% (Level 1), 50% (Level 2), 70% (Level 3).
- **Critical:** The **percentage is fixed by the Celebrity’s level at the time of purchase**, not by their level when the refund is paid.  
  Example: Level 1 Celebrity buys hi-tech this turn; next turn they promote to Level 2. They still receive **30%** back (Level 1 rate), not 50%.
- **Implementation:** Use a **status** (or equivalent) to record **pending refunds**: e.g. when a Celebrity buys hi-tech, store something like `{ color, amount = price * (0.30 or 0.50 or 0.70), levelAtPurchase }`. The **amount** is computed at purchase time from the **current** vocation level, so after promotion the refund stays 30%/50%/70% as at purchase. Next round (start or end, as decided), pay the stored amount(s) to the player and clear the pending refund(s). If multiple hi-tech items are bought in one turn, store multiple pending refunds (or sum per round); each pays out based on level at that purchase.

---

### Celebrity: Obligations summary

| Level | Obligation | Celebrity action counts as | Penalty per missing event |
|-------|------------|----------------------------|----------------------------|
| 2     | At least **1** event card per turn | Yes (counts as 1) | -3 Satisfaction |
| 3     | At least **2** event cards per turn | Yes (counts as 1; need 1 more) | -3 Satisfaction per missing |

Check at end of turn (or in the same place other “additional rules” are applied); apply -3 Satisfaction for each event short of the required count.

---

## Part 3. Entrepreneur

### Level 1 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Flash Sale Promotion** | Level action. Run the flash sale promotion. | **Partly implemented** | `actionId`: `ENT_L1_FLASH_SALE`. Cost: 1 AP. Current: all players may buy one Consumable with 30% discount; Entrepreneur +1 Satisfaction per buyer. Complete as needed. |
| 2 | **Talk to shop owner** | Special ability. **Spend 1 AP** to talk to the shop owner → **all other players pay double prices in the shop for one turn.** | **To implement** | Entrepreneur raises shop prices for everyone else only (not for themselves). Duration: one turn. Track “double prices for others” in ShopEngine (e.g. flag or status until end of current turn / start of next). |

**Passive (no button):** See “Richest player Satisfaction” below (Level 1 and 2: +1 Sat when Entrepreneur has highest money at end of their turn).

### Level 2 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Commercial training course** | Level action. Run the commercial training course. | **Partly implemented** | `actionId`: `ENT_L2_TRAINING`. Cost: 2 AP. Participants, exam roll, rewards (Knowledge/Skill). Complete as needed. |
| 2 | **Use your network** | Passive (no button). On every die roll during their turn (vocation, shop, events), Entrepreneur may choose **Reroll** (1 AP, once) or **Go on**. | **Fully implemented** | In practice, dice are almost always rolled during the active player’s turn, so limiting to “during your turn” and “only Entrepreneur” keeps implementation straightforward: no need to support another player asking the Entrepreneur to enable a reroll. Store a “pending reroll” when the ability is used; on the **Entrepreneur’s next die roll that turn**, show “Reroll?” and use second result if they choose. Clear the pending reroll after use or at end of turn. |

**Passive (no button):** Richest player Satisfaction (same as Level 1): +1 Sat when Entrepreneur has highest money at end of their turn.

### Level 3 – One button + passive perks

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Reposition event cards** | Special ability. **During your turn, spend 2 AP** to change the position of **up to 3 event cards** in the **event lane**. The player may reorder/shuﬀle 3 out of the 7 open cards as they wish. | **To implement** | Needs integration with Event Lane / Events Controller: which object holds the 7 open cards, how positions are defined, and an UI or flow to “pick up to 3 cards and place them in new positions” (swap/reorder). |

**Passive (no button):**  
- **Property discount:** Entrepreneur gets **25% discount on properties**. This **stacks** with discount cards/tokens (e.g. discount token + this passive = combined discount). Apply wherever property purchase price is calculated.  
- **Richest player Satisfaction:** When the Entrepreneur **ends their turn**, check who has the **highest amount of money**. If the Entrepreneur does, they gain **+2 Satisfaction** (at Level 3; at Level 1 and 2 it is +1 – see below).

---

### Entrepreneur: Richest player Satisfaction (passive, all levels)

- **When:** When the **Entrepreneur ends their turn** (end-of-turn check).
- **Check:** Compare money of all players; if the **Entrepreneur has the highest** amount:
  - **Level 1 or 2:** gain **+1 Satisfaction**.
  - **Level 3:** gain **+2 Satisfaction**.
- **Implementation:** In Turn Controller (or wherever “turn end” is processed), after the Entrepreneur’s turn ends: get all players’ money, find max, if Entrepreneur is sole or tied for max give the appropriate Satisfaction. Ties: clarify whether “highest” means strictly more than everyone or tied-for-first counts; if tied, document and implement consistently.

---

### Entrepreneur: Reroll ability (Level 2) – implementation note

- **Scope:** Only the **Entrepreneur** benefits; the reroll is only valid **during their turn**. (There is no support for “another player asks the Entrepreneur” to enable a reroll.)
- **Implementation:** When the Entrepreneur uses the ability (spend 1 AP), set a “pending reroll” flag for that color. On the **Entrepreneur’s next die roll during that same turn** (vocation action, training exam, event, etc.), before applying the result, show a prompt: “Use network reroll?” If yes, roll again and use the second result. Clear the pending reroll after use or at end of turn. This avoids dealing with other players’ rolls and keeps the flow simple.

---

## Part 4. Public Servant

**Button layout:** Each level has two buttons: (1) tax campaign (level action), (2) level perk (free card for the whole game). Level perks are under construction; tax campaigns are implemented.

### Level 1 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Income Tax Campaign** | Level action. Run the income tax collection campaign (die roll: fail / 15% / 30% of cash from each player). | **Implemented** | `actionId`: `PS_L1_INCOME_TAX`. Cost: 2 AP. Die roll determines outcome. |
| 2 | **Health Monitor Access** | Level perk. **Free access to the Health Monitor for the whole game** – one physical card (e.g. template 026d01) is moved to the Public Servant’s board; same use as shop Health Monitor. | **Under construction** | `actionId`: `PS_PERK_HEALTH_MONITOR_ACCESS`. Button is hidden once the card is already on their board. ShopEngine: move (not clone) card, track owner, block if they already bought Health Monitor from shop. |

### Level 2 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Hi-Tech Tax Campaign** | Level action. Run the hi-tech tax collection campaign (die roll: fail / 200 VIN per hi-tech / 400 VIN per hi-tech from each player). | **Implemented** | `actionId`: `PS_L2_HITECH_TAX`. Cost: 2 AP. |
| 2 | **Anti-burglary Alarm** | Level perk. Free **Anti-burglary Alarm** for the whole game (same effect as the shop hi-tech item – theft protection). | **Under construction** | Same pattern as Health Monitor Access: one card moved to board, ownership tracked. Event Engine must check ALARM on theft (e.g. `wounded_steal`) before applying steal. |

### Level 3 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Property Tax Campaign** | Level action. Run the property tax collection campaign (die roll: fail / 200 VIN per property level / 400 VIN per property level from each player). | **Implemented** | `actionId`: `PS_L3_PROPERTY_TAX`. Cost: 2 AP. |
| 2 | **New Car** | Level perk. Free **Car** for the whole game (same effect as shop hi-tech – e.g. free shop/estate entry, event cards -1 AP). | **Under construction** | Same pattern as other level perks: one card to board, ownership tracked. Integrate with shop entry and Event Engine where CAR is checked. |

---

### Public Servant: Passive and automatic rules (no buttons)

| Rule | Description | Implementation status | Implementation notes |
|------|-------------|------------------------|------------------------|
| **Consumable discount** | **Constant 50% discount on all consumable cards** (in the shop). | **To implement** | Apply in ShopEngine when Public Servant buys a consumable: reduce price by 50%. No button; always on. |
| **Waive first tax obligation (per level)** | **Once per level**, due to mastery of administrative law, the Public Servant may **waive their own tax obligation**. Implemented as **automatic**: the **first** tax obligation affecting the Public Servant each level is waived. | **To implement** | No button; automatic. When a tax obligation would apply to the Public Servant (e.g. from tax campaign, or other tax events), if it is the first such obligation this level, cancel it for them. Track “tax obligations waived this level” per color per level. |
| **Work obligation** | Public Servant must work **2 to 4 Action Points per year** (2–4 work tokens on their board). Check at end of year (or when “year” is evaluated). | **To implement** | See “Work obligation by level” below. Count work AP/tokens for the year; if outside 2–4 range, apply penalties. |

---

### Public Servant: Work obligation by level

Each year the Public Servant must have **exactly 2, 3, or 4** work AP (work tokens) on their board. “Missing” = fewer than 2; “extra” = more than 4.

| Level | If condition not met (outside 2–4 work AP) | Implementation notes |
|-------|-------------------------------------------|------------------------|
| **1** | Do **not** receive an **experience token** this year and **cannot be promoted**. | Check at year end (or when experience/promotion is awarded). Block experience and promotion for that year only. |
| **2** | For **each missing or extra** AP (outside 2–4): lose **1 Satisfaction**. Do **not** get experience point this year. | Same work count; for each AP short of 2 or over 4, -1 Sat; no experience that year. |
| **3** | For **each missing or extra** AP: lose **2 Satisfaction**. **Cannot gain an award** this year. | Same work count; for each AP short of 2 or over 4, -2 Sat; block awards. **Note:** Special awards are not implemented yet; document and implement when the award system exists. |

---

## Part 5. Gangster

**Button layout:** Two buttons per level: (1) crime action (vs shop / false money / lockdown), (2) crime against player. Additional satisfaction and victim impact (see below) apply after success and are to be implemented.

### Level 1 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Crime action: Steal hi-tech from shop** | Spend **3 AP**. Roll die: **1–2** failure (nothing); **3–4** partial success (police can investigate); **5–6** full success (police can’t start investigation). Still a crime → raises Heat. | **To implement** | New button/action. No “victim”; target is the shop. Heat/Investigation as per existing crime flow. |
| 2 | **Crime against player (Lv1)** | Choose target; spend AP; roll die. **5–6** full success: target gets WOUNDED, gangster steals **one hi-tech item OR 500 VIN**. Partial success: wound + lower steal. | **Partly implemented** | `actionId`: `GANG_L1_CRIME`. Current: 2 AP, die 1–2 fail, 3–4 partial (300 VIN), 5–6 full (500 VIN or hi-tech). **Hi-tech choice UI** (see below) and **victim impact** (see below) to be added. |

### Level 2 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Crime action: False money production** | Roll die: **1–2** failure (nothing); **3–4** success → gangster gains **1000 VIN**; **5–6** great success → **2000 VIN**. Crime → raises Heat. | **To implement** | New button/action. No victim; Heat as per crime. |
| 2 | **Crime against player (Lv2)** | Same as Lv1 pattern. Full success (5–6): target WOUNDED, gangster steals **one hi-tech item OR 1000 VIN**. | **Partly implemented** | `actionId`: `GANG_L2_CRIME`. Same hi-tech choice UI and victim impact as Lv1. |

### Level 3 – Two buttons

| # | Button label | Description | Implementation status | Implementation notes |
|---|--------------|-------------|------------------------|------------------------|
| 1 | **Crime action: Enforce citywide lockdown** | Spend **2 AP**. Effect: **all opponents** start their next turn with **-1 AP** (1 AP of each moved to inactive). Then gangster rolls die: **1–2** → +200 VIN; **3–4** → +500 VIN; **5–6** → +1000 VIN and **+2 Satisfaction**. Crime → raises Heat. | **To implement** | New button/action. Apply “opponents -1 AP at start of next turn” in Turn Controller (or equivalent). Heat as per crime. |
| 2 | **Crime against player (Lv3)** | Same pattern. Full success (5–6): target WOUNDED, gangster steals **one hi-tech item OR 2000 VIN**. | **Partly implemented** | `actionId`: `GANG_L3_CRIME`. Same hi-tech choice UI and victim impact. |

---

### Gangster: Hi-tech vs money choice (crime against player, full success only)

When the **victim has at least one hi-tech item** and the gangster gets **full success** (5–6), the gangster must choose: take **one** hi-tech item **or** take the money. Implement via UI on the victim’s hi-tech cards:

- On **each** of the victim’s hi-tech items, show **two buttons**: **“Take the item”** and **“Take money”**.
- **Only the first selection counts.** As soon as the gangster (or designated chooser) clicks one option on **any** of those cards:
  - If “Take the item”: that item is transferred to the gangster; no money is taken.
  - If “Take money”: gangster takes the VIN amount (500 / 1000 / 2000 by level); no item is taken.
- **Immediately after that first click**, remove **all** such buttons and consider the action finished. No second choice.

If the victim has **no** hi-tech item, do **not** show buttons; the gangster takes the money automatically.

---

### Gangster: Additional satisfaction (all 6 actions) – after successful crime

After **any** of the six Gangster summary actions finishes **successfully** (roll 3 or more / crime resolved with effect), the **gangster** gets one extra die roll. The **result of that die = +Satisfaction** for the gangster (e.g. roll 4 → +4 Satisfaction).

- **Implementation:** Use **UI** so it is not missed. After the successful crime is fully resolved, show a screen with a button such as **“Roll die after successful crime”** (or “Roll your die to add satisfaction”). On click, roll the die once and add the result to the gangster’s Satisfaction. This applies to all six actions (three crime actions + three crime-against-player actions).

---

### Gangster: Victim impact (only the 3 “crime against player” actions)

**Scope:** Only the three **Gangster summary** “crime against player” actions (Lv1, Lv2, Lv3). **Does not** apply to crime from event cards (e.g. adult deck “crime against player” cards).

When a **crime against player** from the Gangster summary is **successful** (target wounded / steal applied), the **victim** rolls a die:

- **1, 2, or 3:** victim loses **3 Satisfaction**.
- **4, 5, or 6:** victim loses **5 Satisfaction**.

Implement after the crime resolution (and after hi-tech/money choice if applicable). Optionally use a small UI so the victim explicitly rolls and the result is applied.

---

## Part 6. NGO Worker

**Button layout:** Social campaigns (one per level), level perks (one per level), and one **Voluntary work** button (same label on every level; effect depends on level). Voluntary work is easy to implement.

### Social campaigns (level actions)

| Level | Button label | Description | Implementation status | Implementation notes |
|-------|--------------|-------------|------------------------|------------------------|
| 1 | **Charity campaign** | Start Charity. Roll die; 1–2 nothing, 3–4 each pays 200, 5–6 each pays 400 (initiator may get reward). | **Implemented** | `actionId`: `NGO_L1_CHARITY`. Cost: 2 AP. |
| 2 | **Crowdfunding campaign** | Start crowdfunding; other players help finance it. You **must immediately** spend the money in the shop to buy **one hi-tech item**. | **Partly implemented** | `actionId`: `NGO_L2_CROWDFUND`. Cost: **2 AP** for campaign. Die: **1–2** nothing; **3–4** each player pays you **250** (only if they have it); **5–6** each pays **400**. You receive a money pool (e.g. up to 1000–1200). **Immediately** use it to buy **one** hi-tech from the **three open cards** in the shop. **To complete:** After the die roll, show **buttons on the three open hi-tech cards** in the shop – player must buy one of those. If item is cheaper than pool, rest is lost. If item is more expensive, player pays the difference from their own money. If they don’t buy any hi-tech, all crowdfunding money is lost. Going to the shop costs **1 AP** (per normal shop entry). |
| 3 | **Advocacy / pressure campaign** | Advocacy Pressure Campaign. | **Implemented** | `actionId`: `NGO_L3_ADVOCACY`. Cost: 3 AP. |

### Level perks (once per level, on your turn)

| Level | Button label | Description | Implementation status | Implementation notes |
|-------|--------------|-------------|------------------------|------------------------|
| 1 | **Take Good Karma (free)** | Once per level, on your turn you can take **one Good Karma card** without spending time or money. You must see the card (in the shop as consumable, or in the adult event deck). The card is used; you gain a **Good Karma token**. | **To implement** | Button: e.g. “Take Good Karma (free, once per level)”. When used: if a Good Karma card is visible (shop consumable row or adult deck), mark it used and grant one Good Karma token to the NGO Worker. Track “used this level” per level. |
| 2 | **Take Trip (free)** | Once per level, on your turn you can take **one Trip card** without spending time or money. If you see a Trip card (e.g. consumable shelf in the shop), use it for free and get the full benefits. | **Implemented** | `actionId`: `NGO_L2_TAKE_TRIP`. Button shows "Take this Trip (free)" on each visible Trip card in shop; player picks one, effect applied (rest + die for SAT), perk marked used. Tracks once per level via `ngoTakeTripUsedPerLevel`. |
| 3 | **Use Investment (free, up to 1000 VIN)** | Once per level, on your turn you can **use one Investment card** without spending time or money, with a **limit of 1000 VIN** from this perk. You can add your own money if you want to invest more. | **To implement** | Button: use one Investment card; up to 1000 VIN comes from the perk, any extra from player’s money. Track once per level. |

### Voluntary work (one button, same on every level – effect depends on level)

| Level | Cost | Effect |
|-------|------|--------|
| 1 | **2 AP** | Gain **1 Satisfaction**. |
| 2 | **3 AP** | Gain **2 Satisfaction**. |
| 3 | **1 AP** | Gain **1 Satisfaction**. |

- **Implementation:** One button, e.g. **“Voluntary work”**, shown for NGO Worker at any level. On click, deduct the AP for the current level (2 / 3 / 1) and add the corresponding Satisfaction. Very easy to implement.

---

## Reference: Good Karma (existing system)

- **Good Karma token:** Used when playing an **obligatory** event card. The player may choose “Use Good Karma to avoid results of this card?”; if YES, the card is skipped without effects and one Good Karma token is consumed.
- **Granting a token:** Done via Player Status Controller / Token Engine (e.g. `PS_Event` ADD_STATUS for the Good Karma status, or the test “+ Good Karma” path). The Social Worker Level 1 perk button should call the same kind of “add Good Karma for this player” once per click.

---

*Document created for vocation summary UI documentation. All six vocations documented: Social Worker, Celebrity, Entrepreneur, Public Servant, Gangster, NGO Worker.*
