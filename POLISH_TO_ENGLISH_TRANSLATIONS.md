# Polish to English Translation - Player-Visible Text

This document lists all Polish text visible to players in the game, with proposed English translations for approval.

## 📋 Translation Status: PENDING APPROVAL

---

## 🛒 SHOP ENGINE (d59e04_ShopEngine.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"⛔ ShopEngine: nie znaleziono ShopsBoard"` | `"⛔ ShopEngine: ShopsBoard not found"` | ⏳ |
| `"⚠️ Brak MoneyCtrl — nie mogę dodać "..amount.." WIN."` | `"⚠️ No MoneyCtrl — cannot add "..amount.." WIN."` | ⏳ |
| `"⚠️ Brak MoneyCtrl — nie mogę pobrać "..amount.." WIN."` | `"⚠️ No MoneyCtrl — cannot deduct "..amount.." WIN."` | ⏳ |
| `"⚠️ Brak APCtrl — nie mogę pobrać "..amount.." AP"` | `"⚠️ No APCtrl — cannot deduct "..amount.." AP"` | ⏳ |
| `"⛔ Nie masz AP na pierwszy zakup w sklepie (koszt wejścia 1 AP)."` | `"⛔ You don't have AP for the first shop purchase (entry cost 1 AP)."` | ⏳ |
| `"⚠️ Nie udało się nadać Good Karma (brak PSC albo błąd)."` | `"⚠️ Failed to add Good Karma (no PSC or error)."` | ⏳ |
| `"✅ "..color.." wyleczył uzależnienie! (usunięto "..removed.." tokenów) (rzut="..v..", próg="..riskThreshold..")"` | `"✅ "..color.." cured addiction! (removed "..removed.." tokens) (roll="..v..", threshold="..riskThreshold..")"` | ⏳ |
| `"❌ "..color.." nie udało się wyleczyć uzależnienia (rzut="..v..", próg="..riskThreshold..")"` | `"❌ "..color.." failed to cure addiction (roll="..v..", threshold="..riskThreshold..")"` | ⏳ |
| `"⚠️ "..color.." UZALEŻNIŁ SIĘ od Anti-Sleeping Pills! (dodano 3 tokeny ADDICTION - traci 3/2/1 AP kolejno) (rzut="..v..", próg="..riskThreshold..")"` | `"⚠️ "..color.." became ADDICTED to Anti-Sleeping Pills! (added 3 ADDICTION tokens - loses 3/2/1 AP consecutively) (roll="..v..", threshold="..riskThreshold..")"` | ⏳ |
| `"✅ "..color.." bezpiecznie użył PILLS (rzut="..v..", próg="..riskThreshold..")"` | `"✅ "..color.." safely used PILLS (roll="..v..", threshold="..riskThreshold..")"` | ⏳ |
| `"🩺 Cure: nie masz SICK/WOUNDED → brak efektu."` | `"🩺 Cure: you don't have SICK/WOUNDED → no effect."` | ⏳ |
| `"⛔ Cure (roll="..v..") wymaga 1 AP, ale nie udało się go pobrać → brak leczenia."` | `"⛔ Cure (roll="..v..") requires 1 AP, but failed to deduct → no healing."` | ⏳ |
| `"ℹ️ (WIP) Brak efektu dla: "..tostring(getNameSafe(card))` | `"ℹ️ (WIP) No effect for: "..tostring(getNameSafe(card))` | ⏳ |
| `"⛔ Ta karta nie jest już w slocie OPEN sklepu."` | `"⛔ This card is no longer in an OPEN shop slot."` | ⏳ |
| `"⛔ Na razie programujemy tylko CONSUMABLES (CSHOP)."` | `"⛔ Currently only CONSUMABLES (CSHOP) are implemented."` | ⏳ |
| `"⛔ Nieznana karta CONSUMABLE: "..tostring(name)` | `"⛔ Unknown CONSUMABLE card: "..tostring(name)` | ⏳ |
| `"⛔ Brak AP na koszt karty ("..def.extraAP.." AP)."` | `"⛔ Not enough AP for card cost ("..def.extraAP.." AP)."` | ⏳ |
| `"⛔ Brak środków (WIN) na zakup tej karty."` | `"⛔ Not enough funds (WIN) to purchase this card."` | ⏳ |
| `"🛒 Kupiono: "..tostring(name).." - Roll the die, then click ROLL DICE"` | `"🛒 Purchased: "..tostring(name).." - Roll the die, then click ROLL DICE"` | ⏳ |
| `"🛒 Kupiono: "..tostring(name)` | `"🛒 Purchased: "..tostring(name)` | ⏳ |
| `"⛔ ShopEngine: brakuje talii C/H/I (sprawdź tagi decków)."` | `"⛔ ShopEngine: missing C/H/I decks (check deck tags)."` | ⏳ |
| `"⛔ ShopEngine: brak talii dla "..tostring(row).." (sprawdź tag)."` | `"⛔ ShopEngine: missing deck for "..tostring(row).." (check tag)."` | ⏳ |
| `"✅ DEBUG: +1000 WIN dla "..tostring(target)` | `"✅ DEBUG: +1000 WIN for "..tostring(target)` | ⏳ |

---

## 🔄 TURN CONTROLLER (c9ee1a_TurnController.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"⚠️ "..color.." uzależnienie: -"..addictionCount.." AP do INACTIVE"` | `"⚠️ "..color.." addiction: -"..addictionCount.." AP to INACTIVE"` | ⏳ |
| `"🏁 Koniec: osiągnięto rundę "..MAX_ROUND` | `"🏁 Game Over: reached round "..MAX_ROUND` | ⏳ |
| `"✅ Kolejność:\n"..table.concat(s,"\n")` | `"✅ Turn Order:\n"..table.concat(s,"\n")` | ⏳ |
| `"🎲 Rzut kostką: "..color` | `"🎲 Rolling die: "..color` | ⏳ |
| `"Nie udało się odczytać wartości kostki (getValue)."` | `"Failed to read die value (getValue)."` | ⏳ |
| `"🎲 Wynik: "..color.." = "..v` | `"🎲 Result: "..color.." = "..v` | ⏳ |
| `"✅ ADULT START: użyto rzutów z ustalania kolejności (bez drugiego rzutu)."` | `"✅ ADULT START: used rolls from turn order setup (without second roll)."` | ⏳ |
| `"❌ Brak STATS CTRL dla "..color` | `"❌ No STATS CTRL for "..color` | ⏳ |
| `"❌ "..color..": brak adultStart_apply albo błąd."` | `"❌ "..color..": missing adultStart_apply or error."` | ⏳ |
| `"✅ "..color..": bonusy K="..st.k.." S="..st.s.." zastosowane."` | `"✅ "..color..": bonuses K="..st.k.." S="..st.s.." applied."` | ⏳ |
| `"✅ ADULT START zakończony."` | `"✅ ADULT START completed."` | ⏳ |
| `"⚠️ Auto-PARK Estates: brak MarketController (tag "..TAG_MARKET_CTRL..")."` | `"⚠️ Auto-PARK Estates: no MarketController (tag "..TAG_MARKET_CTRL..")."` | ⏳ |
| `"⚠️ Auto-PARK Estates: MarketController nie ma miRequestPark/miRequestParkAndScan albo call failed."` | `"⚠️ Auto-PARK Estates: MarketController missing miRequestPark/miRequestParkAndScan or call failed."` | ⏳ |
| `"⚠️ StartAuto: TokenEngine API_collect nie działa"` | `"⚠️ StartAuto: TokenEngine API_collect not working"` | ⏳ |
| `"⚠️ StartAuto: TokenEngine API_prime nie działa."` | `"⚠️ StartAuto: TokenEngine API_prime not working."` | ⏳ |
| `"⚠️ StartAuto: ShopEngine API_reset nie działa"` | `"⚠️ StartAuto: ShopEngine API_reset not working"` | ⏳ |
| `"❌ Nie znaleziono EventController"` | `"❌ EventController not found"` | ⏳ |
| `"❌ EventController nie obsługuje NEW GAME PREP"` | `"❌ EventController does not support NEW GAME PREP"` | ⏳ |
| `"⛔ Najpierw uruchom grę (START GAME)."` | `"⛔ Start the game first (START GAME)."` | ⏳ |
| `"Rzut kostką dla aktualnego gracza"` | `"Roll die for current player"` | ⏳ |
| `"Po zakończeniu rzutów pojawi się START GAME"` | `"After rolling is finished, START GAME will appear"` | ⏳ |
| `"⛔ "..color..": rozdaj pulę do zera. Zostało: "..st.pool` | `"⛔ "..color..": distribute pool to zero. Remaining: "..st.pool` | ⏳ |

---

## 🎴 EVENT ENGINE (7b92b3_EventEngine.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"👶 Odblokowanie AP: brak dziecka."` | `"👶 AP Unlock: no child."` | ⏳ |
| `"👶 Odblokowano "..tostring(nxt-cur).." AP z blokady dziecka (w tej rundzie)."` | `"👶 Unlocked "..tostring(nxt-cur).." AP from child lock (this round)."` | ⏳ |
| `"👶 Babysitter: brak dziecka → nic do odblokowania."` | `"👶 Babysitter: no child → nothing to unlock."` | ⏳ |
| `"⛔ Nie masz wystarczająco pieniędzy."` | `"⛔ You don't have enough money."` | ⏳ |
| `"⛔ Nie masz wystarczająco pieniędzy na tę kartę."` | `"⛔ You don't have enough money for this card."` | ⏳ |
| `"⛔ Nie masz wystarczająco AP na tę kartę."` | `"⛔ You don't have enough AP for this card."` | ⏳ |

---

## 🎮 EVENTS CONTROLLER (1339d3_EventsController.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"⛔ Nie masz wystarczająco AP na dopłatę za kartę z dalszego slotu (+"..tostring(extra).." AP)."` | `"⛔ You don't have enough AP for the extra cost from a further slot (+"..tostring(extra).." AP)."` | ⏳ |
| `"⚠️ Karta zagrana, ale nie udało się pobrać dopłaty AP (+"..tostring(extra).."). Sprawdź AP_CTRL."` | `"⚠️ Card played, but failed to deduct extra AP cost (+"..tostring(extra).."). Check AP_CTRL."` | ⏳ |

---

## 🎯 YOUTH BOARD (89eb00_YouthBoard.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"[YOUTH BOARD] ⛔ Brak aktywnego gracza z Turns.turn_color. Włącz Turns i ustaw turę (Yellow/Blue/Red/Green)."` | `"[YOUTH BOARD] ⛔ No active player with Turns.turn_color. Enable Turns and set turn (Yellow/Blue/Red/Green)."` | ⏳ |

---

## 🎛️ WLB CONTROL (1b53e4_WLBControl.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"❌ [WLB] RESTORE LAYOUT: brak zapisanego layoutu. Kliknij CAPTURE LAYOUT (i zrób SAVE)."` | `"❌ [WLB] RESTORE LAYOUT: no saved layout. Click CAPTURE LAYOUT (and do SAVE)."` | ⏳ |
| `"🔁 [WLB] RESTORE LAYOUT: przywrócono "..tostring(moved).." obiektów, brak "..tostring(missing).."."` | `"🔁 [WLB] RESTORE LAYOUT: restored "..tostring(moved).." objects, missing "..tostring(missing).."."` | ⏳ |
| `"Zapisuje pozycje wszystkich obiektów z tagiem WLB_LAYOUT. Po kliknięciu: SAVE!"` | `"Saves positions of all objects with tag WLB_LAYOUT. After clicking: SAVE!"` | ⏳ |
| `"Przywraca zapisany layout."` | `"Restores saved layout."` | ⏳ |
| `"Zbiera tokeny SAT_TOKEN obok Control Panelu"` | `"Collects SAT_TOKEN tokens near Control Panel"` | ⏳ |
| `"Wybierz start: Youth lub Adult"` | `"Choose start: Youth or Adult"` | ⏳ |
| `"Start od rundy 1 (Youth) + SAT=10"` | `"Start from round 1 (Youth) + SAT=10"` | ⏳ |
| `"Start od rundy 6 (Adult) + SAT=10 + mechanika startowa Adult"` | `"Start from round 6 (Adult) + SAT=10 + Adult start mechanics"` | ⏳ |
| `"Wróć"` | `"BACK"` | ⏳ |

---

## 📅 YEAR TOKEN (465776_YearToken.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"⚠️ TokenYear: brak zapisanej pozycji dla rundy "..tostring(r).."."` | `"⚠️ TokenYear: no saved position for round "..tostring(r).."."` | ⏳ |

---

## 🔍 SCANNER PERSO BOARD APART (ScannerPersoBoardApart.lua)

| Polish Original | Proposed English Translation | Status |
|----------------|------------------------------|--------|
| `"Brak PROBE (tag: "..TAG_PROBE..")"` | `"No PROBE (tag: "..TAG_PROBE..")"` | ⏳ |

---

## Notes

- **rzut** = roll (dice roll)
- **próg** = threshold
- **kolejność** = order/turn order
- **traci** = loses
- **dodano** = added
- **brak** = missing/no/none
- **nie udało się** = failed to
- **wyleczył** = cured
- **bezpiecznie użył** = safely used
- **zakup** = purchase
- **koszt** = cost
- **wejścia** = entry

---

## Action Required

Please review each translation and confirm:
1. ✅ Approve - translation is correct
2. 🔄 Revise - suggest alternative translation
3. ❌ Reject - keep original Polish
