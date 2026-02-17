# VocationsController – Plan Refaktoru „na raz”

**Cel:** Usunąć błędy `chunk_X … attempt to call a nil value` i zabezpieczyć przyszłość.

**Zasada:** Nie zmieniamy oryginalnego pliku. Tworzymy alternatywę w `scripts/object-scripts-alternative/VocationsController_Refactored.lua`.

---

## 0. Diagnoza i założenia

### Co się dzieje

- TTS dzieli duże skrypty na chunki.
- `local function` i `local` nie są widoczne w innym chunku.
- Nawet „zwykłe” globalne mogą być niedostępne między chunkami.
- `_G` jest współdzielone między chunkami.

### Architektura docelowa

- Publiczne API i helpery w `_G.WLB.VOC`
- W skrypcie tylko cienkie wrappery delegujące do `VOC.*`

---

## 1. Zależności między plikami (kontrakt API)

### EventEngine (7b92b3_EventEngine.lua)

- `VOC_CanUseEntrepreneurReroll`
- `VOC_RollDieForPlayer`
- `VOC_GetSalary`
- `VOC_GetVocation`
- `StartVECrimeTargetSelection`
- `RunVocationEventCardAction`

### TurnController (c9ee1a_TurnController.lua)

- `VOC_GetVocation`
- `VOC_OnTurnEnd`

### ShopEngine (d59e04_ShopEngine.lua)

- `VOC_GetVocation`
- `VOC_RollDieForPlayer`
- `VOC_CanUseEntrepreneurReroll`
- `VOC_ApplyCrowdfundPoolForPurchase`
- `VOC_GetNGOInvestmentSubsidy`
- `VOC_ConsumeNGOInvestmentPerk`
- `VOC_MarkNGOTakeTripUsed`
- `VOC_GangsterStealHitechCardChosen`

### EstateEngine (fd8ce0_EstateEngine.lua)

- `VOC_GetVocation`

### PlayerBoardController_Shared

- `VOC_GetSalary`

### Global_Script_Complete.lua

- `handleTargetSelection` (UI target selection)

**Wniosek:** Te funkcje muszą pozostać jako globalne entry pointy (nazwy) – zmieniamy tylko wnętrze.

---

## 2. API kontraktowe (freeze – nie zmieniać nazw)

```
VOC_GetVocation
VOC_SetVocation
VOC_GetLevel
VOC_GetSalary
VOC_AddWorkAP
VOC_GetTotalWorkAP
VOC_GetWorkAPThisLevel
VOC_GetVocationData
VOC_OnRoundEnd
VOC_OnTurnEnd
VOC_CanUseEntrepreneurReroll
VOC_RollDieForPlayer
VOC_ResolveEntrepreneurDieGoOn
VOC_ResolveEntrepreneurDieReroll
StartVECrimeTargetSelection
handleTargetSelection
VECrimeTargetSelected
VOC_SaveState
VOC_ResetForNewGame
VOC_DebugState
API_CanPublicServantWaiveTax
API_UsePublicServantTaxWaiver
API_GetPublicServantTaxWaiverStatus
API_GetOverworkSatLoss
API_GetExperienceTokenCount
VOC_StartSocialWorkerConsumableFree
VOC_StartSocialWorkerHitechFree
VOC_StartSocialWorkerCommunitySession
VOC_StartSocialWorkerPracticalWorkshop
VOC_StartSocialWorkerExposeCase
VOC_ApplyCrowdfundPoolForPurchase
VOC_GetNGOInvestmentSubsidy
VOC_ConsumeNGOInvestmentPerk
VOC_MarkNGOTakeTripUsed
VOC_GangsterStealHitechCardChosen
HandleInteractionResponse
RunVocationEventCardAction
hideTargetSelection
(+ wszystkie inne VOC_* i API_* wołane przez inne pliki)
```

---

## 3. Docelowa architektura pliku

### 3.1 Bootstrap (początek pliku, ~200–400 linii)

```lua
_G.WLB = _G.WLB or {}
_G.WLB.VOC = _G.WLB.VOC or {}
local VOC = _G.WLB.VOC

-- Stałe w VOC
VOC.DEBUG = true
VOC.VERSION = "1.0.0"
VOC.TAGS = {
  SELF = "WLB_VOCATIONS_CTRL",
  BOARD = "WLB_BOARD",
  TURN_CTRL = "WLB_TURN_CTRL",
  TURN_CTRL_ALT = "WLB_TURN_CONTROLLER",
  TOKEN_ENGINE = "WLB_TOKEN_ENGINE",
  STATS_CTRL = "WLB_STATS_CTRL",
  AP_CTRL = "WLB_AP_CTRL",
  MONEY = "WLB_MONEY",
  PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL",
  HEAT_POLICE = "WLB_POLICE",
  VOCATION_TILE = "WLB_VOCATION_TILE",
  COLOR_PREFIX = "WLB_COLOR_",
}
VOC.COLORS = {"Yellow", "Blue", "Red", "Green"}

-- Safe TTS API (guard przed nil w chunkach)
VOC.getAllObjectsSafe = function()
  return (type(getAllObjects) == "function" and getAllObjects()) or {}
end
VOC.getObjectsWithTagSafe = function(tag)
  local fn = getObjectsWithTag or (type and type(getObjectsWithTag))
  if type(fn) ~= "function" then return {} end
  return fn(tag) or {}
end
VOC.safeCall = function(obj, fn, params)
  if not obj or type(obj.call) ~= "function" then return false, "no obj/call" end
  local ok, res = pcall(function() return obj.call(fn, params or {}) end)
  return ok, res
end
VOC.getObjectFromGUID = function(guid)
  if type(getObjectFromGUID) ~= "function" then return nil end
  return getObjectFromGUID(guid)
end

-- Log / warn (tylko przez VOC)
VOC.log = function(msg)
  if VOC.DEBUG then print("[VOC_CTRL] " .. tostring(msg)) end
end
VOC.warn = function(msg)
  print("[VOC_CTRL][WARN] " .. tostring(msg))
end
VOC.normalizeColor = function(color)
  if not color then return nil end
  local c = tostring(color):lower()
  if c == "white" then return "White" end
  local map = { yellow = "Yellow", blue = "Blue", red = "Red", green = "Green" }
  return map[c]
end

-- Findery kontrolerów (jeden standard)
VOC.findTurnCtrl = function()
  local all = VOC.getAllObjectsSafe()
  for _, obj in ipairs(all) do
    if obj and obj.hasTag and (obj.hasTag(VOC.TAGS.TURN_CTRL) or obj.hasTag(VOC.TAGS.TURN_CTRL_ALT)) then
      return obj
    end
  end
  for _, obj in ipairs(all) do
    if obj and obj.call then
      local ok, r = pcall(function() return obj.call("API_GetSciencePoints", {color = "Yellow"}) end)
      if ok and type(r) == "number" then return obj end
    end
  end
  return nil
end
VOC.findTokenEngine = function()
  local all = VOC.getAllObjectsSafe()
  for _, obj in ipairs(all) do
    if obj and obj.hasTag and obj.hasTag(VOC.TAGS.TOKEN_ENGINE) and obj.call then return obj end
  end
  return nil
end
VOC.findStatsCtrl = function(color)
  local tag = VOC.TAGS.COLOR_PREFIX .. tostring(color or "")
  local list = VOC.getObjectsWithTagSafe(tag)
  for _, o in ipairs(list) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.STATS_CTRL) and o.call then return o end
  end
  for _, o in ipairs(VOC.getAllObjectsSafe()) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.STATS_CTRL) and o.hasTag(tag) and o.call then return o end
  end
  return nil
end
VOC.findPlayerStatusCtrl = function()
  local all = VOC.getAllObjectsSafe()
  for _, o in ipairs(all) do
    if o and o.hasTag and o.hasTag(VOC.TAGS.PLAYER_STATUS_CTRL) and o.call then return o end
  end
  return nil
end
VOC.findEventEngine = function()
  return VOC.getObjectFromGUID("7b92b3") or nil
end
VOC.findShopEngine = function()
  local all = VOC.getAllObjectsSafe()
  for _, o in ipairs(all) do
    if o and o.hasTag and o.hasTag("WLB_SHOP_ENGINE") and o.call then return o end
  end
  return nil
end
-- (+ inne find* według potrzeb)
```

### 3.2 VOC.API

```lua
VOC.API = VOC.API or {}

-- Przykład: VOC.API.VOC_GetVocation
VOC.API.VOC_GetVocation = function(params)
  -- implementacja (używa tylko VOC.* i state)
  ...
end

-- Wszystkie publiczne funkcje w VOC.API.*
```

### 3.3 Wrappery globalne

```lua
function VOC_GetVocation(params)
  return (VOC.API and VOC.API.VOC_GetVocation and VOC.API.VOC_GetVocation(params)) or nil
end
function VOC_CanUseEntrepreneurReroll(params)
  return (VOC.API and VOC.API.VOC_CanUseEntrepreneurReroll and VOC.API.VOC_CanUseEntrepreneurReroll(params)) or false
end
-- ... dla każdej funkcji kontraktowej
```

---

## 4. Zasady „chunk-hardening”

### 4.1 Brak gołych wywołań TTS API

- Zamiast `getAllObjects()` → `VOC.getAllObjectsSafe()`
- Zamiast `getObjectsWithTag(tag)` → `VOC.getObjectsWithTagSafe(tag)`
- Zamiast `getObjectFromGUID(g)` → `VOC.getObjectFromGUID(g)` (z guardem)

### 4.2 Brak `local function` dla rzeczy używanych szeroko

- `local function` tylko dla funkcji prywatnych w jednej sekcji.
- Wszystko wołane z .call, UI lub innych funkcji → w `VOC.*`.

### 4.3 Jeden standard lookup

- `VOC.findTurnCtrl()`, `VOC.findTokenEngine()`, itd. – jeden zestaw, bez duplikatów (`getTurnCtrl`, `findTurnController` itp.).

### 4.4 Cross-object calls w pcall

- Zawsze przez `VOC.safeCall(obj, "FunctionName", params)`.

### 4.5 getSciencePointsForColor

- Musi używać **tylko** `VOC.normalizeColor`, `VOC.findTurnCtrl`, `VOC.log` – nigdy lokalnych wersji.

---

## 5. Mapowanie sekcji (co przenosimy gdzie)

| Sekcja | Zawartość |
|--------|-----------|
| A – Bootstrap | Namespace, TAGS, COLORS, getAllObjectsSafe, safeCall, log, warn, normalizeColor, find* |
| B – Cache (opcjonalnie) | VOC.cache, VOC.refreshCache() |
| C – Target selection / Crime | StartVECrimeTargetSelection, startTargetSelection, handleTargetSelection, VECrimeTargetSelected |
| D – Dice / Reroll | VOC_CanUseEntrepreneurReroll, VOC_RollDieForPlayer |
| E – Economy | VOC_GetSalary, VOC_GetVocation, VOC_ApplyCrowdfundPoolForPurchase, itd. |
| F – Turn lifecycle | VOC_OnTurnEnd |
| G – Reszta | Pozostałe vocation perks, interaction, promotion, itd. |

---

## 6. Integracja z innymi plikami

### EventEngine

- Usunąć wywołania `findOneByTags({TAG})` – przekazywać string lub używać `getObjectsWithTag`.
- Upewnić się, że tag `WLB_VOCATIONS_CTRL` jest spójny.

### Tagi

- `TAG_SELF = "WLB_VOCATIONS_CTRL"` – ten sam string wszędzie.

---

## 7. Procedura refaktoru krok po kroku

### Krok 1: Kopia pliku

```
cp scripts/object-scripts/VocationsController.lua scripts/object-scripts-alternative/VocationsController_Refactored.lua
```

### Krok 2: Bootstrap _G.WLB.VOC

Na początku pliku (po komentarzu nagłówkowym) wstawić blok z sekcji 3.1. Nie usuwać na razie istniejących `local` – tylko dodać `VOC.*`.

### Krok 3: VOC.API i wrappery

Utworzyć `VOC.API = {}` i przenieść po jednej funkcji:

1. Skopiować `function VOC_GetVocation(...)` do `VOC.API.VOC_GetVocation`
2. W `VOC.API.VOC_GetVocation` zamienić wywołania na `VOC.log`, `VOC.normalizeColor`, `VOC.findTurnCtrl` itd.
3. Zostawić wrapper: `function VOC_GetVocation(params) return VOC.API.VOC_GetVocation(params) end`

### Krok 4: Krytyczne funkcje (Crime flow)

Priorytet:

1. `getSciencePointsForColor` – wyłącznie `VOC.normalizeColor`, `VOC.findTurnCtrl`, `VOC.log`
2. `VOC_CanUseEntrepreneurReroll` – wyłącznie `VOC.*` i `VOC.API`
3. `VOC_RollDieForPlayer` – j.w.
4. `handleTargetSelection`, `StartVECrimeTargetSelection` – j.w.

### Krok 5: Usunięcie lokalnych duplikatów

- Usunąć `local function getTurnCtrl` (zastępuje `VOC.findTurnCtrl`)
- Usunąć `local function findTokenEngine` (zastępuje `VOC.findTokenEngine`)
- Wszystkie miejsca używające tych funkcji – przepisać na `VOC.findTurnCtrl()` itd.

### Krok 6: onLoad – diagnostyka

```lua
function onLoad()
  print("[VOC_CTRL] REFACTOR LOADED " .. os.date("%Y-%m-%d %H:%M:%S"))
  ...
end
```

### Krok 7: Testy (checklista w sekcji 8)

---

## 8. Checklista testów po refaktorze

- [ ] **Crime flow:** VE card → YES → Crime → wybór targetu → rzut kostką (bez crash)
- [ ] Crime z różnymi kolorami (Red/Blue/Yellow)
- [ ] Target „not playable” – brak crash
- [ ] **Entrepreneur reroll:** Crime jako Entrepreneur L2 – reroll działa
- [ ] **Shop:** purchase z crowdfund pool, NGO subsidy, gangster steal hi-tech
- [ ] **Turn:** End turn → VOC_OnTurnEnd
- [ ] **Nil safety:** Spectator i normalny gracz

---

## 9. Dlaczego to usuwa błąd na stałe

1. Wszystko krytyczne jest w `_G.WLB.VOC` – dostępne z każdego chunku.
2. Brak polegania na `local function` z innego chunku.
3. Cross-object calls przez `VOC.safeCall` (pcall).
4. Nawet przy zmianach granic chunków `_G` pozostaje wspólne.

---

## 10. Użycie pliku alternatywnego

1. Skopiować zawartość `VocationsController_Refactored.lua` do obiektu VocationsController w TTS (Lua Script).
2. Zapisać grę i wczytać ponownie.
3. Sprawdzić log: `[VOC_CTRL] REFACTOR LOADED ...`
4. Przetestować Crime flow.

---

## 11. EventEngine – fix findOneByTags

W EventEngine zidentyfikowano wzorce `findOneByTags({TAG})` – przekazywanie tabeli zamiast stringu może powodować błędy. W planie refaktoru:
- Usunąć wywołania `findOneByTags` z tabelą.
- Użyć `getObjectsWithTag(TAG)` (string) lub bezpośrednio GUID obiektu VocationsController.

## 12. Pliki do analizy przed refaktorem

- `scripts/object-scripts/VocationsController.lua` – źródło
- `scripts/object-scripts/7b92b3_EventEngine.lua` – EventEngine
- `scripts/object-scripts/c9ee1a_TurnController.lua` – TurnController
- `scripts/object-scripts/d59e04_ShopEngine.lua` – ShopEngine
- `scripts/object-scripts/fd8ce0_EstateEngine.lua` – EstateEngine
- `scripts/object-scripts/PlayerBoardController_Shared.lua`
- `scripts/object-scripts/Global_Script_Complete.lua`
