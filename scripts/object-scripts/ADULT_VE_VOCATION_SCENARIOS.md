# Adult Vocation Event Cards (AD_VE) — Vocation Scenario Specifications

**Purpose:** Reference for implementing the 24 AD_VE cards (AD_58–AD_81).  
Each card has: (1) **Crime** (upper) — 1 AP, dice, everyone can play; (2) **Vocation choice** (bottom) — only one of two vocation actions can be played (option A or B).

Vocation codes in code: `NGO1`, `NGO2`, `SOC1`, `SOC2`, `GAN1`, `GAN2`, `ENT1`, `ENT2`, `CEL1`, `CEL2`, `PUB1`, `PUB2`.

---

## GANGSTER (GAN)

### GAN1 — "Robin Hood Job"
- **Cost:** 2 AP
- **Target:** Choose any player with at least 500 WIN
- **Effect (roll 1d6):**
  - **1–2** → Plan leaks. You pay 200 WIN to bank, lose 2 SAT.
  - **3–4** → Steal and donate 500 WIN from target (they lose 500; money removed). You +5 SAT.
  - **5–6** → Steal and donate 1,000 WIN from target (or all they have if less). You +8 SAT.
- **Note:** Gangster never keeps money — only satisfaction.

### GAN2 — "Protection Racket"
- **Cost:** 3 AP
- **Story:** Each other player must choose: Pay or Refuse.
- **Option A — Pay for protection:** Player pays 200 WIN × their vocation level (L1=200, L2=400, L3=600). Gangster keeps all money; gangster +2 SAT per paying player; payer has no penalty.
- **Option B — Refuse:** Player loses −2 SAT, −3 Health. Gangster gains no SAT from refusing players.

---

## SOCIAL WORKER (SOC)

### SOC1 — "Homeless Shelter Breakthrough"
- **Cost:** 2 AP + 100 WIN
- **Effect (roll 1d6):**
  - **1–2** → They leave. You −1 SAT.
  - **3–4** → Temporary shelter. You +3 SAT.
  - **5–6** → Long-term support. You +7 SAT, +1 Skill.

### SOC2 — "Forced Protective Removal"
- **Cost:** 3 AP
- **Target:** Choose a player who has at least one child
- **Effect (roll 1d6):**
  - **1–2** → False alarm. You −2 SAT, −1 Health. Target +3 SAT.
  - **3–4** → Temporary removal (1 turn). Parent: 0 SAT from child, still pays cost, no AP on child, −2 SAT. You +2 SAT. Child returns end of next turn.
  - **5–6** → Permanent removal. Parent −6 SAT; you +4 SAT; parent no longer pays cost / AP / SAT from that child.

---

## PUBLIC SERVANT (PUB)

### PUB1 — "Policy Drafting Deadline"
- **Cost:** 2 AP
- **Effect (deterministic):** −1 Health, +6 SAT, +1 Knowledge.

### PUB2 — "Bureaucratic Bottleneck"
- **Cost:** 3 AP
- **Effect (roll 1d6):**
  - **1–2** → System collapse. All other players −2 AP next turn. You −2 SAT.
  - **3–4** → No effect.
  - **5–6** → Full reform. All other players +2 SAT. You +7 SAT.

---

## NGO WORKER (NGO)

### NGO1 — "International Crisis Appeal"
- **Cost:** 1 AP + 200 WIN
- **Effect:** Each other player chooses:
  - **Donate 200 WIN** → They +2 SAT; you +2 SAT per donating player.
  - **Ignore** → They 0 SAT; you +1 SAT.

### NGO2 — "Misused Donation Scandal"
- **Cost:** 2 AP + 300 WIN
- **Effect:** Pay 300 WIN, then roll 1d6:
  - **1–2** → Public accusation. You −3 SAT.
  - **3–4** → Resolved quietly. You +4 SAT.
  - **5–6** → Donor apologizes publicly. You +6 SAT, +1 Knowledge.

---

## ENTREPRENEUR (ENT)

### ENT1 — "Aggressive Expansion"
- **Cost:** 3 AP + 300 WIN
- **Effect (roll 1d6):**
  - **1–2** → Collapse. −3 SAT, −200 WIN.
  - **3–4** → Moderate growth. +4 SAT.
  - **5–6** → Massive growth. +8 SAT, +800 WIN.

### ENT2 — "Employee Training Boost"
- **Cost:** 2 AP + 500 WIN
- **Effect (deterministic):** +2 Skills, +2 SAT.

---

## CELEBRITY (CEL)

### CEL1 — "Fan Talent Collaboration"
- **Cost:** 3 AP + 300 WIN
- **Effect (always):** You +4 SAT, +1 Skill.
- **Helpers:** Any number of other players may spend 2 AP each → each helper +1 Knowledge, +2 SAT; you +2 SAT (once total).

### CEL2 — "Fan Meetup Backfire"
- **Cost:** 2 AP + 200 WIN
- **Effect (roll 1d6):**
  - **1–2** → Chaos. −3 SAT, −1 Health.
  - **3–4** → Modest success. +3 SAT.
  - **5–6** → Overwhelming love. +7 SAT, +300 WIN.

---

## Card ↔ Vocation mapping (already in EventEngine)

| Card type           | Option A | Option B |
|---------------------|----------|----------|
| AD_VE_NGO2_SOC1     | NGO2     | SOC1     |
| AD_VE_NGO1_GAN1     | NGO1     | GAN1     |
| AD_VE_NGO1_ENT1     | NGO1     | ENT1     |
| AD_VE_NGO2_CEL1     | NGO2     | CEL1     |
| AD_VE_SOC2_CEL1     | SOC2     | CEL1     |
| AD_VE_SOC1_PUB1     | SOC1     | PUB1     |
| AD_VE_GAN1_PUB2     | GAN1     | PUB2     |
| AD_VE_ENT1_PUB1     | ENT1     | PUB1     |
| AD_VE_CEL2_PUB2     | CEL2     | PUB2     |
| AD_VE_CEL2_GAN2     | CEL2     | GAN2     |
| AD_VE_ENT2_GAN2     | ENT2     | GAN2     |
| AD_VE_ENT2_SOC2     | ENT2     | SOC2     |

---

## Crime side (upper) — per-card tables

**Target:** Attacker chooses one other player. Roll 1d6; apply WOUNDED when "wounded"; steal = target loses WIN (money removed from game).

| Card type | 1-2 | 3-4 | 5-6 | Crime AP |
|-----------|-----|-----|-----|----------|
| AD_VE_NGO1_ENT1 | Nothing | Wounded | Wounded + 1000 WIN | 1 |
| AD_VE_NGO1_GAN1 | Nothing | Wounded + 250 WIN | Wounded + 600 WIN | 1 |
| AD_VE_NGO2_SOC1 | Nothing | Wounded | Wounded + 1000 WIN | 2 |
| AD_VE_NGO2_CEL1 | Nothing | Wounded + 200 WIN | Wounded + 800 WIN | 2 |
| AD_VE_ENT1_PUB1 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 1 |
| AD_VE_ENT2_GAN2 | Nothing | Wounded | Wounded + 1000 WIN | 1 |
| AD_VE_ENT2_SOC2 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 2 |
| AD_VE_GAN1_PUB2 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 2 |
| AD_VE_CEL2_GAN2 | Nothing | Wounded | Wounded + 1000 WIN | 2 |
| AD_VE_SOC1_PUB1 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 2 |
| AD_VE_SOC2_CEL1 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 1 |
| AD_VE_CEL2_PUB2 | Nothing | Wounded + 200 WIN | Wounded + 500 WIN | 1 |

**Wounded:** Target gets WOUNDED status. **Steal:** Target loses WIN; money removed from game.

 they’## Clarifications (implementation notes)

### GAN2 — "Protection Racket"
- Each other player chooses **Pay** or **Refuse** in turn via UI (like auction).
- **Timeout:** Max **30 seconds** per player; no reaction = **Refuse**.
- **Auto-refuse:** If player cannot pay (200 × vocation level), treat as **Refuse**.

### SOC2 — "Forced Protective Removal"
- **Temporary removal (3-4):** Remove child token from board. After one full turn, child returns.
- **Permanent removal (5-6):** Child removed; parent stops cost/AP/SAT for that child.

### PUB2 — "Bureaucratic Bottleneck" (1-2)
- "All other players -2 AP next turn" = each other player **moves 2 AP to INACTIVE** (existing mechanic).

### CEL1 — "Fan Talent Collaboration" (helpers)
- **UI:** Optional "Support (2 AP)" for other players. Spending 2 AP moves them to INACTIVE; helper +1 Knowledge, +2 SAT; celebrity +2 SAT once total.

---

**Next step:** Implement crime flow + vocation flow + special flows (GAN2, SOC2, PUB2, CEL1) in EventEngine.
