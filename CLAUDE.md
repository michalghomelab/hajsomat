# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

hajsomat — a personal stock/ETF portfolio tracker. Prices and FX rates come from Yahoo Finance; cost basis is converted to PLN at the NBP table-A rate captured on each purchase date plus a 0.5% broker spread. README.md (in Polish) is the canonical product description. The user communicates in Polish; respond in Polish.

## Commands

Everything runs in Docker — nothing is installed natively.

```bash
docker compose up --build          # dev: API :3000, scheduler, web :5173 (use http://lvh.me:5173)
```

Tests / lint (CI runs rspec + vitest before building the prod image):

```bash
# backend (Rage image must be built first via `docker compose build api`)
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/backfill_service_spec.rb   # single file
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/backfill_service_spec.rb:42 # single example
docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rubocop

# frontend
docker run --rm -v "$PWD/web":/app -w /app node:22-slim sh -lc "npm ci && npx vitest run"
docker run --rm -v "$PWD/web":/app -w /app node:22-slim sh -lc "npm ci && npx vitest run src/lib/format.test.js"  # single file
```

RuboCop must stay green (config in `api/.rubocop.yml`: line length 120, MethodLength 25, AbcSize 25). Prefer BigDecimal for money, dry-validation contracts, dry-configurable, dry-struct; rely on Zeitwerk autoload (no manual `require` for app classes).

## Data backfills

The app deploys to a homelab, so the production DB only ever changes via code that ships with the image. **Any one-off data change (backfilling a new column, fixing rows, seeding) MUST be a Sequel migration (`api/db/migrations/`, auto-run on boot) or a rake task (`api/lib/tasks/`)** — never a script run by hand against a local container, because that change won't reach production. A self-healing path baked into normal runtime (e.g. `InstrumentNameBackfiller` filling missing names during a price refresh) is also fine, since it runs on the homelab too.

## Architecture

Two processes share one SQLite file (WAL mode, `PRAGMA foreign_keys=ON`):
- **`api`** — Rage (`rage-rb`) JSON API, routes under `/api` (`api/config/routes.rb`).
- **`scheduler`** (`api/bin/scheduler`) — standalone rufus-scheduler process (the forking app server can't reliably host a background thread). Hourly price refresh on a clock-aligned cron derived from the `refresh_interval_minutes` setting, re-applied live by a 30s watcher; daily snapshot after US close. The scheduler can't broadcast WebSocket messages itself, so after a refresh it POSTs `/api/internal/refreshed` and the web process pushes a WS "refreshed" signal to subscribers (`PricesChannel`).

In prod a single image (`deploy/`) runs nginx (serves the built SPA, proxies `/api`) + Rage + scheduler.

### Backend layering (`api/app/`)

Controllers stay thin and delegate to **service objects**. Services include `Callable` (`extend Callable`) so they're invoked as `Service.call(...)`; the module forwards to `new(...).call`.

Valuation is the core flow and is split into composable pieces:
- `InstrumentPriceMap` → `{ instrument_id => InstrumentPrice }` (a dry-struct typed view of pricing data).
- `ValuationService.positions(...)` groups transactions by instrument and calls `PositionBuilder` per instrument; `.totals(...)` rolls them up via `PositionTotals`.
- `PositionBuilder` produces a `Position` struct. Cost in PLN uses each buy's captured `fx_rate` (falls back to current rate); the broker spread (`AppConfig.fx_margin`, 0.5%) is *added* to cost and *subtracted* from market value. PLN-denominated positions skip FX and spread. Any missing rate makes the PLN cost nil → totals flagged `incomplete`.
- Presenters (`PortfolioPresenter`, etc.) serialize to JSON. `Decimals.string` renders money as plain decimal strings (`"6000.0"`, never `"0.6e4"`); pass `transactions:` to `PortfolioPresenter.call` to get the detail view with positions, omit it for the list summary.

Market data: `MarketData::YahooClient` wraps Yahoo's unofficial chart/search endpoints (quote, prices, fx_rate via `BASE QUOTE=X`, daily `history`, `symbol_search`). It returns `nil`/skips on 404 and retries once on 429. `InstrumentResolver` finds an instrument by symbol or creates one seeded from a live quote. `PurchaseFxRate` captures the NBP rate for a buy. `BackfillService` reconstructs daily snapshots backward from Yahoo history + FX, valuing each day with the transactions in effect then.

XTB import (`XtbReportImporter`): parses a "Cash Operations" `.xlsx`, dedups by operation ID stored as `external_ref` (idempotent re-upload), resolves tickers by their base (the part before the exchange suffix, e.g. `IGLN` from `IGLN.UK`) against held instruments or a Yahoo search, skips fully-sold positions, and imports all-or-nothing in a DB transaction.

Data model (Sequel models in `app/models/`, migrations in `api/db/migrations/`, auto-run on boot by `config/initializers/db.rb`): `Portfolio` 1—* `Transaction` *—1 `Instrument`; `Transaction` carries `quantity/price/currency/executed_at/fx_rate/external_ref` (buys only in MVP). `Instrument` has `symbol/mic/name/currency/kind/last_price`. `PortfolioSnapshot` stores daily value/cost; `Setting`/`AppSettings` holds the refresh interval.

### Frontend (`web/src/`)

Svelte 5 (runes: `$state`, `$effect`) + Vite + Tailwind v4 + daisyUI, ApexCharts for charts. Hash-based routing in `App.svelte` (`#/portfolio/:id`). All HTTP goes through `src/lib/api.js`. `src/lib/components/PortfolioView.svelte` is the portfolio detail view (positions, expandable transactions, refresh/backfill/import actions); `PortfolioList.svelte` is the home summary. Live price updates arrive over WebSocket via `src/lib/priceStream.js`.

### Tests

RSpec specs (`api/spec/`) boot the real Rage app against an in-memory SQLite DB and wrap each example in a rolled-back transaction (`spec/spec_helper.rb`). WebMock blocks real HTTP — stub Yahoo/NBP calls. `rack-test` drives request specs. Frontend uses Vitest + `@testing-library/svelte` (jsdom).
