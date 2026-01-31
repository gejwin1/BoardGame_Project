# Child-Blocked AP Tracking System

## 📋 Overview

This system tracks which Action Points in INACTIVE come from children (permanent) vs other sources (temporary like addiction). This allows cards to selectively remove specific types of blocked AP.

**Version:** v0.4.0 (Player Status Controller)

---

## 🎯 Purpose

- **Children block AP permanently** - They stay with the player, so their AP block is permanent
- **Other sources block AP temporarily** - Addiction, etc. are temporary
- **Selective unblocking** - Some cards can remove only child-blocked AP, others can remove only non-child-blocked AP

---

## 🔧 How It Works

### 1. Automatic Tracking

When a child is created (via `PS_Event({op="ADD_CHILD"})`):
- Player Status Controller automatically tracks **+2 child-blocked AP** for that player
- This happens in `ADD_CHILD` operation handler

### 2. AP Movement

**Shop Engine (FAMILY cards):**
- When child is created: Moves 2 AP to INACTIVE immediately
- Player Status Controller tracks this as child-blocked

**Event Engine (end-of-round):**
- Applies child AP blocking at end of round: `(apBlock - childUnlock[color])` AP moved to INACTIVE
- This is also tracked as child-blocked (permanent)

### 3. State Persistence

- Child-blocked AP counts are saved/loaded via `onSave()`/`onLoad()` in Player Status Controller
- Persists across game saves

---

## 📡 APIs

### `PS_GetChildBlockedAP(params)`
Returns count of AP permanently blocked by children.

**Parameters:**
- `{color="Yellow"}` or just `"Yellow"`

**Returns:** Number (0-12, typically 0, 2, 4, 6...)

**Example:**
```lua
local psc = findPlayerStatusController()
local blocked = psc.call("PS_GetChildBlockedAP", {color="Blue"})
-- Returns: 2 (if Blue has 1 child), 4 (if 2 children), etc.
```

### `PS_RemoveChildBlockedAP(params)`
Removes child-blocked AP (for cards that can unblock it).

**Parameters:**
- `{color="Yellow", amount=2}`

**Returns:** `true` if any AP was removed, `false` otherwise

**Example:**
```lua
local psc = findPlayerStatusController()
local ok = psc.call("PS_RemoveChildBlockedAP", {color="Blue", amount=2})
-- Removes 2 child-blocked AP from Blue's count
-- Note: This only updates the tracking, doesn't move AP back from INACTIVE
```

### `PS_GetNonChildBlockedAP(params)`
Returns count of INACTIVE AP that is NOT from children (for cards that can unblock other sources).

**Parameters:**
- `{color="Yellow"}`

**Returns:** Number (count of INACTIVE AP minus child-blocked AP)

**Example:**
```lua
local psc = findPlayerStatusController()
local otherBlocked = psc.call("PS_GetNonChildBlockedAP", {color="Blue"})
-- Returns: 3 (if Blue has 5 INACTIVE total, 2 child-blocked = 3 other-blocked)
```

---

## 🔄 Integration Points

### Shop Engine (FAMILY cards)
- ✅ Already moves 2 AP to INACTIVE when child is created
- ✅ Player Status Controller automatically tracks this when `pscAddChild()` is called

### Event Engine (end-of-round)
- ✅ Already applies child AP blocking at end of round
- ⚠️ **TODO:** Event Engine should also track this as child-blocked when it applies the block

### Future Cards
- Cards that remove child-blocked AP: Use `PS_RemoveChildBlockedAP()` then move AP back from INACTIVE
- Cards that remove other-blocked AP: Use `PS_GetNonChildBlockedAP()` to find removable AP, then move it back

---

## 📊 State Structure

```lua
childBlockedAP = {
  Yellow = 0,  -- AP permanently blocked by children
  Blue = 2,     -- Example: 1 child = 2 AP blocked
  Red = 4,      -- Example: 2 children = 4 AP blocked
  Green = 0
}
```

---

## ⚠️ Important Notes

1. **Child-blocked AP is permanent** - It stays until the child is removed (if that mechanic exists)
   - ✅ **No `duration` parameter** = Permanent blocking (children)
   - ✅ **`duration=1` parameter** = Temporary blocking (events like Birthday, Marriage)
2. **Tracking is separate from AP Controller** - AP Controller just tracks total INACTIVE count
3. **Manual coordination required** - When removing child-blocked AP:
   - Call `PS_RemoveChildBlockedAP()` to update tracking
   - Call AP Controller `moveAP({to="START", amount=N})` to actually move AP back
4. **Duration-based release** - AP Controller's `WLB_END_TURN` hook should release AP with `duration=1` after turn ends, but leave AP without duration permanent. This behavior must be verified in AP Controller implementation.

## 🔄 Cooperation with Turn Controller

**Turn Controller calls `Global.WLB_END_TURN({color})` at end of each turn.**

**Expected behavior:**
- AP with `duration=1` should be automatically released (returned to START)
- AP without `duration` should remain in INACTIVE (permanent)

**Current implementation:**
- ✅ **Event-based temporary blocking** (Birthday, Marriage): Uses `duration=1` → Released after turn
- ✅ **Child-based permanent blocking** (FAMILY cards, Event Engine end-of-round): No `duration` → Stays permanent

**⚠️ Verification needed:** Confirm that AP Controller's `WLB_END_TURN` implementation respects the `duration` parameter and only releases temporary AP, leaving permanent child-blocked AP untouched.

---

## 🚀 Future Enhancements

1. **Event Engine integration** - Update Event Engine's `applyEndOfRoundForColor()` to track child-blocked AP
2. **Child removal** - If children can be removed, add `PS_RemoveChild()` that also reduces child-blocked AP
3. **API for moving AP back** - Helper function that combines `PS_RemoveChildBlockedAP()` + AP Controller `moveAP()`
