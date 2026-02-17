# Event Engine – Plan Refaktoru (chunk-safe)

**Cel:** Usunąć błędy `chunk_X … attempt to call a nil value` w Event Engine, w szczególności w flow Crime (VECrimeTargetSelected → rollDieForPlayer → findOneByTags).

**Zasada:** Nie zmieniamy oryginalnego pliku. Tworzymy alternatywę w `scripts/object-scripts-alternative/EventEngine_Refactored.lua`.

---

## 0. Diagnoza – dlaczego Event Engine

Błąd nadal występuje mimo refaktoru VocationsController. Flow wygląda tak:

1. Gracz wybiera Crime → VocationsController.startTargetSelection → handleTargetSelection
2. handleTargetSelection przekazuje do Event Engine: `engine.call("VECrimeTargetSelected", params)`
3. **Event Engine** – `VECrimeTargetSelected` (linia 1231) wywołuje `rollDieForPlayer(data.color, "evt_crime", callback)`
4. **Event Engine** – `rollDieForPlayer` (linia 1787) wywołuje `findOneByTags({TAG_VOCATIONS_CTRL})` aby uzyskać obiekt VocationsController
5. **Event Engine** – `findOneByTags` (linia 197) wywołuje `getAllObjects()` – jeśli w chunk_4 jest `nil` → crash

**Wniosek:** Crash może występować w Event Engine, nie w VocationsController. `findOneByTags` i inne wywołania TTS API muszą być zabezpieczone.

---

## 1. Założenia (identyczne jak VocationsController)

- TTS dzieli duże skrypty na chunki.
- `getAllObjects`, `getObjectsWithTag`, `getObjectFromGUID` mogą być `nil` w niektórych chunkach.
- `_G` jest współdzielone – wszystko cross-chunk musi być w `_G.WLB.EVT` (lub podobnym namespace).
- Nie zmieniamy nazw publicznych funkcji (kontrakt API).

---

## 2. Zależności Event Engine (kto woła co)

### Zewnętrzni wywołujący

- **VocationsController** – `engine.call("VECrimeTargetSelected", params)`
- **EventsController** – `playCardFromUI`, `isObligatoryCard`, inne
- **Global UI / obiekty** – evt_veCrime, evt_veTargetYellow/Blue/Red/Green, evt_cancelPending, itd.

### Wołane przez Event Engine (inne obiekty)

- VocationsController – `StartVECrimeTargetSelection`, `VOC_RollDieForPlayer`, `VOC_CanUseEntrepreneurReroll`, `VOC_GetSalary`, `VOC_GetVocation`, `RunVocationEventCardAction`
- EventsController – `EVENTS_CONTROLLER_GUID` (1339d3)
- ShopEngine, EstateEngine, PlayerStatusController, Stats, AP, Money – przez findOneByTags / tagi

### Funkcje publiczne (nie zmieniać nazw)

- `VECrimeTargetSelected`
- `playCardFromUI`
- `evt_veCrime`, `evt_veTargetYellow/Blue/Red/Green`, `evt_veCrimeRoll`, `evt_veChoiceA/B`, `evt_cancelPending`
- `noop_engine`
- (+ wszystkie inne eksportowane przez obiekt)

---

## 3. Docelowa architektura

### 3.1 Bootstrap `_G.WLB.EVT`

Na początku pliku (~100–150 linii):

```lua
_G.WLB = _G.WLB or {}
_G.WLB.EVT = _G.WLB.EVT or {}
EVT = _G.WLB.EVT  -- Global (no local) – dostępny z każdego chunku

EVT.DEBUG = true
EVT.TAGS = {
  STATS_CTRL = "WLB_STATS_CTRL",
  AP_CTRL = "WLB_AP_CTRL",
  MONEY = "WLB_MONEY",
  SHOP_ENGINE = "WLB_SHOP_ENGINE",
  MARKET_CTRL = "WLB_MARKET_CTRL",
  PLAYER_STATUS_CTRL = "WLB_PLAYER_STATUS_CTRL",
  VOCATIONS_CTRL = "WLB_VOCATIONS_CTRL",
  KEEP_ZONE = "WLB_KEEP_ZONE",
  DISCARD_ZONE = "WLB_EVENT_DISCARD_ZONE",
  DISCARD_ZONE_ALT = "WLB_EVT_USED_ZONE",
  COSTS_CALC = "WLB_COSTS_CALC",
  BOARD = "WLB_BOARD",
}

EVT.getAllObjectsSafe = function()
  return (type(getAllObjects) == "function" and getAllObjects()) or {}
end
EVT.getObjectsWithTagSafe = function(tag)
  if type(getObjectsWithTag) ~= "function" then return {} end
  return getObjectsWithTag(tag) or {}
end
EVT.getObjectFromGUID = function(guid)
  if type(getObjectFromGUID) ~= "function" then return nil end
  return getObjectFromGUID(guid)
end
EVT.safeCall = function(obj, fn, params)
  if not obj or type(obj.call) ~= "function" then return false, nil end
  return pcall(function() return obj.call(fn, params or {}) end)
end
EVT.log = function(msg)
  if EVT.DEBUG then print("[WLB EVENT] " .. tostring(msg)) end
end
EVT.warn = function(msg)
  print("[WLB EVENT][WARN] " .. tostring(msg))
end
EVT.findOneByTags = function(tags)
  local all = EVT.getAllObjectsSafe()
  for _, o in ipairs(all) do
    local ok = true
    for _, t in ipairs(tags) do
      if not (o and o.hasTag and o.hasTag(t)) then ok = false break end
    end
    if ok then return o end
  end
  return nil
end
```

### 3.2 Mapowanie zamian

| Dotychczas | Po refaktorze |
|------------|----------------|
| `getAllObjects()` | `EVT.getAllObjectsSafe()` |
| `getObjectsWithTag(tag)` | `EVT.getObjectsWithTagSafe(tag)` |
| `getObjectFromGUID(guid)` | `EVT.getObjectFromGUID(guid)` |
| `findOneByTags(tags)` | `EVT.findOneByTags(tags)` |
| `log(msg)` | `EVT.log(msg)` |
| `warn(msg)` | `EVT.warn(msg)` |

---

## 4. Krytyczne miejsca (Crime flow)

1. **VECrimeTargetSelected** (linia ~1231)
   - Używa `getObjectFromGUID(g)` – zamienić na `EVT.getObjectFromGUID(g)`
   - Wywołuje `rollDieForPlayer` – wewnątrz rollDieForPlayer jest `findOneByTags`

2. **rollDieForPlayer** (linia ~1787)
   - `voc = findOneByTags and findOneByTags({TAG_VOCATIONS_CTRL}) or nil`
   - Zamienić na `voc = EVT.findOneByTags({EVT.TAGS.VOCATIONS_CTRL})`

3. **findOneByTags** (linia ~197)
   - Używa `getAllObjects()` – zastąpić całą implementację przez delegację do `EVT.findOneByTags`

4. **findPlayerStatusCtrl** (linia ~229)
   - Używa `getObjectsWithTag` i `getAllObjects` – zamienić na EVT.*

5. **resolveMoney** (linia ~138)
   - Używa `findOneByTags` – już będzie bezpieczne po zamianie findOneByTags

6. **Wszystkie pozostałe** – skan pliku i zamiana każdego wywołania.

---

## 5. Procedura refaktoru krok po kroku

### Krok 1: Kopia pliku
```
copy scripts/object-scripts/7b92b3_EventEngine.lua scripts/object-scripts-alternative/EventEngine_Refactored.lua
```

### Krok 2: Bootstrap EVT
Wstawić blok bootstrap na początku pliku (po nagłówku, przed `local DEBUG`).

### Krok 3: Zamiana findOneByTags
- Zastąpić implementację `findOneByTags` przez delegację do `EVT.findOneByTags`.
- Albo całkowicie usunąć lokalną definicję i wszędzie używać `EVT.findOneByTags`.

### Krok 4: Zamiana getAllObjects
- Każde `getAllObjects()` → `EVT.getAllObjectsSafe()` (poza implementacją w bootstrapie).

### Krok 5: Zamiana getObjectsWithTag
- Każde `getObjectsWithTag(...)` → `EVT.getObjectsWithTagSafe(...)`.

### Krok 6: Zamiana getObjectFromGUID
- Każde `getObjectFromGUID(...)` → `EVT.getObjectFromGUID(...)`.

### Krok 7: Zamiana log / warn
- `log` i `warn` – alias do EVT.log / EVT.warn lub zamiana wszystkich wywołań.

### Krok 8: Diagnostyka
- W `onLoad` (jeśli istnieje) lub na początku wykonania: `print("[WLB EVENT] REFACTOR LOADED " .. os.date("%Y-%m-%d %H:%M:%S"))`.

### Krok 9: Testy
- Crime flow: VE card → Crime → wybór targetu → rzut kością.
- Inne eventy (dice, choice, child, marriage, itd.).

---

## 6. Ryzyko i ostrożność

- **Nie ruszać logiki** – tylko zamiana wywołań TTS API na bezpieczne wrappery.
- **Nie zmieniać nazw funkcji** – kontrakt z EventsController, VocationsController i UI.
- **Testować po każdym większym bloku** – jeśli coś przestanie działać, łatwiej zlokalizować.

---

## 7. Integracja z VocationsController

- VocationsController (refactored) woła Event Engine przez `VOC.getObjectFromGUID("7b92b3")` lub `getObjectFromGUID("7b92b3")`.
- Event Engine (refactored) będzie szukał VocationsController przez `EVT.findOneByTags({EVT.TAGS.VOCATIONS_CTRL})` – tag musi pozostać `WLB_VOCATIONS_CTRL`.
- Oba refaktory są niezależne – można testować EventEngine_Refactored nawet z oryginalnym VocationsController (lub odwrotnie).

---

## 8. Użycie pliku alternatywnego

1. Skopiować zawartość `scripts/object-scripts-alternative/EventEngine_Refactored.lua`.
2. Wkleić do skryptu obiektu Event Engine (GUID 7b92b3) w TTS – podmienić cały istniejący kod.
3. Zapisać grę i załadować ją ponownie.
4. Sprawdzić w logu: `[WLB EVENT] REFACTOR LOADED ...`.
5. Przetestować Crime flow (VE card → Crime → wybór targetu → rzut kością).

Oryginalny plik `7b92b3_EventEngine.lua` w `object-scripts/` pozostaje bez zmian.

---

## 9. Checklista po refaktorze

- [ ] `[WLB EVENT] REFACTOR LOADED` w logu po załadowaniu.
- [ ] Crime flow bez crash (wybór targetu → rzut kością → rozstrzygnięcie).
- [ ] Zwykłe karty event (dice, choice) działają.
- [ ] Dziecko / małżeństwo / specjalne eventy – brak regresji.
