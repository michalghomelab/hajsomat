# hajsomat

Osobisty tracker portfela akcji i ETF-ów — z automatycznym odświeżaniem cen, przeliczaniem na PLN po kursach NBP z dnia zakupu i historią zysku w czasie.

![CI](https://github.com/michalghomelab/hajsomat/actions/workflows/docker.yml/badge.svg)

## Funkcje

- **Wiele portfeli** (np. IKE, IKZE) z podsumowaniem zbiorczym na ekranie głównym.
- **Transakcje** zakupu — ilość, cena, waluta, data; pozycja i średnia cena liczone z transakcji.
- **Wycena**:
  - ceny i kursy walut z **Yahoo Finance** (US, GPW `.WA`, Xetra `.DE`, Milano `.MI`, LSE `.L` …),
  - koszt w PLN po **kursie NBP (tabela A) z dnia każdego zakupu** + spread brokera 0,5% (round‑trip),
  - bieżąca wartość po aktualnym kursie − 0,5%.
- **Odświeżanie cen** co godzinę w dni robocze (godziny sesji) + ręczny przycisk.
- **Historia**: dzienne snapshoty wartości i kosztu → wykresy:
  - krzywa **wartości vs wpłat** (skumulowany koszt),
  - słupki **dziennej zmiany** z rozbiciem **wpłata vs rynek**.
- **Backfill historii** z notowań Yahoo (odtworzenie snapshotów wstecz).
- Procentowy zysk, czas ostatniej aktualizacji, rozwijane zakupy per pozycja, link do wykresu Yahoo.
- **Tryb jasny/ciemny** automatycznie wg systemu (bez przełącznika).

## Stack

- **Backend:** Ruby 3.3 + [Rage](https://github.com/rage-rb/rage) (JSON API), Sequel + SQLite, dry-validation (kontrakty), dry-configurable (`AppConfig`), Zeitwerk (autoload), rufus-scheduler. Walidacja przez RuboCop, testy RSpec + WebMock.
- **Frontend:** Svelte 5 + Vite + Tailwind v4 + daisyUI, wykresy ApexCharts. Testy Vitest.
- **Źródła danych:** Yahoo Finance (ceny/kursy bieżące i historyczne), NBP API (kursy historyczne do kosztu).
- **Konteneryzacja:** Docker / Docker Compose; jeden obraz produkcyjny (nginx + Rage), CI w GitHub Actions → GHCR.

## Szybki start (dev)

Wszystko działa w Dockerze — nic nie instalujesz natywnie.

```bash
cp .env.example .env        # klucz API nie jest potrzebny (Yahoo/NBP bez klucza)
docker compose up --build
```

- Frontend: http://lvh.me:5173
- API: http://localhost:3000

Vite ma włączony polling, więc zmiany w kodzie łapią się od ręki. `docker compose watch` uruchamia synchronizację + przebudowę przy zmianie zależności.

## Jak liczona jest wycena

Dla każdej pozycji (walutowej):

```
koszt_PLN   = Σ (ilość × cena × kurs_NBP_z_dnia_zakupu) × (1 + 0,5%)
wartość_PLN = ilość × cena_bieżąca × kurs_bieżący × (1 − 0,5%)
P/L         = wartość_PLN − koszt_PLN
```

Dla pozycji w PLN kursu i spreadu nie stosujemy. Kurs NBP z dnia zakupu jest zapisywany przy transakcji (`fx_rate`), więc P/L odzwierciedla też zmianę kursu od momentu zakupu (zgodnie z tym, co pokazuje broker).

## Testy

```bash
# backend
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rubocop
# frontend
docker run --rm -v "$PWD/web":/app -w /app node:22-slim sh -lc "npm ci && npx vitest run"
```

CI (GitHub Actions) odpala rspec + vitest przed buildem — obraz powstaje tylko, gdy testy są zielone.

## Produkcja (homelab)

Push do `master` → testy → build → **jeden obraz** w GHCR (`ghcr.io/michalghomelab/hajsomat`).

```bash
docker login ghcr.io                                   # PAT z read:packages
docker compose -f docker-compose.prod.yml up -d        # nginx + Rage, port 8080

# przeniesienie bazy z deva (opcjonalnie)
docker compose cp api:/data/portfolio.sqlite3 ./portfolio.sqlite3        # z deva
docker compose -f docker-compose.prod.yml cp ./portfolio.sqlite3 app:/data/portfolio.sqlite3
docker compose -f docker-compose.prod.yml restart app
```

Obraz produkcyjny: nginx serwuje statyczny front i proxuje `/api` do Rage w tym samym kontenerze; baza SQLite na wolumenie; scheduler startuje automatycznie.

## Struktura

```
api/        # Rage API: modele, serwisy, kontrakty, kontrolery, migracje, testy
web/        # Svelte + Vite: komponenty, wykresy, testy
deploy/     # produkcyjny Dockerfile (jeden obraz), nginx.conf, entrypoint
docs/       # spec i plan implementacji
docker-compose.yml        # dev
docker-compose.prod.yml   # prod (obraz z GHCR)
```

## Roadmap

- [ ] Polskie obligacje skarbowe (ROD/ROS) — portfel obligacyjny z wgrywanym „Stanem Rachunku Rejestrowego".
- [ ] Importer XTB w aplikacji (upload `.xlsx`, dedup po ID transakcji).
- [ ] Obsługa sprzedaży (pozycje netto, realizacja zysku).

## Uwagi

- API Yahoo jest nieoficjalne — może się zmienić; klient ma retry na 429 i pomija pojedyncze błędne walory.
- Spread 0,5% to przybliżenie marży brokera; kurs bazowy jest średni (NBP/Yahoo mid).
