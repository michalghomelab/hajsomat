# Portfolio Tracker — Design

**Date:** 2026-05-26
**Status:** Draft for review

## Cel

Osobista aplikacja do śledzenia portfela akcji i ETF-ów. Użytkownik dodaje
transakcje zakupu (ile, po jakiej cenie, kiedy, w jakiej walucie), a aplikacja
3 razy dziennie odświeża ceny rynkowe i kursy walut z zewnętrznego API. Raz
dziennie zapisuje migawkę (snapshot) wartości portfeli, dzięki czemu można
śledzić zysk/stratę w czasie na wykresie.

## Zakres (potwierdzony z użytkownikiem)

- **Użytkownicy:** jeden użytkownik, ale **wiele portfeli** (np. IKE,
  spekulacyjny). Bez pełnego systemu kont/logowania na start.
- **Rynki:** USA (NYSE/Nasdaq) + europejskie ETF-y UCITS (Xetra/LSE/Euronext).
  Bez GPW, bez krypto.
- **Model zakupów:** transakcje/loty. Schemat od razu przygotowany pod
  sprzedaż (`kind`: buy/sell), ale **MVP implementuje tylko zakupy**.
- **Odświeżanie:** 3x dziennie + 1 dzienny snapshot wartości portfela.
- **Waluta bazowa:** PLN (wszystkie sumy i P/L przeliczane do PLN).
- **Baza:** SQLite na start (migracja do Postgres możliwa później).
- **Stack:** Rage (Ruby, JSON API) + Svelte/Vite/Tailwind front + Twelve Data API.
- **Środowisko:** wszystko w Dockerze — nic instalowane natywnie (brak lokalnego
  Ruby/Node). `docker compose` uruchamia całość lokalnie.

## Poza zakresem (YAGNI na teraz)

- Logowanie/wielu użytkowników.
- Sprzedaże i realizacja P/L (FIFO) — schemat gotowy, implementacja później.
- Prowizje (fee) — kolumna w schemacie, ale logika i UI dopiero później.
- GPW i krypto.
- Powiadomienia, alerty cenowe.
- Dywidendy, splity, podatki.

## Zewnętrzne API: Twelve Data (free tier)

- **Limity:** ~800 kredytów/dzień, 8 zapytań/min. Pokrywa US + europejskie
  ETF-y (Xetra/LSE/Euronext via Cboe) oraz kursy walut (forex) z jednego
  źródła.
- **Budżet zapytań:** 3 odświeżenia/dzień × (unikalne tickery + ~2 pary FX).
  Przy nawet 50 instrumentach → ~156 kredytów/dzień, z dużym zapasem.
- **Endpointy:** `/quote` (cena bieżąca; batch przez `symbol=A,B,C`),
  `/exchange_rate` lub `/price` dla par walutowych (USD/PLN, EUR/PLN).
- **Klucz API:** użytkownik ma już konto/klucz; trzymany w `TWELVE_DATA_API_KEY`
  (plik `.env` poza gitem, w repo `.env.example` z placeholderem).
- **Mapowanie tickerów:** europejskie ETF-y wymagają sufiksu giełdy
  (np. `VWCE:XETR`). Pole `exchange`/`mic` na instrumencie pozwala zbudować
  poprawny symbol. Pokrycie konkretnych tickerów weryfikujemy przy
  implementacji (endpoint `/symbol_search`).

## Architektura

### Backend (Rage, JSON API)

Warstwy: kontrolery (cienkie) → serwisy (logika) → modele (**Sequel** ze SQLite;
migracje przez `Sequel.migration`).

**Modele / tabele:**

- `portfolios` — `id`, `name`, `base_currency` (default `PLN`), `created_at`.
- `instruments` — cache metadanych i ostatniej ceny per ticker.
  `id`, `symbol`, `exchange`/`mic`, `name`, `currency`, `kind` (stock/etf),
  `last_price`, `last_price_at`. Współdzielone między portfelami.
- `transactions` — `id`, `portfolio_id`, `instrument_id`, `kind`
  (buy/sell — MVP tylko buy), `quantity`, `price`, `currency`, `fee`
  (kolumna istnieje, ale **MVP jej nie używa** — UI i wycena ignorują),
  `executed_at`, `created_at`.
- `fx_rates` — `id`, `base` (np. USD), `quote` (PLN), `rate`, `fetched_at`.
  Trzymamy najświeższy kurs per para; historia opcjonalnie.
- `portfolio_snapshots` — `id`, `portfolio_id`, `date`, `total_value_pln`,
  `total_cost_pln`, `pnl_pln`. Jedna migawka na portfel na dzień.

> Uwaga: nie ma osobnej tabeli `holdings`. „Pozycja" (holding) to wynik
> agregacji transakcji danego instrumentu w portfelu — liczona w locie przez
> `ValuationService`. Upraszcza spójność danych (jedno źródło prawdy =
> transakcje). Gdy dojdą sprzedaże, agregacja zostaje, dochodzi tylko logika
> FIFO.

**Serwisy:**

- `MarketData::TwelveDataClient` — opakowuje HTTP do Twelve Data: `quotes(symbols)`,
  `fx_rate(base, quote)`. Obsługa błędów, rate-limit (8/min), parsowanie.
- `RefreshService` — orkiestruje pojedyncze odświeżenie: zbiera unikalne
  symbole ze wszystkich portfeli, woła `TwelveDataClient`, zapisuje
  `instruments.last_price` i `fx_rates`. Wywoływany przez scheduler.
- `SnapshotService` — raz dziennie: dla każdego portfela liczy wartość przez
  `ValuationService` i zapisuje `portfolio_snapshots`.
- `ValuationService` — czysta logika (bez I/O): z transakcji + ostatnich cen +
  kursów liczy dla portfela/pozycji: ilość, średnią cenę, koszt, wartość
  bieżącą, P/L (w walucie instrumentu i w PLN). Łatwo testowalna jednostkowo.

**Kontrolery / endpointy (JSON):**

- `GET /api/portfolios` — lista portfeli z podsumowaniem (wartość, P/L w PLN).
- `POST /api/portfolios` — utwórz portfel.
- `GET /api/portfolios/:id` — portfel + pozycje (zagregowane) + bieżące wyceny.
- `GET /api/portfolios/:id/snapshots` — historia migawek (dane do wykresu).
- `POST /api/portfolios/:id/transactions` — dodaj transakcję (zakup).
- `DELETE /api/transactions/:id` — usuń transakcję (korekta pomyłki).
- `POST /api/refresh` — ręczne wywołanie odświeżenia (przydatne w dev/test).
- `GET /api/instruments/search?q=` — podpowiedzi tickerów (Twelve Data
  `/symbol_search`) przy dodawaniu transakcji.

### Scheduler (rufus-scheduler, in-process)

- Uruchamiany przy starcie procesu Rage (inicjalizator).
- 3 wpisy cron na stałe pory (np. 10:00, 16:00, 22:30 CET — rano EU, otwarcie
  US, po zamknięciu US). Ostatnie odpalenie dnia wywołuje też `SnapshotService`.
- Każde odpalenie woła `RefreshService`. Błędy pojedynczych instrumentów nie
  przerywają całości; nieudane fetch-e mogą być ponawiane przez
  `Rage::Deferred` (retry z backoffem) — opcjonalne usprawnienie.

### Środowisko (Docker)

- Nic nie instalujemy natywnie — Ruby i Node żyją wyłącznie w obrazach.
- `docker-compose.yml` z usługami:
  - `api` — obraz z Ruby + Rage, montuje kod, eksponuje port API.
  - `web` — obraz z Node + Vite dev server (Svelte/Tailwind), proxy `/api` → `api`.
  - SQLite jako plik na zamontowanym wolumenie (współdzielony stan między
    restartami). Brak osobnego kontenera bazy.
- Scheduler (rufus) działa w procesie `api`, więc nie wymaga osobnej usługi.
- Klucz `TWELVE_DATA_API_KEY` wstrzykiwany przez env / plik `.env` (poza gitem).

### Frontend (Svelte + Vite + Tailwind)

- **Widok listy portfeli** — kafelki z nazwą, wartością i P/L (PLN), kolor
  zysk/strata.
- **Widok portfela** — tabela pozycji (symbol, ilość, śr. cena, cena bieżąca,
  wartość, P/L w walucie i PLN), nagłówek z sumą i datą ostatniego
  odświeżenia.
- **Formularz dodania transakcji** — wyszukiwarka tickera (autouzupełnianie z
  `/api/instruments/search`), ilość, cena, waluta, data.
- **Wykres historii zysku** — linia wartości/P-L w czasie ze snapshotów
  (lekka biblioteka wykresów, np. Chart.js lub LayerCake dla Svelte; wybór
  przy implementacji).
- Komunikacja: `fetch` do `/api`. W dev Vite proxy na port Rage.

## Przepływ danych

1. Użytkownik dodaje transakcję → `POST /transactions`. Jeśli instrument nie
   istnieje w `instruments`, tworzymy go (symbol+exchange+waluta) i próbujemy
   od razu pobrać cenę.
2. Scheduler 3x/dzień → `RefreshService`: pobiera ceny wszystkich unikalnych
   instrumentów + kursy USD/PLN, EUR/PLN → zapis do `instruments`/`fx_rates`.
3. Ostatnie odpalenie dnia → `SnapshotService`: zapis `portfolio_snapshots`.
4. Front pobiera `GET /portfolios/:id` → `ValuationService` liczy bieżącą
   wycenę w locie z najświeższych cen i kursów.
5. Wykres ← `GET /portfolios/:id/snapshots`.

## Obsługa błędów

- **API niedostępne / rate-limit:** `RefreshService` loguje i pomija dany cykl;
  zostają ostatnie znane ceny (`last_price_at` pokazuje wiek danych w UI).
- **Nieznany ticker:** `/symbol_search` nie zwraca trafienia → komunikat w
  formularzu, transakcja niezapisana albo zapisana bez ceny (do decyzji w
  implementacji; domyślnie blokujemy zapis bez rozpoznanego instrumentu).
- **Brak kursu waluty:** wycena pozycji w danej walucie pokazywana, ale suma
  PLN oznaczona jako niepełna.
- **Walidacja transakcji:** ilość > 0, cena ≥ 0, waluta z dozwolonej listy,
  data nie z przyszłości.

## Testowanie

- **Jednostkowe:** `ValuationService` (agregacja transakcji, średnia cena, P/L,
  przeliczenia walut) — kluczowa logika, pełne pokrycie. `TwelveDataClient`
  parsowanie odpowiedzi (na zapisanych fixture'ach, bez sieci).
- **Integracyjne (API):** endpointy transakcji i portfeli na testowej bazie
  SQLite; Twelve Data zamockowane (WebMock/VCR).
- **Scheduler:** test, że `RefreshService`/`SnapshotService` wołane są z
  poprawnymi argumentami (sam rufus nie testowany).
- **Front:** podstawowe testy komponentów (Vitest) dla formularza i tabeli.
- TDD zgodnie ze skillem `test-driven-development` przy implementacji.

## Otwarte kwestie do rozstrzygnięcia w implementacji

- Dokładne pory cron (strefa czasu, dni handlowe).
- Biblioteka wykresów na froncie.
- Czy blokować zapis transakcji dla nierozpoznanego tickera (domyślnie tak).
