# Call for Auction – przewodnik implementacji (dla dewelopera)

Dokument opisuje **krok po kroku**, jak zaimplementować kartę **Call for Auction** (Adult Event, obligatoryjna) w grze, **bez** wklejania gotowego kodu – tylko: co zrobić, gdzie, w jakiej kolejności, czego unikać i na co uważać.

---

## 0. Setup (Global script i Global UI – bez tagowania)

**Panel Bid/Pass (UI aukcji)** jest w **Global UI** (ten sam plik co vocation UI: `VocationsUI_Global.xml`). W TTS skrypt **Global** i **Global UI** **nie są przypisane do żadnego obiektu** – nie da się ich otagować. Zamiast tego TTS udostępnia skryptom obiektów wbudowaną referencję **`Global`**; wywołanie `Global.call("nazwa_funkcji", parametry)` uruchamia funkcję w skrypcie Global (tak jak w TurnControllerze przy `Global.call("WLB_END_TURN", …)`).

**Co musisz mieć w TTS:**

- **Global script:** wklejony `Global_Script_Complete.lua` (w tym funkcje `UI_AuctionShow`, `UI_AuctionUpdate`, `UI_AuctionHide`, `UI_AuctionBid`, `UI_AuctionPass`).
- **Global UI:** wklejona zawartość `VocationsUI_Global.xml` (w tym panel `auctionOverlay` z przyciskami Bid/Pass).

EventsController wywołuje `Global.call("UI_AuctionShow", …)` itd. – **nie trzeba dodawać żadnego tagu ani GUID**; TTS sam udostępnia `Global` skryptom obiektów. Jeśli panel aukcji się nie pokazuje, sprawdź, czy Global script i Global UI są faktycznie wklejone w odpowiednie miejsca w TTS (Global → Script i Global → UI).

---

## 1. Cel mechaniki (wspólna definicja)

**Karta:** Call for Auction (np. AD_47, `AD_AUCTION_O`, `special = "AD_AUCTION_SCHEDULE"` w EventEngine).

**Opis z gry:**  
*Next year, the cozy flat with three rooms will be set for an auction. Only those who pay 500 WIN before the auction starts can take part. Minimum price 1500 WIN. If you lose, you get your money back.*

**Dwie fazy:**

| Faza | Gdzie | Co się dzieje |
|------|--------|----------------|
| **JOINING** | Karta na Estate Agency (L2) | Gracze w **swoich turach** mogą kliknąć „Pay 500 & Join”. Depozyt 500 WIN „leży” na aukcji (w logice, nie jako token). Okno dołączenia trwa **do początku następnej tury inicjatora**. |
| **BIDDING** | Global UI (panel aukcji) | Na początku **następnej tury inicjatora** startuje licytacja. Kolejność zgodna z turą (od inicjatora). Kroki po 100 WIN. Tylko aktualny licytant widzi aktywne Bid/Pass. Zwycięzca dopłaca (cena − 500), reszta dostaje zwrot 500. |

**Szczegóły:**

- **1 uczestnik:** pytanie „Kupujesz za 1500 WIN?” (dopłata 1000) lub zwrot 500.
- **2+ uczestników:** licytacja Bid/Pass w kolejności tur; ostatni licytujący płaci pełną cenę (minimum 1500 + kroki 100).
- **Brak dostępnych mieszkań L2:** komunikat „No apartments available → no auction”, karta bez efektu / do discard.
- **Increment:** 100 WIN za każdy podbój.

---

## 2. Gdzie jest kod (architektura)

| Odpowiedzialność | Plik / obiekt | Uwagi |
|------------------|----------------|--------|
| **Logika aukcji (backend)** | `1339d3_EventsController.lua` (EventsController) | Jedna maszyna stanów aukcji, walidacje, przyciski na karcie (JOIN), wywołania do EstateEngine/Money. |
| **UI panel (Bid/Pass)** | `Global_Script_Complete.lua` + Global UI (np. rozszerzenie `VocationsUI_Global.xml`) | Panel aukcji widoczny dla wszystkich; przyciski Bid/Pass tylko dla aktualnego licytanta (plus twarda walidacja w backendzie). |
| **Trigger karty** | `7b92b3_EventEngine.lua` (EventEngine) | Przy `def.special == "AD_AUCTION_SCHEDULE"` zamiast „not implemented” wywołanie EventsController i przekazanie karty/inicjatora. |
| **Start fazy BIDDING** | `c9ee1a_TurnController.lua` (TurnController) | Na początku tury: sygnał do EventsController (`Auction_OnTurnStart(activeColor)`), żeby zamknąć JOINING i wystartować licytację, gdy wraca tura inicjatora. |
| **Pieniądze / nieruchomość** | MoneyController (per kolor), `fd8ce0_EstateEngine.lua` | Sprawdzenie „czy stać”, pobranie 500 / dopłata; przydział mieszkania L2 tą samą ścieżką co normalny zakup. |

**Zasada:**  
Backend (EventsController) jest **jedynym** źródłem prawdy. UI tylko wyświetla stan i przekazuje kliknięcia; każda akcja jest walidowana w EventsController (także „czy to twoja kolej”, „czy masz środki”).

**Wzorzec UI (już działający w grze):**  
W projekcie **już działa** Global UI dla wyboru zawodu (vocation choice) oraz dystrybucji punktów nauki (science points). Cała ta dystrybucja przechodzi przez UI. Mechanicznie działa poprawnie; wygląd można dopracować później. Panel aukcji (i kolejne eventy z UI) powinien **powielać ten sam wzorzec**: Global UI (`VocationsUI_Global.xml` / rozszerzenie), callbacki w `Global_Script_Complete.lua` przekazujące akcje do odpowiedniego kontrolera (tu: EventsController). Priorytet: najpierw mechanika, potem estetyka.

---

## 3. Kolejność kroków implementacji

### KROK 0 – Umowa „jeden backend”

- Cała logika aukcji (stany, uczestnicy, ceny, kto może co kliknąć) ma być w **jednym miejscu**: EventsController.
- Unikać: rozrzucania logiki po Global, EventEngine i TurnController (poza wywołaniami do backendu).

---

### KROK 1 – Struktura stanu aukcji (EventsController)

W EventsController wprowadzić **jedną tabelę** `auctionState` (lub podobną), która trzyma m.in.:

- `active` (bool)
- `state` = `"JOINING"` | `"BIDDING"` | `"RESOLVED"`
- `initiatorColor`
- `eventCardGuid` (GUID karty przeniesionej na L2)
- `propertyLevel` = `"L2"` (co jest licytowane)
- `participants` = `{ [color]=true }`
- `deposits` = `{ [color]=500 }`
- `currentPrice` (start 1500), `increment` (100)
- `currentBidderColor`, `leaderColor`
- `activeBidders` (lista kolorów jeszcze w licytacji)
- Informacja o „oknie dołączenia”: np. `joinUntilInitiatorNextTurn = true` oraz sposób wykrycia „minął pełen cykl” (patrz KROK 6).

Stan ma być tak zaprojektowany, żeby po ewentualnym save/load dało się go odtworzyć (minimum: GUID karty, lista uczestników, stan).

---

### KROK 2 – Trigger z EventEngine (bez zmiany sposobu zagrywania kart)

W **EventEngine** (`7b92b3_EventEngine.lua`) w miejscu, gdzie jest:

```lua
if def.special == "AD_AUCTION_SCHEDULE" then
  safeBroadcastTo(color, "ℹ️ Auction: not implemented yet …", …)
  return STATUS.DONE
end
```

Należy:

1. **Nie** wykonywać już tego broadcastu ani zwracać DONE „na ślepo”.
2. Sprawdzić, czy **EstateEngine** ma dostępne mieszkanie L2 (np. nowe API typu `canAuctionL2()` / `hasAvailableL2()` – jeśli nie ma, dodać lub użyć istniejącego sprawdzenia „czy L2 ma kartę do kupienia”).  
   - Jeśli **nie ma** dostępnych mieszkań: broadcast „No apartments available → no auction”, karta do discard / standardowe zakończenie eventu, `return STATUS.DONE`.
3. Jeśli L2 jest dostępne: wywołać **EventsController** (po GUID lub po tagu, np. `TAG_EVENTS_CTRL` – tag trzeba dodać w EventEngine, jeśli dziś EventsController jest wyszukiwany tylko z Event Board).  
   Wywołanie w stylu:  
   `getObjectFromGUID(EVENTS_CTRL_GUID).call("Auction_Start", { initiatorColor = color, cardGuid = card.getGUID() })`  
   (lub równoważnie przez tag).
4. EventsController w `Auction_Start`: ustawia stan JOINING, **przenosi kartę** na wskazany slot L2 przy Estate Agency (współrzędne/pozycję L2 można wziąć z EstateEngine lub z konfiguracji EventsController), blokuje kartę (lock), tworzy przycisk JOIN na karcie (patrz KROK 4).
5. EventEngine po wywołaniu `Auction_Start` zwraca `STATUS.DONE` (karta znika z toru eventów, bo jest już na Estate Agency).

**Uwaga:** W EventEngine obecnie nie ma referencji do EventsController – trzeba dodać stałą GUID lub wyszukiwanie po tagu (np. `WLB_EVENTS_CTRL`) i wywołać `Auction_Start` z przekazaniem `initiatorColor` i `cardGuid`.

---

### KROK 3 – Walidacja „czy jest co licytować”

W **EventsController**, w `Auction_Start` (lub w jednej wspólnej funkcji przed wejściem w JOINING):

- Przed przeniesieniem karty sprawdzić w **EstateEngine**, czy L2 nadal ma dostępne mieszkanie (to samo API co w Kroku 2).
- Jeśli nie: nie rozpoczynać aukcji, komunikat, karta może wrócić do discard / standardowego flow eventów.
- Jeśli tak: opcjonalnie „zarezerwować” slot L2 na czas aukcji (flaga w EstateEngine lub w EventsController), żeby dwie równoległe aukcje nie rezerwowały tego samego L2.  
  **Ryzyko:** brak atomowości przy wielu eventach – warto z góry zablokować drugą aukcję, dopóki pierwsza jest aktywna (np. `auctionState.active == true` → drugi `Auction_Start` odrzucony).

---

### KROK 4 – Ustawienie karty na Estate Agency i przycisk JOIN (EventsController)

W **EventsController** po ustawieniu stanu JOINING:

1. Pobrać obiekt karty po `cardGuid`, przenieść go na **pozycję L2** przy Estate Agency (np. stała pozycja dla „karty aukcji L2” – może być ta sama co „górna karta” L2 lub osobny slot; ważne, żeby karta nie merge’owała się z talią L2).
2. Na karcie: `clearButtons()`, potem **jedna** przycisk:  
   **„Pay 500 & Join”** (lub krótszy tekst),  
   `click_function` w EventsController, `function_owner = self` (wzorzec jak przy „Do you want to play this card?” na torze eventów).
3. Opcjonalnie: drugi przycisk „Withdraw (refund 500)” tylko w JOINING; po kliknięciu zwrot 500 i usunięcie z `participants`/`deposits`.
4. Opis karty (`setDescription` lub tooltip): np. „Joined: Blue, Yellow” – aktualizowany przy każdym dołączeniu/opuszczeniu.

**Zabezpieczenia:**

- Karta w fazie JOINING powinna być **zablokowana** (lock), żeby nie dało jej się podnieść / zmerge’ować w deck.
- Przed utworzeniem przycisków po przeniesieniu karty można dać krótkie `Wait.time(0.1–0.2)` tylko po to, żeby TTS „posadził” obiekt – **nie** budować na tym logiki czasowej; logika tylko event-driven.

---

### KROK 5 – Logika dołączenia (JOIN) w EventsController

Callback przycisku **„Pay 500 & Join”** (np. `auction_join(card, playerColor, altClick)`):

1. Sprawdzić: `auctionState.active == true` i `state == "JOINING"`.
2. Sprawdzić: ten gracz **nie** jest już w `participants`.
3. Sprawdzić środki: **500 WIN** – przez API kontrolera pieniędzy dla danego koloru (np. PlayerBoardController / MoneyController: `canSpend(500)` i `spend(500)`; w projekcie używane są tagi `WLB_MONEY` i `WLB_COLOR_*`).
4. Jeśli OK: dodać gracza do `participants`, wpisać `deposits[color]=500`, zaktualizować opis na karcie („Joined: …”), opcjonalnie krótki broadcast „Yellow joined the auction”.

**Czego unikać:**

- Trzymania depozytu jako **fizycznego tokenu** na karcie (fizyka w TTS bywa niestabilna) – tylko w stanie (tabela `deposits`).
- Zezwalania na join poza stanem JOINING – walidacja tylko w backendzie.

**Opcja „tylko w swojej turze”:**  
Jeśli reguła ma być „dołączyć można tylko w swojej turze”, w callbacku sprawdzić `playerColor == currentTurnColor` (currentTurnColor można przekazywać z TurnControllera lub odczytać z Global/TurnControllera). Jeśli docelowo część eventów ma pozwalać na decyzje **poza turą**, ten warunek można pominąć lub zrobić konfigurowalny.

---

### KROK 6 – Wykrycie momentu startu aukcji (BIDDING) – bez timerów

**Nie** używać timera ani ticku. Start BIDDING **tylko** gdy wraca **tura inicjatora** (po pełnym cyklu tur).

**Sposób A (zalecany):** **TurnController** na początku każdej tury wywołuje backend aukcji:

- W **TurnController** (`c9ee1a_TurnController.lua`) w miejscu, gdzie wykonywane są `onTurnStart_*` (tuż po `globalCall("WLB_ON_TURN_CHANGED", { newColor = c, prevColor = prev })`), dodać wywołanie EventsController, np.:  
  `getObjectFromGUID(EVENTS_CTRL_GUID).call("Auction_OnTurnStart", { activeColor = c })`  
  (GUID EventsControllera trzeba w TurnControllerze mieć – albo stała, albo tag `WLB_EVENTS_CTRL` i wyszukanie).

- W **EventsController** funkcja `Auction_OnTurnStart(activeColor)`:
  - jeśli `state ~= "JOINING"` → nic nie robić;
  - jeśli `state == "JOINING"` i `activeColor == initiatorColor` i **minął pełen cykl** (tura inicjatora po raz drugi od startu aukcji) → przełączyć na BIDDING.

**„Minął pełen cykl”:**  
Przy starcie aukcji zapisać np. `joinStartedAtTurnIndex` lub `initiatorNextTurnArmed`. Przy pierwszym wejściu w `Auction_OnTurnStart` z `activeColor == initiatorColor` ustawić „armed”; przy **drugim** takim wejściu uznać, że cykl się zamknął i wystartować BIDDING. Alternatywnie: zapisać `round`/`turnIndex` w momencie startu i sprawdzać „czy to już następna tura inicjatora” (np. indeks tury inicjatora + 1 w kolejności `finalOrder`).

**Sposób B (alternatywa):**  
Global implementuje `WLB_ON_TURN_CHANGED` i z Global wywołuje EventsController `Auction_OnTurnStart(newColor)`. Logika w EventsController ta sama; tylko „kto wywołuje” się zmienia (Global zamiast TurnController). Obie opcje są poprawne.

---

### KROK 7 – Start BIDDING w EventsController

W momencie przejścia `JOINING` → `BIDDING`:

1. Usunąć przyciski z karty (JOIN / Withdraw): `clearButtons()`.
2. Opcjonalnie: zostawić jeden przycisk „Open Auction UI” (informacyjny), jeśli panel nie jest zawsze widoczny.
3. Zbudować kolejkę licytacji:  
   `activeBidders` = lista kolorów z `participants` w **kolejności tur** (np. od `initiatorColor` według `finalOrder` z TurnControllera).  
   Ustawić `currentPrice = 1500`, `leaderColor = nil`, `currentBidderColor = firstBidder` (np. inicjator).
4. Wywołać **Global**: np. `Global.call("UI_AuctionShow", auctionStatePublic)` – żeby pokazać panel aukcji i zaktualizować go danymi (uczestnicy, cena, aktualny licytant).  
   Dane do przekazania: tylko to, co UI ma wyświetlać (state, participants, currentPrice, leaderColor, currentBidderColor), bez wrażliwych pól wewnętrznych.

---

### KROK 8 – Panel aukcji w Global UI

W **Global** (skrypt) oraz w **Global UI** (np. w tym samym pliku co Vocations UI – `VocationsUI_Global.xml` – jako drugi panel, albo osobny blok):

- **Panel** pokazuje: status (JOINING / BIDDING), listę uczestników, aktualną cenę, lidera, aktualnego licytanta.
- **Przyciski:** „Bid” i „Pass”.
- **Kto może klikać:** w BIDDING tylko gracz, którego `currentBidderColor` – w UI można wyłączyć przyciski (disabled) dla innych kolorów, ale **obowiązkowo** EventsController przy każdym kliknięciu sprawdza `playerColor == currentBidderColor` i odrzuca akcje z innego koloru.

**Przepływ:**

- Klik „Bid” / „Pass” w UI wywołuje w Global funkcję np. `UI_AuctionBid(playerColor)` / `UI_AuctionPass(playerColor)` (TTS przekazuje kolor klikającego).
- Global **nie** decyduje o regułach – tylko wywołuje EventsController:  
  `getObjectFromGUID(EVENTS_CTRL_GUID).call("Auction_OnBid", { color = playerColor, choice = "bid" })`  
  i analogicznie `Auction_OnPass`.
- EventsController po każdej akcji (Bid/Pass) aktualizuje stan i wywołuje `Global.call("UI_AuctionUpdate", stateSnapshot)`, żeby odświeżyć panel.

W Global trzeba mieć **EVENTS_CTRL_GUID** (lub wyszukanie po tagu), tak jak jest VOC_CTRL_GUID dla Vocations.

---

### KROK 9 – Logika Bid / Pass w EventsController

**Walidacja wejścia (zawsze):**

- `state == "BIDDING"`, `playerColor == currentBidderColor`, `playerColor` w `activeBidders`.  
  Jeśli nie – ignorować + ewentualnie komunikat „Not your turn to bid”.

**Bid:**

- Nowa cena: np. `currentPrice + increment` (100).  
  Sprawdzić, czy gracz ma środki na **finalną** dopłatę: `(bidPrice - 500)` (bo 500 już wpłacone).  
  API Money: np. `getMoney()` / `canSpend()` dla tego koloru.
- Jeśli OK: `leaderColor = playerColor`, `currentPrice = bidPrice`, przejść do **następnego** licytanta w `activeBidders` (jeśli następny istnieje, ustawić `currentBidderColor`; jeśli nie – patrz „Koniec licytacji”).
- Po każdej zmianie: `Global.call("UI_AuctionUpdate", ...)`.

**Pass:**

- Usunąć gracza z `activeBidders`, przejść do następnego licytanta.
- Jeśli następnego nie ma – koniec licytacji (patrz poniżej).

**Koniec licytacji:**

- Gdy `#activeBidders == 1`: zwycięzca = ten gracz.
- Gdy `#activeBidders == 0` (wszyscy spasowali od razu): brak zwycięzcy – zwrot 500 wszystkim z `deposits`, zamknąć aukcję (RESOLVED), cleanup.
- Przejście do **KROK 10 (Rozliczenie)**.

---

### KROK 10 – Rozliczenie (RESOLVED)

**Przypadek: 1 uczestnik (bez licytacji):**

- Zapytać tego gracza: „Kupujesz mieszkanie L2 za 1500 WIN?” (już wpłacił 500, więc dopłata 1000).  
  Realizacja: albo **dialog** (np. `Player[color].showConfirmDialog(...)` z callbackami), albo w **UI aukcji** przyciski „Buy” / „Decline” tylko dla tego gracza.
- **Buy:** dopłata 1000 (łącznie 1500), przydział nieruchomości L2 przez EstateEngine (ta sama ścieżka co normalny zakup).
- **Decline:** zwrot 500, brak przydziału.

**Przypadek: 2+ uczestników (licytacja była):**

- Zwycięzca (ostatni w `activeBidders`): dopłata `currentPrice - 500` (500 już w depozycie), przydział L2 przez EstateEngine.
- Pozostali: zwrot 500 każdemu z `deposits`.

**EstateEngine:**  
Użyć istniejącego API do „przydziału mieszkania L2 graczowi” (np. to samo co przy normalnym kupnie z planszy), żeby nie duplikować logiki posiadania.

---

### KROK 11 – Cleanup po RESOLVED

W EventsController po rozliczeniu:

1. `auctionState.active = false`, stan wyczyszczony.
2. Schować panel aukcji: `Global.call("UI_AuctionHide")` lub ustawić stan „Auction finished” na 1–2 s i potem schować.
3. Usunąć przyciski z karty (`clearButtons()`).
4. Kartę eventu przenieść do discard / used (zgodnie z Waszym flow eventów).
5. Odblokować kartę i ewentualną „rezerwację” L2 w EstateEngine.

**Częsty błąd:** zostawienie `auctionState.active == true` lub nie wyczyszczenie stanu → kolejne eventy lub druga aukcja mogą się nakładać.

---

## 4. Problemy typowe w TTS i jak ich unikać

| Problem | Zapobieganie |
|--------|--------------|
| **„Gramy jako White”** | W walidacji zawsze sprawdzać `playerColor`; w PROD można zablokować White; nie polegać na UI jako jedynej bramce. |
| **Karta merge’uje się z deckiem L2** | Trzymać kartę aukcji na **osobnym** slocie/pozycji (np. „auction slot L2”), nie na wierzchu talii L2; lock karty w JOINING. |
| **Przyciski nakładają się** | Zawsze `clearButtons()` przed dodaniem nowych; ewentualnie krótki Wait po przeniesieniu karty przed `createButton`. |
| **UI nie odświeża się u wszystkich** | Przy każdej zmianie stanu wysyłać **pełny** snapshot do Global (UI_AuctionUpdate); nie zakładać, że klient ma poprzedni stan. |
| **Race: dwie aukcje na raz** | W EventsController: jeśli `auctionState.active == true`, drugi `Auction_Start` odrzucić (komunikat „Auction already in progress”). |
| **Brak środków w trakcie licytacji** | Przy Bid sprawdzać „czy stać” przed przyjęciem oferty; jeśli nie – tylko Pass (albo komunikat „Insufficient funds”). Nie „rezerwować” pełnej kwoty w trakcie – tylko przy RESOLVE pobierać dopłatę. |

---

## 5. Skalowanie na kolejne eventy (15+ kart)

Żeby nie kopiować setek linii dla każdej nowej karty „join / decide / vote”:

- W EventsController wprowadzić **wspólną ramę**: np. `activeFlow = { type = "auction", ... }` i funkcje `Flow_OnTurnStart(color)`, `Flow_OnUIAction(action, payload)`.
- Aukcja = `type = "auction"` z własną maszyną stanów wewnątrz tej ramy.
- Panel UI może być **wielokrotnego użytku**: jeden „FlowPanel” z trybami (auction / vote / choose), przełączanymi w zależności od `activeFlow.type`.

To ułatwi dodawanie kolejnych ~24 eventów z podobnym wzorcem (decyzje wielu graczy, okno w czasie, itd.).

---

## 6. Podsumowanie plików i zmian

| Plik | Zmiany (krótko) |
|------|------------------|
| **1339d3_EventsController.lua** | Struktura `auctionState`, `Auction_Start`, `auction_join`, `Auction_OnTurnStart`, `Auction_OnBid`, `Auction_OnPass`, rozliczenie, cleanup, przeniesienie karty na L2, przycisk JOIN na karcie (Bid/Pass tylko w Global UI). |
| **7b92b3_EventEngine.lua** | Przy `AD_AUCTION_SCHEDULE`: wywołanie EventsController `Auction_Start`, zwrot STATUS.DONE. Opcjonalnie: sprawdzenie L2 (EstateEngine) przed startem. |
| **c9ee1a_TurnController.lua** | Po `WLB_ON_TURN_CHANGED`: wywołanie EventsController `Auction_OnTurnStart(activeColor, finalOrder)`. |
| **Global_Script_Complete.lua** | Funkcje `UI_AuctionShow`, `UI_AuctionUpdate`, `UI_AuctionHide`, `UI_AuctionBid`, `UI_AuctionPass`; wywołania EventsController. EVENTS_CTRL_GUID. |
| **VocationsUI_Global.xml** | Panel aukcji (`auctionOverlay`): teksty (cena, aktualny licytant, lider), przyciski Bid / Pass (onClick → Global). |
| **fd8ce0_EstateEngine.lua** | Przydział L2 zwycięzcy (istniejąca ścieżka kupna). |

**Przypomnienie (patrz sekcja 0):** Panel aukcji działa przez wbudowaną referencję `Global` w TTS – nie trzeba tagować żadnego obiektu.

---

Dokument można przekazać deweloperowi jako jedną całość; kolejność kroków 0→11 można traktować jako plan wdrożenia. W razie wątpliwości co do konkretnego API (Money, EstateEngine, TurnController) – najlepiej sprawdzić istniejące wywołania w `7b92b3_EventEngine.lua`, `1339d3_EventsController.lua` i `c9ee1a_TurnController.lua` i zachować ten sam styl (tagi, GUID, nazwy funkcji).
