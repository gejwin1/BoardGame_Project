# Call for Auction – audit vs AUCTION_IMPLEMENTATION_GUIDE.md

## What the guide requires (KROK 0–11)

| KROK | Requirement | Current status |
|------|-------------|----------------|
| 0 | One backend (EventsController) | ✅ Logic in EventsController |
| 1 | auctionState with active, state, participants, deposits, currentPrice, currentBidderColor, leaderColor, activeBidders, etc. | ✅ Present |
| 2 | EventEngine: check L2 available (EstateEngine), then call EventsController `Auction_Start`; return DONE | ⚠️ **Missing L2 check** – we call Auction_Start without verifying L2 |
| 3 | EventsController: before JOINING, check L2; reject if auction already active | ✅ Reject second auction; ⚠️ no L2 check in Auction_Start |
| 4 | Card on L2 position, lock, one button "Pay 500 & Join", description "Joined: …" | ✅ |
| 5 | Join: 500 WIN, participants/deposits, only in JOINING, optional "only in your turn" | ✅ (only current turn can join) |
| 6 | BIDDING start only when initiator's turn again (no timers). TurnController calls `Auction_OnTurnStart(activeColor)`. | ✅ TurnController calls; we use **one round** (first initiator turn = BIDDING) per user request |
| 7 | JOINING→BIDDING: clear card buttons, build activeBidders from participants in turn order, call **Global** `UI_AuctionShow(snapshot)` | ✅ Clear buttons; ✅ build queue; ⚠️ **Global must be findable** – if not, panel never shows |
| 8 | Global UI: panel with status, price, bidder, Bid/Pass; Global calls EventsController `Auction_OnBid` / `Auction_OnPass`; EVENTS_CTRL_GUID in Global | ✅ XML and Global handlers exist; ✅ EVENTS_CTRL_GUID |
| 9 | Bid/Pass validated in EventsController; after each action `UI_AuctionUpdate(snapshot)` | ✅ |
| 10 | RESOLVED: 1 participant → Buy 1500 / Decline; 2+ → winner pays currentPrice−500, others refund | ✅ |
| 11 | Cleanup: active=false, UI_AuctionHide, clearButtons, card to used, unlock | ✅ |

## Root cause: auction panel not showing

The guide says: EventsController calls **Global** (the object that has the Global script) to run `UI_AuctionShow(snapshot)`. In TTS there is no built-in `Global` reference from another object; we must **resolve the Global object** by:

1. **Registration** – Global’s `onLoad` calls `Auction_RegisterGlobal({ guid = self.getGUID() })`. If `self` is nil in Global context or Global loads before EventsController, this can fail.
2. **EVT_GLOBAL_GUID** – Set in EventsController to the GUID of the object that has the Global script. Often left empty.
3. **Tag WLB_GLOBAL** – The object that has the Global script (and Global UI XML) must have tag **WLB_GLOBAL** so EventsController can find it with `hasTag(TAG_EVT_GLOBAL)`.

**Correct fix:** EventsController uses the built-in **`Global`** reference (as in TurnController): `Global.call("UI_AuctionShow", snapshot)`. No tag or GUID needed – TTS provides `Global` to object scripts.

## Implementation fixes applied

1. **AUCTION_IMPLEMENTATION_GUIDE.md** – Add a short “Setup” section: add tag **WLB_GLOBAL** to the object that has the Global script (and the Global UI XML).
2. **EventEngine** – (Optional) Add L2 availability check before `Auction_Start` if EstateEngine exposes e.g. `HasAvailableL2()`; otherwise leave as-is and note in guide.
3. **EventsController** – No logic change; already clears card buttons for BIDDING and calls `auctionUINotifyShow()`. Ensure `TAG_EVT_GLOBAL = "WLB_GLOBAL"` and that we try tag lookup.
4. **Global** – Already has `UI_AuctionShow`, `UI_AuctionUpdate`, `UI_AuctionHide`, `UI_AuctionBid`, `UI_AuctionPass` and `EVENTS_CTRL_GUID`. Ensure Global UI XML is on the **same** object as the Global script (same as vocation UI).

## Summary

- **Why the panel didn’t show:** EventsController could not find the Global object (no registration, no EVT_GLOBAL_GUID, no tag on the Global object).
- **What to do in TTS:** Nothing – use built-in `Global.call(...)`. Ensure Global script and Global UI are in TTS Global script/UI tabs.
