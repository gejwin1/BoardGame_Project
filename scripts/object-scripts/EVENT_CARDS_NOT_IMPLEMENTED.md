# Event Cards – What Is Not Fully Implemented Yet

Based on `7b92b3_EventEngine.lua` (CARD_TYPE map + TYPES with `todo=true` or notes). **Vocational events (VE) are excluded** as requested; only Youth (YD_) and Adult (AD_) non-VE gaps are listed.

---

## Youth deck (YD_) – status

**All mapped youth event cards are implemented.** There are no `todo=true` or “not implemented” notes on any Youth type.

Mapped types: DATE, PARTY, VOLUNTARY, MENTORSHIP, BEAUTY, BIRTHDAY, WORK1_150–WORK5_500, VOUCH_HI, VOUCH_CONS, SICK_O, LOAN_O, KARMA. All have full logic (AP, money, stats, dice, voucher token grant, obligatory, etc.).

---

## Adult deck (AD_) – non‑VE gaps

### 1. Property voucher card (AD_VOUCH_PROP)

| Item | Value |
|------|--------|
| **Type key** | `AD_VOUCH_PROP` |
| **Card IDs** | AD_42, AD_43 (mapRange AD_ 42–43 "_VOUCH-PROP") |
| **In code** | `TYPES.AD_VOUCH_PROP` has `todo=true` and note: *"Property purchase system not implemented yet"* |
| **What actually runs** | The voucher block in EventEngine **does** add the property voucher token (`STATUS_TAG.VOUCH_P`) and finalize the card. EstateEngine **does** apply the 20% property discount when buying L1–L4 with voucher. So: **token grant + discount are implemented.** |
| **Conclusion** | Likely only the `todo`/note are outdated. If property voucher flow works in playtests, you can remove `todo=true` and the note from `AD_VOUCH_PROP` in EventEngine. No new logic needed unless something is still missing in game design. |

---

## Adult deck – vocational events (VE) – summary

You asked to exclude these from the “what still needs implementation” list; they are only summarised here.

- **Types:** `AD_VE_NGO2_SOC1`, `AD_VE_NGO1_GAN1`, `AD_VE_NGO1_ENT1`, `AD_VE_NGO2_CEL1`, `AD_VE_SOC2_CEL1`, `AD_VE_SOC1_PUB1`, `AD_VE_GAN1_PUB2`, `AD_VE_ENT1_PUB1`, `AD_VE_CEL2_PUB2`, `AD_VE_CEL2_GAN2`, `AD_VE_ENT2_GAN2`, `AD_VE_ENT2_SOC2`.
- **Card IDs:** AD_58–AD_81 (pairs per type).
- **In code:** All have `todo=true` and `ve={a="...", b="..."}`. When played, they open a choice (side A or B) but the **vocation effect** (granting vocation points / applying the chosen side) is not implemented.
- These are the “huge amount of vocational events” you already know about; no further breakdown here.

---

## Summary table (non‑VE only)

| Deck | Card(s) | Type | Status |
|------|---------|------|--------|
| Youth | All mapped YD_ | — | Implemented |
| Adult | AD_42, AD_43 | AD_VOUCH_PROP | Marked `todo` + note; token + Estate discount already in code → likely just remove `todo`/note if tests are OK |
| Adult | AD_58–AD_81 | AD_VE_* (12 types) | Excluded per request; vocational logic not implemented |

So **besides vocational events**, the only event cards that still have a “not fully implemented” marker in code are the **two property voucher cards (AD_42, AD_43)**; the actual behaviour (grant token + 20% property discount) is already there, so they may only need the `todo`/note cleaned up after you confirm in testing.
