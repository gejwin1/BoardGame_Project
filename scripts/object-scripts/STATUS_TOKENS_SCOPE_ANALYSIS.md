# Status tokens and scope/chunk (comparison with Good Karma fix)

Good Karma stopped working because in the Events Controller, `uiOpenModal` (early in the file) ran in a chunk where the helpers `isCardObligatory` and `hasGoodKarma` were **nil** (they were defined ~850 lines later). TTS can split long scripts into chunks, so "early" code may not see "late" locals.

**Fix that worked:** Move `getEngine`, `getPSC`, `hasGoodKarma`, `consumeGoodKarma`, and `isCardObligatory` to **immediately before** `uiOpenModal` in `1339d3_EventsController.lua`. Good Karma then works.

This note compares that case with **other status tokens** (vouchers, SICK, WOUNDED, ADDICTION, DATING, etc.) in other scripts.

---

## Comparison table

| Script | Status usage | Where helpers are defined | Entry points that use them | Risk |
|--------|--------------|---------------------------|----------------------------|------|
| **Events Controller** | Good Karma (obligatory modal) | Now **before** uiOpenModal (~704–761) | uiOpenModal (~713) | **Fixed** |
| **ShopEngine** | VOUCH_C, VOUCH_H, SICK, WOUNDED, ADDICTION (discounts, removal) | resolvePSC ~992, pscHasStatus etc. ~1240–1291 | Buy/voucher flows ~1959, 2224, 3168, 3421 | **Medium** – if TTS chunks by ~1000 lines, code at 3168/3421 may be in a later chunk and not see pscHasStatus. Preventive fix: move PSC block to start of file (after basic utils). |
| **EstateEngine** | VOUCH_P (property voucher count/remove) | findPSC ~238, pscGetStatusCount/pscRemoveStatusCount ~245–259 | Buy L1–L4 discount flow (later in file) | **Low** – PSC helpers are already in the first ~260 lines. |
| **TurnController** | ADDICTION (count for AP block) | getPlayerStatusController ~269, pscCall ~277, countAddictionTokens ~342 | Turn start hooks (same region) | **Low** – all in the same ~100-line block. |
| **EventEngine** | DATING, ADD_STATUS, MARRIAGE, CHILD (PS_EventCall, hasDatingStatus) | findPlayerStatusCtrl ~221, PS_EventCall ~229, hasDatingStatus ~251 | Card resolution (later) | **Low** – PSC usage is in the first ~320 lines. |

---

## Conclusion

- **Events Controller:** Fixed; Good Karma works.
- **ShopEngine:** Only other script where status helpers are defined far from some call sites (e.g. voucher at 3168/3421). A **preventive** move of the PSC block to early in the file (right after `normalizeBoolResult`) is recommended so voucher and other status logic never hit the same chunk/scope issue.
- **EstateEngine, TurnController, EventEngine:** Helpers are near the top or in the same block as callers; no change required for this reason.
