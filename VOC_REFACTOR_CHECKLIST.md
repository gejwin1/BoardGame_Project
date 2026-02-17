# VocationsController Refactor — Kompletna Lista Zmian

## Cel refaktoru
Odporność na TTS chunking: każda funkcja publiczna/callback musi używać `VOC_NS()` na początku i **nigdy** fallbacku `(VOC.x or x)(...)` do lokalnej funkcji (bo lokalna może być nil w innym chunku).

---

## Reguły obowiązkowe

### Reguła 1: Accessor na początku każdej entry-point
```lua
local function VOC_NS()
  return (_G and (_G.VOC or (_G.WLB and _G.WLB.VOC))) or nil
end
_G.VOC_NS = VOC_NS
```

W **każdej** funkcji publicznej / callbacku UI:
```lua
local VOC = (_G.VOC_NS or VOC_NS)()
if not VOC then
  print("[VOC_CTRL][FATAL] VOC namespace missing in chunk")
  return nil  -- lub odpowiedni early-exit
end
```

### Reguła 2: Zero fallbacków `(VOC.x or x)(...)`
- Fallback **tylko** przez `_G`, np. `(_G.VOC_normalizeColor and _G.VOC_normalizeColor(value))`
- Nigdy: `(VOC.normalizeColor or normalizeColor)(value)`

### Reguła 3: Użycie `VOC.` tylko po `local VOC = VOC_NS()`
- Jeśli funkcja używa `VOC.` bez wcześniejszego `VOC_NS()` → **dodać** na początku funkcji.

---

## P1 — Priorytet krytyczny (Crime / Dice / UI target selection)

Te funkcje są na ścieżce: karta VE → YES → Crime → wybór targetu → rzut kością.
**Stan:** Część ma już `VOC_NS()`, ale należy zweryfikować brak niebezpiecznych fallbacków.

| # | Funkcja | Linia | Ma VOC_NS? | Uwagi |
|---|---------|-------|------------|-------|
| 1 | `StartVECrimeTargetSelection` | 1637 | ✓ | Zweryfikować fallbacki |
| 2 | `handleTargetSelection` | 1526 | ✓ | |
| 3 | `VECrimeTargetSelected` | 1595 | ✓ | |
| 4 | `hideTargetSelection` | 1487 | ✓ | |
| 5 | `VOC_RollDieForPlayer` | 3609 | ✓ | |
| 6 | `VOC_CanUseEntrepreneurReroll` | 3588 | ✓ | |
| 7 | `VOC_ResolveEntrepreneurDieReroll` | 3539 | ✓ | |
| 8 | `VOC_ResolveEntrepreneurDieGoOn` | 3516 | ✓ | |
| 9 | `RollDieAndResolveInteraction` | 3447 | ✗ | **Dodać VOC_NS()** |
| 10 | `OnEntrepreneurDieGoOn` | 3490 | ✗ | **Dodać VOC_NS()** (callback UI) |
| 11 | `OnEntrepreneurDieReroll` | 3503 | ✗ | **Dodać VOC_NS()** (callback UI) |
| 12 | `clearTargetSelection` | 1410 | ✗ | **Dodać VOC_NS()** — wołana z hideTargetSelection |
| 13 | `startTargetSelection` | 1423 | ✓ | |

---

## P2 — API dla zewnętrznych silników

Wywoływane z EventEngine, ShopEngine, TurnController itd.

| # | Funkcja | Linia | Ma VOC_NS? | Uwagi |
|---|---------|-------|------------|-------|
| 1 | `VOC_GetVocation` | 2948 | ✗ | Używa tylko _G.VOC_normalizeColor — OK, ale dodać guard jeśli params nil |
| 2 | `VOC_SetVocation` | 2956 | ✗ | **Dodać VOC_NS()** — używa normalizeColor, VOC.log |
| 3 | `VOC_GetVocationData` | 3185 | ✓ | |
| 4 | `VOC_GetSalary` | 3101 | ✗ | **Dodać VOC_NS()** |
| 5 | `VOC_OnTurnEnd` | 3290 | ✓ | |
| 6 | `VOC_OnRoundEnd` | 3207 | ✓ | |
| 7 | `VOC_SaveState` | 2672 | ✗ | **Dodać VOC_NS()** |
| 8 | `VOC_ResetForNewGame` | 2843 | ✗ | **Dodać VOC_NS()** |
| 9 | `API_CanPublicServantWaiveTax` | 3030 | ✗ | **Dodać VOC_NS()** |
| 10 | `API_UsePublicServantTaxWaiver` | 3040 | ✗ | **Dodać VOC_NS()** |
| 11 | `API_GetPublicServantTaxWaiverStatus` | 3050 | ✗ | **Dodać VOC_NS()** |
| 12 | `API_GetOverworkSatLoss` | 3080 | ✗ | **Dodać VOC_NS()** |
| 13 | `API_GetExperienceTokenCount` | 3094 | ✗ | **Dodać VOC_NS()** |
| 14 | `API_AddAwardToken` | 3167 | ✗ | **Dodać VOC_NS()** |
| 15 | `VOC_AddWorkAP` | 3119 | ✗ | **Dodać VOC_NS()** |
| 16 | `VOC_GetTotalWorkAP` | 3136 | ✗ | **Dodać VOC_NS()** |
| 17 | `VOC_GetWorkAPThisLevel` | 3143 | ✗ | **Dodać VOC_NS()** |
| 18 | `VOC_GetLevel` | 3021 | ✗ | **Dodać VOC_NS()** |
| 19 | `HandleInteractionResponse` | 2599 | ✗ | **Dodać VOC_NS()** |

---

## P3 — Akcje zawodów (VOC_Start* i perki)

**Wymagają VOC_NS() na początku i usunięcia fallbacków.**

### Social Worker
| Funkcja | Linia |
|---------|-------|
| `VOC_StartSocialWorkerUseGoodKarma` | 926 |
| `VOC_StartSocialWorkerConsumableFree` | 965 |
| `VOC_StartSocialWorkerHitechFree` | 1002 |
| `VOC_StartSocialWorkerCommunitySession` | 3657 |
| `VOC_StartSocialWorkerPracticalWorkshop` | 3719 |
| `VOC_StartSocialWorkerExposeCase` | 3777 |
| `VOC_StartSocialWorkerHomelessShelter` | 3824 |
| `VOC_StartSocialWorkerRemoval` | 3888 |

### Celebrity
| Funkcja | Linia |
|---------|-------|
| `VOC_StartCelebrityStreetPerformance` | 3972 |
| `VOC_StartCelebrityMeetGreet` | 4013 |
| `VOC_StartCelebrityCharityStream` | 4060 |
| `VOC_CelebrityGetAward` | 4101 |
| `VOC_StartCelebrityCollaboration` | 4140 |
| `VOC_StartCelebrityMeetup` | 4183 |

### Public Servant
| Funkcja | Linia |
|---------|-------|
| `VOC_StartPublicServantIncomeTax` | 4242 |
| `VOC_PlacePublicServantHealthMonitorAccess` | 4327 |
| `VOC_PlacePublicServantAlarmAccess` | 4360 |
| `VOC_PlacePublicServantCarAccess` | 4390 |
| `VOC_StartPublicServantHiTechTax` | 4419 |
| `VOC_StartPublicServantPropertyTax` | 4487 |
| `VOC_StartPublicServantPolicy` | 4555 |
| `VOC_StartPublicServantBottleneck` | 4589 |

### NGO Worker
| Funkcja | Linia |
|---------|-------|
| `VOC_StartNGOCharity` | 4646 |
| `VOC_StartNGOTakeGoodKarma` | 4722 |
| `VOC_StartNGOTakeTrip` | 4782 |
| `VOC_MarkNGOTakeTripUsed` | 4823 |
| `VOC_StartNGOUseInvestment` | 4835 |
| `VOC_GetNGOInvestmentSubsidy` | 4866 |
| `VOC_ConsumeNGOInvestmentPerk` | 4879 |
| `VOC_StartNGOCrowdfunding` | 4892 |
| `VOC_ApplyCrowdfundPoolForPurchase` | 4971 |
| `VOC_StartNGOVoluntaryWork` | 5006 |
| `VOC_StartNGOAdvocacy` | 5043 |
| `VOC_StartNGOCrisis` | 5086 |
| `VOC_StartNGOScandal` | 5125 |

### Entrepreneur
| Funkcja | Linia |
|---------|-------|
| `VOC_StartEntrepreneurFlashSale` | 5182 |
| `VOC_StartEntrepreneurTalkToShopOwner` | 5237 |
| `VOC_StartEntrepreneurTraining` | 5277 |
| `VOC_StartEntrepreneurExpansion` | 5317 |
| `VOC_StartEntrepreneurEmployeeTraining` | 5371 |
| `VOC_StartEntrepreneurReposition` | 5410 |

### Gangster
| Funkcja | Linia |
|---------|-------|
| `VOC_StartGangsterStealHitech` | 5473 |
| `VOC_StartGangsterFalseMoney` | 5516 |
| `VOC_StartGangsterLockdown` | 5570 |
| `VOC_OnTurnStarted` | 5637 |
| `VOC_GangsterStealHitechCardChosen` | 5653 |
| `VOC_StartGangsterCrime` | 5699 |
| `RunCrimeInvestigation` | 5896 |
| `VOC_StartGangsterRobinHood` | 5974 |
| `VOC_StartGangsterProtection` | 6071 |

### Promotion / UI
| Funkcja | Linia |
|---------|-------|
| `VOC_CanPromote` | 6107 |
| `VOC_Promote` | 6262 |
| `VOC_CheckAndAutoPromote` | 6433 |
| `UI_VocationAction` | 6735 |
| `RunVocationEventCardAction` | 6899 (ma VOC_NS) |
| `refreshSelectionCardAllocUI` | 6981 |
| `findSummaryTileForVocation` | 7458 |
| `VOC_ReturnLevel1Cards` | 7581 |
| `VOC_ShowSelectionUI` | 7612 |
| `VOC_ChoseFromCard` | 7680 |
| `VOC_ShowExplanationCard` | 7725 |
| `VOC_HideExplanationCard` | 7790 |
| `VOC_ShowExplanationForPlayer` | 7801 |
| `VOC_CardButtonShowExplanation` | 7833 |
| `VOC_VocationTileClicked` | 7855 |
| `VOC_ShowPerksOnController` | 7902 |
| `VOC_BackToSelection` | 7972 |
| `VOC_StartSelection` | 8064 |
| `VOC_SelectPublicServant` | 8126 |
| `VOC_SelectCelebrity` | 8130 |
| `VOC_SelectSocialWorker` | 8134 |
| `VOC_SelectGangster` | 8138 |
| `VOC_SelectEntrepreneur` | 8142 |
| `VOC_SelectNGOWorker` | 8146 |
| `handleVocationButtonClick` | 8150 |
| `VOC_SelectionTileClicked` | 8183 |
| `VOC_ShowSummary` | 8206 |
| `VOC_ConfirmSelection` | 8290 |
| `VOC_HideSummary` | 8337 |
| `VOC_CleanupSelection` | 8368 |
| `VOC_RecoverTiles` | 8430 |
| `VOC_UI_SelectVocation` | 8514 |
| `UI_SelectVocation` | 8526 |
| `VOC_UI_ConfirmVocation` | 8636 |
| `UI_ConfirmVocation` | 8648 |
| `UI_AllocScience` | 8803 |
| `UI_ApplyAllocScience` | 8847 |
| `VOC_UI_BackToSelection` | 8889 |
| `UI_BackToSelection` | 8901 |
| `VOC_UI_CloseVocationExplanation` | 8951 |
| `VOC_UI_CancelSelection` | 8966 |
| `UI_CancelSelection` | 8978 |
| `VOC_StartSelection_UI` | 9041 |
| `ResolveInteractionEffectsWithDie` | 9074 |
| `UI_Interaction_YellowJoin` | 9088 |
| `UI_Interaction_YellowIgnore` | 9099 |
| `UI_Interaction_BlueJoin` | 9108 |
| `UI_Interaction_BlueIgnore` | 9117 |
| `UI_Interaction_RedJoin` | 9126 |
| `UI_Interaction_RedIgnore` | 9135 |
| `UI_Interaction_GreenJoin` | 9144 |
| `UI_Interaction_GreenIgnore` | 9153 |

### Inne / Debug
| Funkcja | Linia |
|---------|-------|
| `getSciencePointsForColor` | 1336 |
| `VOC_DebugState` | 2822 |
| `findTurnController` | 8331 |
| `noop` | 8123 |
| `btnTestUI` | 9191 |
| `onLoad` | 9357 |
| `VOC_Test` | 9444 |
| `VOC_TestUI` | 9449 |
| `VOC_ShowUITest` | 9498 |
| `btnDebugStartSelection` | 9513 |
| `btnDebugShowSummary` | 9532 |
| `btnDebugTestCallback` | 9557 |
| `VOC_RestoreDebugButtons` | 9579 |
| `btnDebugFullTest` | 9586 |
| `btnDebug_ShowLevels` | 9632 |
| `btnDebug_SetLevel1` | 9645 |
| `btnDebug_TestSWEvent` | 9673 |

---

## Wzorce do usunięcia (niebezpieczne)

1. **`(VOC.normalizeColor or normalizeColor)(value)`** → zastąpić:
   ```lua
   (VOC and VOC.normalizeColor and VOC.normalizeColor(value))
     or (_G.VOC_normalizeColor and _G.VOC_normalizeColor(value))
   ```
   Tylko po wcześniejszym `local VOC = VOC_NS()`.

2. **`VOC.log`, `VOC.warn`** bez sprawdzenia VOC:
   - Zawsze po `local VOC = VOC_NS()` i `if not VOC then return ... end`
   - Albo użyć `_G.VOC_log` / `_G.VOC_warn` jeśli są zdefiniowane w bootstrapie.

3. **`log`, `warn`** (aliasy) — obecnie:
   ```lua
   log = function(msg) if VOC and VOC.log then VOC.log(msg) end end
   ```
   Tu `VOC` może być nil w chunku. Lepiej:
   ```lua
   _G.VOC_log = _G.VOC_log or function(msg) ... end
   ```

---

## EventEngine_Refactored.lua — findOneByTags({...})

**Problem:** W EventEngine_Refactored.lua jest **27 wywołań** `findOneByTags({TAG_...})` z **tablicą** zamiast argumentów.

Jeśli `findOneByTags` oczekuje `(tagA, tagB)` (dwa stringi), przekazywanie `{tagA, tagB}` powoduje błąd lub niespodziewane zachowanie.

**Lokalizacje (linie):** 190, 197, 345, 373, 489, 501, 535, 548, 573, 731, 784, 811, 1083, 1164, 1183, 1238, 1380, 1447, 1530, 1636, 1733, 1826, 2396, 2454, 2476, 2886.

**Rekomendacja:**
- Zmienić na `findOneByTags(TAG_X)` lub `findOneByTags(TAG_X, colorTag(color))` w zależności od sygnatury,
- Albo dostosować `findOneByTags` tak, żeby akceptował zarówno `(tag)` jak i `(tagA, tagB)`.

---

## Strategia wdrożenia

### Etap 1 — P1 (Crime / Dice)
1. Dodać `VOC_NS()` do: `RollDieAndResolveInteraction`, `OnEntrepreneurDieGoOn`, `OnEntrepreneurDieReroll`, `clearTargetSelection`.
2. Usunąć fallbacki `(VOC.x or x)(...)` z całego P1.
3. Dodać debug: `print("ENTER VECrimeTargetSelected VOC="..tostring(VOC~=nil))` na wejściu do `VECrimeTargetSelected` i `VOC_RollDieForPlayer`.

### Etap 2 — P2 (API)
Po ustabilizowaniu Crime/Dice — dopiąć VOC_NS do wszystkich P2.

### Etap 3 — P3 (masowo)
- Regex: na początku każdej `function VOC_Start...` / `function VOC_...` dodać blok VOC_NS.
- Dla callbacków UI (`obj, color, alt_click`) to samo.

### Etap 4 — EventEngine
- Poprawić `findOneByTags` w EventEngine_Refactored (argumenty zamiast tablicy).

---

## Definicja ukończenia

- [ ] Wszystkie funkcje publiczne (VOC_*, StartVEC*, VEC*, callbacki UI) mają na początku `local VOC = VOC_NS()`.
- [ ] Nigdzie nie ma `(VOC.x or x)(...)` ani fallbacku do "gołej" lokalnej funkcji.
- [ ] Refaktor ładuje się (log z onLoad) i **Crime flow przechodzi bez crasha**.
