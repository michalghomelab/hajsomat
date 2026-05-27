# Portfolio Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal stock/ETF portfolio tracker where the user records buy transactions, prices and FX refresh 3×/day, and daily snapshots feed a profit-over-time chart.

**Architecture:** Rage JSON API (Ruby 3.3+) with Sequel/SQLite, a pure `ValuationService` aggregating transactions into positions, a `TwelveDataClient` for prices + FX, a `RefreshService`/`SnapshotService` driven by an in-process rufus-scheduler, and a Svelte/Vite/Tailwind SPA. Everything runs in Docker; nothing is installed natively.

**Tech Stack:** Ruby 3.3 + Rage + Sequel + SQLite; rufus-scheduler; RSpec + WebMock. Svelte + Vite + Tailwind + Vitest. Docker Compose.

**Valuation convention (MVP):** All PLN conversions — cost and current value — use the *latest* FX rate. `pnl_pln = (market_value_native − cost_native) × latest_fx`. True currency P/L (FX at purchase time) is a documented future enhancement; we keep only the latest rate per pair.

**Money types:** All quantities, prices and rates are stored and computed as `BigDecimal` (Sequel `decimal`/`numeric` columns map to `BigDecimal`). Never use `Float` for money.

---

## File Structure

**Backend (`api/`):**
- `api/Gemfile` — gems: rage, sequel, sqlite3, rufus-scheduler; group test: rspec, webmock.
- `api/config/routes.rb` — all `/api/*` routes.
- `api/config/initializers/db.rb` — Sequel connection + auto-migrate.
- `api/config/initializers/scheduler.rb` — rufus-scheduler entries.
- `api/db/migrations/*.rb` — Sequel migrations (one per table).
- `api/app/models/{portfolio,instrument,transaction,fx_rate,portfolio_snapshot}.rb` — Sequel models.
- `api/app/services/valuation_service.rb` — pure aggregation logic (no I/O).
- `api/app/services/market_data/twelve_data_client.rb` — HTTP client.
- `api/app/services/refresh_service.rb` — fetch prices + FX, persist.
- `api/app/services/snapshot_service.rb` — write daily snapshots.
- `api/app/controllers/{portfolios,transactions,instruments,refresh}_controller.rb`.
- `api/spec/**` — RSpec specs mirroring the above.

**Frontend (`web/`):**
- `web/src/lib/api.js` — fetch wrapper for the API.
- `web/src/lib/format.js` — money/percent formatting + pnl helpers.
- `web/src/lib/components/{PortfolioList,PortfolioView,TransactionForm,PnlChart}.svelte`.
- `web/src/App.svelte`, `web/src/main.js`, `web/src/app.css` (Tailwind).
- `web/src/lib/format.test.js` — Vitest unit tests.

**Root:**
- `docker-compose.yml`, `api/Dockerfile`, `web/Dockerfile`, `.env.example`, `.gitignore`.

---

## Phase 0 — Docker + scaffold + Sequel smoke test

### Task 0.1: Repo hygiene files

**Files:**
- Create: `.gitignore`, `.env.example`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# Ruby
api/.bundle/
api/vendor/bundle/
*.gem
# DB
db/*.sqlite3
api/db/*.sqlite3
# Node
web/node_modules/
web/dist/
# Env
.env
# OS
.DS_Store
```

- [ ] **Step 2: Write `.env.example`**

```dotenv
# Twelve Data API key (free tier). Copy this file to .env and fill in.
TWELVE_DATA_API_KEY=your_key_here
# SQLite location inside the api container
DATABASE_URL=sqlite:///data/portfolio.sqlite3
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore .env.example
git commit -m "chore: add gitignore and env example"
```

### Task 0.2: Scaffold the Rage API in Docker

**Files:**
- Create: `api/Dockerfile`, `api/Gemfile`

We generate the Rage app *inside* a container so nothing is installed natively.

- [ ] **Step 1: Write a throwaway generator Dockerfile step** — run the generator via a one-off container

Run:
```bash
docker run --rm -v "$PWD/api":/out -w /out ruby:3.3-slim bash -lc \
  "apt-get update -qq && apt-get install -y build-essential git libsqlite3-dev >/dev/null && gem install rage-rb && rage new . -d sqlite3 --skip-git || true && ls -la"
```
Expected: `app/`, `config/`, `db/`, `Gemfile` appear under `api/`.

- [ ] **Step 2: Replace `api/Gemfile`** with our explicit dependency set

```ruby
source "https://rubygems.org"
ruby "3.3.0"

gem "rage-rb"
gem "sequel"
gem "sqlite3"
gem "rufus-scheduler"

group :development, :test do
  gem "rspec"
  gem "webmock"
end
```

- [ ] **Step 3: Write `api/Dockerfile`**

```dockerfile
FROM ruby:3.3-slim
RUN apt-get update -qq && apt-get install -y build-essential libsqlite3-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN gem install bundler && bundle install
COPY . .
EXPOSE 3000
CMD ["bundle", "exec", "rage", "s", "-b", "0.0.0.0"]
```

- [ ] **Step 4: Build and verify bundle installs**

Run: `docker build -t portfolio-api ./api`
Expected: build succeeds; `bundle install` resolves rage, sequel, sqlite3, rufus-scheduler.

- [ ] **Step 5: Commit**

```bash
git add api/Dockerfile api/Gemfile api/app api/config api/db api/Gemfile.lock
git commit -m "chore: scaffold Rage API with Sequel deps in Docker"
```

### Task 0.3: Wire Sequel connection + auto-migration

**Files:**
- Create: `api/config/initializers/db.rb`
- Create: `api/db/migrations/001_create_portfolios.rb`

- [ ] **Step 1: Write the DB initializer**

```ruby
# api/config/initializers/db.rb
require "sequel"

DB = Sequel.connect(ENV.fetch("DATABASE_URL", "sqlite://db/portfolio.sqlite3"))
DB.run("PRAGMA foreign_keys = ON") if DB.adapter_scheme == :sqlite

Sequel.extension :migration
migrations_path = File.expand_path("../../db/migrations", __dir__)
Sequel::Migrator.run(DB, migrations_path) if Dir.exist?(migrations_path)
```

- [ ] **Step 2: Write the first migration**

```ruby
# api/db/migrations/001_create_portfolios.rb
Sequel.migration do
  change do
    create_table(:portfolios) do
      primary_key :id
      String :name, null: false
      String :base_currency, null: false, default: "PLN"
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
```

- [ ] **Step 3: Verify migration runs and table exists**

Run:
```bash
docker run --rm -e DATABASE_URL=sqlite:///tmp/test.sqlite3 -v "$PWD/api":/app -w /app portfolio-api \
  bundle exec ruby -e 'require "./config/initializers/db"; puts DB.tables.inspect'
```
Expected: output includes `:portfolios` and `:schema_info`.

- [ ] **Step 4: Commit**

```bash
git add api/config/initializers/db.rb api/db/migrations/001_create_portfolios.rb
git commit -m "feat: wire Sequel connection with auto-migration"
```

### Task 0.4: RSpec harness

**Files:**
- Create: `api/.rspec`, `api/spec/spec_helper.rb`

- [ ] **Step 1: Write `api/.rspec`**

```
--require spec_helper
--format documentation
```

- [ ] **Step 2: Write `api/spec/spec_helper.rb`**

```ruby
ENV["DATABASE_URL"] = "sqlite::memory:"
require "webmock/rspec"
require "sequel"
require "bigdecimal"

DB = Sequel.connect(ENV["DATABASE_URL"])
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path("../db/migrations", __dir__))

RSpec.configure do |config|
  config.around(:each) do |example|
    DB.transaction(rollback: :always) { example.run }
  end
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
```

> Note: `spec_helper` owns its own in-memory `DB` and runs migrations once at load; the `config/initializers/db.rb` connection is for the running server only. Each test runs inside a rolled-back transaction for isolation.

- [ ] **Step 3: Add a trivial passing spec to prove the harness**

```ruby
# api/spec/harness_spec.rb
RSpec.describe "harness" do
  it "has the portfolios table" do
    expect(DB.tables).to include(:portfolios)
  end
end
```

- [ ] **Step 4: Run it**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec`
Expected: 1 example, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/.rspec api/spec/spec_helper.rb api/spec/harness_spec.rb
git commit -m "test: add RSpec + WebMock harness with in-memory DB"
```

---

## Phase 1 — Schema + models

### Task 1.1: Instruments migration + model

**Files:**
- Create: `api/db/migrations/002_create_instruments.rb`
- Create: `api/app/models/instrument.rb`
- Test: `api/spec/models/instrument_spec.rb`

- [ ] **Step 1: Write the migration**

```ruby
# api/db/migrations/002_create_instruments.rb
Sequel.migration do
  change do
    create_table(:instruments) do
      primary_key :id
      String :symbol, null: false
      String :mic            # exchange MIC, e.g. XETR; null for plain US tickers
      String :name
      String :currency, null: false   # USD, EUR, ...
      String :kind, null: false, default: "etf"  # stock|etf
      BigDecimal :last_price, size: [20, 6]
      DateTime :last_price_at
      index [:symbol, :mic], unique: true
    end
  end
end
```

- [ ] **Step 2: Write a failing model spec**

```ruby
# api/spec/models/instrument_spec.rb
require "instrument"

RSpec.describe Instrument do
  it "builds the Twelve Data symbol with MIC suffix when present" do
    i = Instrument.new(symbol: "VWCE", mic: "XETR", currency: "EUR")
    expect(i.td_symbol).to eq("VWCE:XETR")
  end

  it "uses the bare symbol for US tickers without a MIC" do
    i = Instrument.new(symbol: "AAPL", mic: nil, currency: "USD")
    expect(i.td_symbol).to eq("AAPL")
  end
end
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/instrument_spec.rb`
Expected: FAIL — `cannot load such file -- instrument` / uninitialized constant.

- [ ] **Step 4: Write the model**

```ruby
# api/app/models/instrument.rb
class Instrument < Sequel::Model
  def td_symbol
    mic && !mic.empty? ? "#{symbol}:#{mic}" : symbol
  end
end
```

- [ ] **Step 5: Add the model load path to spec_helper**

In `api/spec/spec_helper.rb`, after the migrator line add:
```ruby
$LOAD_PATH.unshift File.expand_path("../app/models", __dir__)
```

- [ ] **Step 6: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/instrument_spec.rb`
Expected: 2 examples, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add api/db/migrations/002_create_instruments.rb api/app/models/instrument.rb api/spec/models/instrument_spec.rb api/spec/spec_helper.rb
git commit -m "feat: add instruments table and model with td_symbol"
```

### Task 1.2: Transactions migration + model

**Files:**
- Create: `api/db/migrations/003_create_transactions.rb`
- Create: `api/app/models/transaction.rb`
- Create: `api/app/models/portfolio.rb`
- Test: `api/spec/models/transaction_spec.rb`

- [ ] **Step 1: Write the migration**

```ruby
# api/db/migrations/003_create_transactions.rb
Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false, on_delete: :cascade
      foreign_key :instrument_id, :instruments, null: false
      String :kind, null: false, default: "buy"   # buy|sell (MVP: buy only)
      BigDecimal :quantity, size: [20, 6], null: false
      BigDecimal :price, size: [20, 6], null: false        # in instrument currency
      String :currency, null: false
      BigDecimal :fee, size: [20, 6]                       # unused in MVP
      DateTime :executed_at, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
```

- [ ] **Step 2: Write a failing spec for validation**

```ruby
# api/spec/models/transaction_spec.rb
require "portfolio"
require "instrument"
require "transaction"

RSpec.describe Transaction do
  let(:portfolio) { Portfolio.create(name: "Main") }
  let(:instrument) { Instrument.create(symbol: "AAPL", currency: "USD") }

  it "is valid for a positive buy" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 10, price: 150, currency: "USD",
                         executed_at: Time.now)
    expect(t.valid?).to be true
  end

  it "rejects non-positive quantity" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 0, price: 150, currency: "USD",
                         executed_at: Time.now)
    expect(t.valid?).to be false
    expect(t.errors[:quantity]).not_to be_empty
  end

  it "rejects a future executed_at" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 1, price: 1, currency: "USD",
                         executed_at: Time.now + 86_400)
    expect(t.valid?).to be false
  end
end
```

- [ ] **Step 3: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/transaction_spec.rb`
Expected: FAIL — uninitialized constant Transaction.

- [ ] **Step 4: Write the models**

```ruby
# api/app/models/portfolio.rb
class Portfolio < Sequel::Model
  one_to_many :transactions
  one_to_many :portfolio_snapshots
end
```

```ruby
# api/app/models/transaction.rb
class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :instrument

  def validate
    super
    errors.add(:quantity, "must be > 0") if quantity.nil? || quantity <= 0
    errors.add(:price, "must be >= 0") if price.nil? || price < 0
    errors.add(:kind, "must be buy or sell") unless %w[buy sell].include?(kind)
    errors.add(:executed_at, "cannot be in the future") if executed_at && executed_at > Time.now
  end
end
```

- [ ] **Step 5: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/transaction_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add api/db/migrations/003_create_transactions.rb api/app/models/transaction.rb api/app/models/portfolio.rb api/spec/models/transaction_spec.rb
git commit -m "feat: add transactions + portfolio models with validation"
```

### Task 1.3: FX rates + snapshots migrations and models

**Files:**
- Create: `api/db/migrations/004_create_fx_rates.rb`
- Create: `api/db/migrations/005_create_portfolio_snapshots.rb`
- Create: `api/app/models/fx_rate.rb`, `api/app/models/portfolio_snapshot.rb`
- Test: `api/spec/models/fx_rate_spec.rb`

- [ ] **Step 1: Write the FX migration**

```ruby
# api/db/migrations/004_create_fx_rates.rb
Sequel.migration do
  change do
    create_table(:fx_rates) do
      primary_key :id
      String :base, null: false    # e.g. USD
      String :quote, null: false   # e.g. PLN
      BigDecimal :rate, size: [20, 8], null: false
      DateTime :fetched_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      index [:base, :quote], unique: true
    end
  end
end
```

- [ ] **Step 2: Write the snapshots migration**

```ruby
# api/db/migrations/005_create_portfolio_snapshots.rb
Sequel.migration do
  change do
    create_table(:portfolio_snapshots) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false, on_delete: :cascade
      Date :date, null: false
      BigDecimal :total_value_pln, size: [20, 2], null: false
      BigDecimal :total_cost_pln, size: [20, 2], null: false
      BigDecimal :pnl_pln, size: [20, 2], null: false
      index [:portfolio_id, :date], unique: true
    end
  end
end
```

- [ ] **Step 3: Write a failing spec for `FxRate.upsert_rate`**

```ruby
# api/spec/models/fx_rate_spec.rb
require "fx_rate"

RSpec.describe FxRate do
  it "inserts then updates the same base/quote pair" do
    FxRate.upsert_rate("USD", "PLN", BigDecimal("4.10"))
    FxRate.upsert_rate("USD", "PLN", BigDecimal("4.25"))
    rows = FxRate.where(base: "USD", quote: "PLN").all
    expect(rows.size).to eq(1)
    expect(rows.first.rate).to eq(BigDecimal("4.25"))
  end
end
```

- [ ] **Step 4: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/fx_rate_spec.rb`
Expected: FAIL — uninitialized constant FxRate.

- [ ] **Step 5: Write the models**

```ruby
# api/app/models/fx_rate.rb
class FxRate < Sequel::Model
  def self.upsert_rate(base, quote, rate)
    row = self[base: base, quote: quote]
    if row
      row.update(rate: rate, fetched_at: Time.now)
    else
      create(base: base, quote: quote, rate: rate, fetched_at: Time.now)
    end
  end
end
```

```ruby
# api/app/models/portfolio_snapshot.rb
class PortfolioSnapshot < Sequel::Model
  many_to_one :portfolio
end
```

- [ ] **Step 6: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/models/fx_rate_spec.rb`
Expected: 1 example, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add api/db/migrations/004_create_fx_rates.rb api/db/migrations/005_create_portfolio_snapshots.rb api/app/models/fx_rate.rb api/app/models/portfolio_snapshot.rb api/spec/models/fx_rate_spec.rb
git commit -m "feat: add fx_rates and portfolio_snapshots tables and models"
```

---

## Phase 2 — ValuationService (pure logic, the heart)

`ValuationService` takes plain data (no DB, no HTTP) so it is exhaustively testable. Callers (controllers, snapshot service) fetch rows and pass them in.

### Task 2.1: Position aggregation

**Files:**
- Create: `api/app/services/valuation_service.rb`
- Test: `api/spec/services/valuation_service_spec.rb`

**Interface (defined once, used everywhere):**
- `Position = Struct.new(:instrument_id, :symbol, :currency, :quantity, :avg_price, :cost_native, :last_price, :market_value_native, :pnl_native, :market_value_pln, :cost_pln, :pnl_pln, keyword_init: true)`
- `ValuationService.positions(transactions:, instruments_by_id:, fx_to_pln:)` → `Array<Position>`
  - `transactions`: array of objects with `.instrument_id`, `.quantity` (BigDecimal), `.price` (BigDecimal). MVP: all `kind == "buy"`.
  - `instruments_by_id`: `Hash{Integer => {symbol:, currency:, last_price:}}` (values are BigDecimal for `last_price`, may be `nil`).
  - `fx_to_pln`: `Hash{String => BigDecimal}` mapping currency → rate to PLN. `"PLN" => 1`.
- `ValuationService.totals(positions)` → `{ market_value_pln:, cost_pln:, pnl_pln: }` (all BigDecimal).

- [ ] **Step 1: Write the failing spec for a single-currency position**

```ruby
# api/spec/services/valuation_service_spec.rb
require "bigdecimal"
require "valuation_service"

Txn = Struct.new(:instrument_id, :quantity, :price, keyword_init: true)

RSpec.describe ValuationService do
  def bd(x) = BigDecimal(x.to_s)

  it "aggregates two buys of one USD instrument and converts to PLN" do
    txns = [
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(100)),
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(120)),
    ]
    instruments = { 1 => { symbol: "AAPL", currency: "USD", last_price: bd(150) } }
    fx = { "USD" => bd(4), "PLN" => bd(1) }

    pos = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx)
    expect(pos.size).to eq(1)
    p = pos.first
    expect(p.quantity).to eq(bd(20))
    expect(p.cost_native).to eq(bd(2200))         # 10*100 + 10*120
    expect(p.avg_price).to eq(bd(110))            # 2200 / 20
    expect(p.market_value_native).to eq(bd(3000)) # 20 * 150
    expect(p.pnl_native).to eq(bd(800))           # 3000 - 2200
    expect(p.market_value_pln).to eq(bd(12000))   # 3000 * 4
    expect(p.cost_pln).to eq(bd(8800))            # 2200 * 4
    expect(p.pnl_pln).to eq(bd(3200))             # 12000 - 8800
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/valuation_service_spec.rb`
Expected: FAIL — uninitialized constant ValuationService.

- [ ] **Step 3: Add the services load path to spec_helper**

In `api/spec/spec_helper.rb` add next to the models path line:
```ruby
$LOAD_PATH.unshift File.expand_path("../app/services", __dir__)
```

- [ ] **Step 4: Write the implementation**

```ruby
# api/app/services/valuation_service.rb
require "bigdecimal"

class ValuationService
  Position = Struct.new(
    :instrument_id, :symbol, :currency, :quantity, :avg_price, :cost_native,
    :last_price, :market_value_native, :pnl_native,
    :market_value_pln, :cost_pln, :pnl_pln, keyword_init: true
  )

  def self.positions(transactions:, instruments_by_id:, fx_to_pln:)
    grouped = transactions.group_by(&:instrument_id)
    grouped.map do |instrument_id, txns|
      meta = instruments_by_id.fetch(instrument_id)
      currency = meta[:currency]
      quantity = txns.sum(BigDecimal(0)) { |t| t.quantity }
      cost_native = txns.sum(BigDecimal(0)) { |t| t.quantity * t.price }
      avg_price = quantity.zero? ? BigDecimal(0) : cost_native / quantity
      last_price = meta[:last_price]
      fx = fx_to_pln[currency]

      market_value_native = last_price ? quantity * last_price : nil
      pnl_native = market_value_native ? market_value_native - cost_native : nil
      market_value_pln = (market_value_native && fx) ? market_value_native * fx : nil
      cost_pln = fx ? cost_native * fx : nil
      pnl_pln = (market_value_pln && cost_pln) ? market_value_pln - cost_pln : nil

      Position.new(
        instrument_id: instrument_id, symbol: meta[:symbol], currency: currency,
        quantity: quantity, avg_price: avg_price, cost_native: cost_native,
        last_price: last_price, market_value_native: market_value_native,
        pnl_native: pnl_native, market_value_pln: market_value_pln,
        cost_pln: cost_pln, pnl_pln: pnl_pln
      )
    end
  end

  def self.totals(positions)
    {
      market_value_pln: positions.sum(BigDecimal(0)) { |p| p.market_value_pln || BigDecimal(0) },
      cost_pln: positions.sum(BigDecimal(0)) { |p| p.cost_pln || BigDecimal(0) },
      pnl_pln: positions.sum(BigDecimal(0)) { |p| p.pnl_pln || BigDecimal(0) },
    }
  end
end
```

- [ ] **Step 5: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/valuation_service_spec.rb`
Expected: 1 example, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add api/app/services/valuation_service.rb api/spec/services/valuation_service_spec.rb api/spec/spec_helper.rb
git commit -m "feat: ValuationService position aggregation with PLN conversion"
```

### Task 2.2: Multi-currency totals + missing-data handling

**Files:**
- Modify: `api/spec/services/valuation_service_spec.rb`

- [ ] **Step 1: Add failing specs for totals and missing price/FX**

```ruby
  it "sums totals across USD and EUR positions" do
    txns = [
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(100)), # USD
      Txn.new(instrument_id: 2, quantity: bd(5),  price: bd(50)),  # EUR
    ]
    instruments = {
      1 => { symbol: "AAPL", currency: "USD", last_price: bd(120) },
      2 => { symbol: "VWCE", currency: "EUR", last_price: bd(60) },
    }
    fx = { "USD" => bd(4), "EUR" => bd(4.3), "PLN" => bd(1) }

    pos = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx)
    totals = described_class.totals(pos)
    # USD: value 1200*4=4800, cost 1000*4=4000 ; EUR: value 300*4.3=1290, cost 250*4.3=1075
    expect(totals[:market_value_pln]).to eq(bd(6090))
    expect(totals[:cost_pln]).to eq(bd(5075))
    expect(totals[:pnl_pln]).to eq(bd(1015))
  end

  it "leaves PLN fields nil when last_price is missing" do
    txns = [Txn.new(instrument_id: 1, quantity: bd(1), price: bd(10))]
    instruments = { 1 => { symbol: "X", currency: "USD", last_price: nil } }
    fx = { "USD" => bd(4), "PLN" => bd(1) }
    p = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx).first
    expect(p.market_value_native).to be_nil
    expect(p.pnl_pln).to be_nil
    expect(p.cost_pln).to eq(bd(40)) # cost still converts with FX
  end

  it "treats nil PLN values as zero in totals" do
    txns = [Txn.new(instrument_id: 1, quantity: bd(1), price: bd(10))]
    instruments = { 1 => { symbol: "X", currency: "USD", last_price: nil } }
    fx = { "USD" => bd(4), "PLN" => bd(1) }
    totals = described_class.totals(described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx))
    expect(totals[:market_value_pln]).to eq(bd(0))
  end
```

- [ ] **Step 2: Run — they should already pass against the Task 2.1 implementation**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/valuation_service_spec.rb`
Expected: 4 examples, 0 failures. (If any fail, fix `valuation_service.rb` until green — do not change the tests.)

- [ ] **Step 3: Commit**

```bash
git add api/spec/services/valuation_service_spec.rb
git commit -m "test: cover multi-currency totals and missing-data valuation"
```

---

## Phase 3 — Twelve Data client

### Task 3.1: Price fetching (single + batch)

**Files:**
- Create: `api/app/services/market_data/twelve_data_client.rb`
- Test: `api/spec/services/market_data/twelve_data_client_spec.rb`

**Interface:**
- `MarketData::TwelveDataClient.new(api_key:, http_base: "https://api.twelvedata.com")`
- `#prices(symbols)` → `Hash{String => BigDecimal}` keyed by the symbol string passed in. Missing/invalid symbols are omitted.
- `#fx_rate(base, quote)` → `BigDecimal`.

Twelve Data `/price` returns `{"price":"150.1"}` for one symbol and `{"AAPL":{"price":"150.1"},"MSFT":{"price":"410.2"}}` for many. `/exchange_rate?symbol=USD/PLN` returns `{"symbol":"USD/PLN","rate":4.12,...}`.

- [ ] **Step 1: Write failing specs with WebMock stubs**

```ruby
# api/spec/services/market_data/twelve_data_client_spec.rb
require "bigdecimal"
require "market_data/twelve_data_client"

RSpec.describe MarketData::TwelveDataClient do
  let(:client) { described_class.new(api_key: "TESTKEY") }

  it "parses a single-symbol price response" do
    stub_request(:get, "https://api.twelvedata.com/price")
      .with(query: { symbol: "AAPL", apikey: "TESTKEY" })
      .to_return(status: 200, body: '{"price":"150.10"}', headers: { "Content-Type" => "application/json" })

    expect(client.prices(["AAPL"])).to eq({ "AAPL" => BigDecimal("150.10") })
  end

  it "parses a multi-symbol price response" do
    stub_request(:get, "https://api.twelvedata.com/price")
      .with(query: { symbol: "AAPL,MSFT", apikey: "TESTKEY" })
      .to_return(status: 200, body: '{"AAPL":{"price":"150.10"},"MSFT":{"price":"410.20"}}',
                 headers: { "Content-Type" => "application/json" })

    expect(client.prices(["AAPL", "MSFT"]))
      .to eq({ "AAPL" => BigDecimal("150.10"), "MSFT" => BigDecimal("410.20") })
  end

  it "omits symbols whose response carries an error status" do
    stub_request(:get, "https://api.twelvedata.com/price")
      .with(query: { symbol: "BAD", apikey: "TESTKEY" })
      .to_return(status: 200, body: '{"status":"error","message":"symbol not found"}',
                 headers: { "Content-Type" => "application/json" })

    expect(client.prices(["BAD"])).to eq({})
  end

  it "parses an exchange rate" do
    stub_request(:get, "https://api.twelvedata.com/exchange_rate")
      .with(query: { symbol: "USD/PLN", apikey: "TESTKEY" })
      .to_return(status: 200, body: '{"symbol":"USD/PLN","rate":4.12}',
                 headers: { "Content-Type" => "application/json" })

    expect(client.fx_rate("USD", "PLN")).to eq(BigDecimal("4.12"))
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/market_data/twelve_data_client_spec.rb`
Expected: FAIL — cannot load market_data/twelve_data_client.

- [ ] **Step 3: Write the client**

```ruby
# api/app/services/market_data/twelve_data_client.rb
require "net/http"
require "json"
require "bigdecimal"
require "uri"

module MarketData
  class TwelveDataClient
    def initialize(api_key: ENV.fetch("TWELVE_DATA_API_KEY"), http_base: "https://api.twelvedata.com")
      @api_key = api_key
      @http_base = http_base
    end

    def prices(symbols)
      return {} if symbols.empty?
      body = get("/price", symbol: symbols.join(","))
      result = {}
      if symbols.size == 1
        sym = symbols.first
        result[sym] = BigDecimal(body["price"]) if body["price"]
      else
        symbols.each do |sym|
          node = body[sym]
          result[sym] = BigDecimal(node["price"]) if node.is_a?(Hash) && node["price"]
        end
      end
      result
    end

    def fx_rate(base, quote)
      body = get("/exchange_rate", symbol: "#{base}/#{quote}")
      BigDecimal(body.fetch("rate").to_s)
    end

    private

    def get(path, params)
      uri = URI("#{@http_base}#{path}")
      uri.query = URI.encode_www_form(params.merge(apikey: @api_key))
      res = Net::HTTP.get_response(uri)
      JSON.parse(res.body)
    end
  end
end
```

- [ ] **Step 4: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/market_data/twelve_data_client_spec.rb`
Expected: 4 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/app/services/market_data/twelve_data_client.rb api/spec/services/market_data/twelve_data_client_spec.rb
git commit -m "feat: TwelveDataClient for prices and FX with WebMock specs"
```

---

## Phase 4 — RefreshService + SnapshotService

### Task 4.1: RefreshService

**Files:**
- Create: `api/app/services/refresh_service.rb`
- Test: `api/spec/services/refresh_service_spec.rb`

**Interface:**
- `RefreshService.new(client:)` (client defaults to `MarketData::TwelveDataClient.new`).
- `#call` — collects distinct instruments across all transactions, fetches prices (one batch per currency-group not required; one batch overall keyed by `td_symbol`), writes `last_price`/`last_price_at`; fetches FX for each non-PLN currency in use and upserts `fx_rates`. Returns a summary hash `{ instruments_updated:, fx_updated: }`.

- [ ] **Step 1: Write a failing spec with a fake client**

```ruby
# api/spec/services/refresh_service_spec.rb
require "bigdecimal"
require "portfolio"; require "instrument"; require "transaction"; require "fx_rate"
require "refresh_service"

RSpec.describe RefreshService do
  let(:portfolio) { Portfolio.create(name: "Main") }
  let(:aapl) { Instrument.create(symbol: "AAPL", currency: "USD") }
  let(:vwce) { Instrument.create(symbol: "VWCE", mic: "XETR", currency: "EUR") }

  before do
    Transaction.create(portfolio_id: portfolio.id, instrument_id: aapl.id, kind: "buy",
                       quantity: 1, price: 100, currency: "USD", executed_at: Time.now)
    Transaction.create(portfolio_id: portfolio.id, instrument_id: vwce.id, kind: "buy",
                       quantity: 1, price: 50, currency: "EUR", executed_at: Time.now)
  end

  let(:fake_client) do
    Class.new do
      def prices(symbols)
        { "AAPL" => BigDecimal("150"), "VWCE:XETR" => BigDecimal("60") }
          .slice(*symbols)
      end
      def fx_rate(base, _quote) = base == "USD" ? BigDecimal("4.0") : BigDecimal("4.3")
    end.new
  end

  it "updates instrument prices and FX rates" do
    summary = described_class.new(client: fake_client).call

    expect(aapl.refresh.last_price).to eq(BigDecimal("150"))
    expect(vwce.refresh.last_price).to eq(BigDecimal("60"))
    expect(FxRate[base: "USD", quote: "PLN"].rate).to eq(BigDecimal("4.0"))
    expect(FxRate[base: "EUR", quote: "PLN"].rate).to eq(BigDecimal("4.3"))
    expect(summary[:instruments_updated]).to eq(2)
    expect(summary[:fx_updated]).to eq(2)
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/refresh_service_spec.rb`
Expected: FAIL — uninitialized constant RefreshService.

- [ ] **Step 3: Write the service**

```ruby
# api/app/services/refresh_service.rb
require "market_data/twelve_data_client"

class RefreshService
  BASE_CURRENCY = "PLN"

  def initialize(client: MarketData::TwelveDataClient.new)
    @client = client
  end

  def call
    instruments = instruments_in_use
    instruments_updated = update_prices(instruments)
    fx_updated = update_fx(instruments)
    { instruments_updated: instruments_updated, fx_updated: fx_updated }
  end

  private

  def instruments_in_use
    ids = Transaction.distinct.select_map(:instrument_id)
    Instrument.where(id: ids).all
  end

  def update_prices(instruments)
    return 0 if instruments.empty?
    by_td = instruments.to_h { |i| [i.td_symbol, i] }
    prices = @client.prices(by_td.keys)
    updated = 0
    prices.each do |td_symbol, price|
      inst = by_td[td_symbol]
      next unless inst
      inst.update(last_price: price, last_price_at: Time.now)
      updated += 1
    end
    updated
  end

  def update_fx(instruments)
    currencies = instruments.map(&:currency).uniq.reject { |c| c == BASE_CURRENCY }
    currencies.each do |cur|
      rate = @client.fx_rate(cur, BASE_CURRENCY)
      FxRate.upsert_rate(cur, BASE_CURRENCY, rate)
    end
    currencies.size
  end
end
```

- [ ] **Step 4: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/refresh_service_spec.rb`
Expected: 1 example, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/app/services/refresh_service.rb api/spec/services/refresh_service_spec.rb
git commit -m "feat: RefreshService updates instrument prices and FX rates"
```

### Task 4.2: SnapshotService

**Files:**
- Create: `api/app/services/snapshot_service.rb`
- Test: `api/spec/services/snapshot_service_spec.rb`

**Interface:**
- `SnapshotService.new` ; `#call(date: Date.today)` — for each portfolio, builds positions via `ValuationService` (using current `instruments.last_price` + latest `fx_rates`), computes totals, upserts one `portfolio_snapshots` row per portfolio per date. Returns count of snapshots written.
- Helper (shared with controllers, defined here): `SnapshotService.fx_to_pln` → `Hash{String=>BigDecimal}` built from `fx_rates` plus `"PLN" => 1`.

- [ ] **Step 1: Write a failing spec**

```ruby
# api/spec/services/snapshot_service_spec.rb
require "bigdecimal"; require "date"
require "portfolio"; require "instrument"; require "transaction"
require "fx_rate"; require "portfolio_snapshot"
require "valuation_service"; require "snapshot_service"

RSpec.describe SnapshotService do
  let(:portfolio) { Portfolio.create(name: "Main") }
  let(:aapl) { Instrument.create(symbol: "AAPL", currency: "USD", last_price: BigDecimal("150")) }

  before do
    Transaction.create(portfolio_id: portfolio.id, instrument_id: aapl.id, kind: "buy",
                       quantity: 10, price: 100, currency: "USD", executed_at: Time.now)
    FxRate.upsert_rate("USD", "PLN", BigDecimal("4"))
  end

  it "writes one snapshot per portfolio with correct PLN totals" do
    count = described_class.new.call(date: Date.new(2026, 5, 26))
    expect(count).to eq(1)
    snap = PortfolioSnapshot[portfolio_id: portfolio.id, date: Date.new(2026, 5, 26)]
    expect(snap.total_value_pln).to eq(BigDecimal("6000")) # 10*150*4
    expect(snap.total_cost_pln).to eq(BigDecimal("4000"))  # 10*100*4
    expect(snap.pnl_pln).to eq(BigDecimal("2000"))
  end

  it "is idempotent for the same date" do
    described_class.new.call(date: Date.new(2026, 5, 26))
    described_class.new.call(date: Date.new(2026, 5, 26))
    expect(PortfolioSnapshot.where(portfolio_id: portfolio.id, date: Date.new(2026, 5, 26)).count).to eq(1)
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/snapshot_service_spec.rb`
Expected: FAIL — uninitialized constant SnapshotService.

- [ ] **Step 3: Write the service**

```ruby
# api/app/services/snapshot_service.rb
require "date"
require "valuation_service"

class SnapshotService
  def self.fx_to_pln
    rates = FxRate.all.to_h { |r| [r.base, r.rate] }
    rates.merge("PLN" => BigDecimal(1))
  end

  def call(date: Date.today)
    fx = self.class.fx_to_pln
    instruments_by_id = Instrument.all.to_h do |i|
      [i.id, { symbol: i.symbol, currency: i.currency, last_price: i.last_price }]
    end

    count = 0
    Portfolio.all.each do |portfolio|
      txns = Transaction.where(portfolio_id: portfolio.id, kind: "buy").all
      positions = ValuationService.positions(
        transactions: txns, instruments_by_id: instruments_by_id, fx_to_pln: fx
      )
      totals = ValuationService.totals(positions)
      upsert_snapshot(portfolio.id, date, totals)
      count += 1
    end
    count
  end

  private

  def upsert_snapshot(portfolio_id, date, totals)
    row = PortfolioSnapshot[portfolio_id: portfolio_id, date: date]
    attrs = {
      total_value_pln: totals[:market_value_pln],
      total_cost_pln: totals[:cost_pln],
      pnl_pln: totals[:pnl_pln],
    }
    row ? row.update(attrs) : PortfolioSnapshot.create(attrs.merge(portfolio_id: portfolio_id, date: date))
  end
end
```

- [ ] **Step 4: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/services/snapshot_service_spec.rb`
Expected: 2 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add api/app/services/snapshot_service.rb api/spec/services/snapshot_service_spec.rb
git commit -m "feat: SnapshotService writes idempotent daily portfolio snapshots"
```

---

## Phase 5 — API endpoints

### Task 5.1: Routes + PortfoliosController (index/show/create)

**Files:**
- Modify: `api/config/routes.rb`
- Create: `api/app/controllers/portfolios_controller.rb`
- Test: `api/spec/requests/portfolios_spec.rb`

> Request specs boot the Rage app via Rack::Test. Add `gem "rack-test"` to the test group and `require "rack/test"` in the spec. The app is loaded with `require File.expand_path("../config/application", __dir__)` (adjust if Rage exposes a different entrypoint — verify with `rage routes`).

- [ ] **Step 1: Add `rack-test` to the Gemfile test group and rebuild**

In `api/Gemfile`, test group becomes:
```ruby
group :development, :test do
  gem "rspec"
  gem "webmock"
  gem "rack-test"
end
```
Run: `docker build -t portfolio-api ./api`
Expected: build succeeds.

- [ ] **Step 2: Define routes**

```ruby
# api/config/routes.rb
Rage.routes.draw do
  scope path: "api" do
    get "portfolios", to: "portfolios#index"
    post "portfolios", to: "portfolios#create"
    get "portfolios/:id", to: "portfolios#show"
    get "portfolios/:id/snapshots", to: "portfolios#snapshots"
    post "portfolios/:id/transactions", to: "transactions#create"
    delete "transactions/:id", to: "transactions#destroy"
    get "instruments/search", to: "instruments#search"
    post "refresh", to: "refresh#create"
  end
end
```

- [ ] **Step 3: Write a failing request spec**

```ruby
# api/spec/requests/portfolios_spec.rb
require "rack/test"
require "json"
require File.expand_path("../../config/application", __dir__)

RSpec.describe "Portfolios API" do
  include Rack::Test::Methods
  def app = Rage.application

  it "creates and lists a portfolio" do
    post "/api/portfolios", JSON.dump(name: "IKE"), "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(201)
    created = JSON.parse(last_response.body)
    expect(created["name"]).to eq("IKE")

    get "/api/portfolios"
    expect(last_response.status).to eq(200)
    list = JSON.parse(last_response.body)
    expect(list.map { |p| p["name"] }).to include("IKE")
    expect(list.first).to have_key("pnl_pln")
  end
end
```

- [ ] **Step 4: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests/portfolios_spec.rb`
Expected: FAIL — controller/action missing or 404.

- [ ] **Step 5: Write the controller**

```ruby
# api/app/controllers/portfolios_controller.rb
require "valuation_service"
require "snapshot_service"

class PortfoliosController < RageController::API
  def index
    fx = SnapshotService.fx_to_pln
    instruments_by_id = instruments_map
    payload = Portfolio.all.map do |p|
      totals = ValuationService.totals(positions_for(p, instruments_by_id, fx))
      portfolio_json(p).merge(totals.transform_values(&:to_s))
    end
    render json: payload
  end

  def show
    p = Portfolio[params[:id].to_i] or return render(json: { error: "not found" }, status: :not_found)
    fx = SnapshotService.fx_to_pln
    positions = positions_for(p, instruments_map, fx)
    render json: portfolio_json(p).merge(
      totals: ValuationService.totals(positions).transform_values(&:to_s),
      positions: positions.map { |pos| position_json(pos) }
    )
  end

  def create
    p = Portfolio.new(name: params[:name].to_s)
    p.base_currency = params[:base_currency] if params[:base_currency]
    if p.valid?
      p.save
      render json: portfolio_json(p), status: :created
    else
      render json: { errors: p.errors }, status: :unprocessable_entity
    end
  end

  def snapshots
    rows = PortfolioSnapshot.where(portfolio_id: params[:id].to_i).order(:date).all
    render json: rows.map { |s|
      { date: s.date.to_s, total_value_pln: s.total_value_pln.to_s,
        total_cost_pln: s.total_cost_pln.to_s, pnl_pln: s.pnl_pln.to_s }
    }
  end

  private

  def instruments_map
    Instrument.all.to_h { |i| [i.id, { symbol: i.symbol, currency: i.currency, last_price: i.last_price }] }
  end

  def positions_for(portfolio, instruments_by_id, fx)
    txns = Transaction.where(portfolio_id: portfolio.id, kind: "buy").all
    ValuationService.positions(transactions: txns, instruments_by_id: instruments_by_id, fx_to_pln: fx)
  end

  def portfolio_json(p)
    { id: p.id, name: p.name, base_currency: p.base_currency }
  end

  def position_json(pos)
    pos.to_h.transform_values { |v| v.is_a?(BigDecimal) ? v.to_s : v }
  end
end
```

- [ ] **Step 6: Add a `name`-presence validation to Portfolio**

In `api/app/models/portfolio.rb` add:
```ruby
  def validate
    super
    errors.add(:name, "is required") if name.nil? || name.strip.empty?
  end
```

- [ ] **Step 7: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests/portfolios_spec.rb`
Expected: 1 example, 0 failures. (If routing entrypoint differs, fix the `require` / `app` per `rage routes` output, then re-run.)

- [ ] **Step 8: Commit**

```bash
git add api/config/routes.rb api/app/controllers/portfolios_controller.rb api/app/models/portfolio.rb api/Gemfile api/Gemfile.lock api/spec/requests/portfolios_spec.rb
git commit -m "feat: portfolios endpoints (index/show/create/snapshots)"
```

### Task 5.2: TransactionsController (create + destroy) with instrument resolution

**Files:**
- Create: `api/app/controllers/transactions_controller.rb`
- Test: `api/spec/requests/transactions_spec.rb`

**Rule:** creating a transaction requires an existing-or-creatable instrument. The request sends `symbol`, optional `mic`, `currency`, plus `quantity`, `price`, `executed_at`. We `find_or_create` the instrument by `[symbol, mic]`. If the instrument is new, we attempt a price fetch immediately (best-effort; failure does not block the transaction).

- [ ] **Step 1: Write failing specs**

```ruby
# api/spec/requests/transactions_spec.rb
require "rack/test"
require "json"
require File.expand_path("../../config/application", __dir__)
require "portfolio"; require "instrument"; require "transaction"

RSpec.describe "Transactions API" do
  include Rack::Test::Methods
  def app = Rage.application
  let(:portfolio) { Portfolio.create(name: "Main") }

  it "creates a transaction and the instrument when new" do
    body = JSON.dump(symbol: "AAPL", currency: "USD", quantity: "10", price: "150",
                     executed_at: "2026-05-20T10:00:00Z")
    post "/api/portfolios/#{portfolio.id}/transactions", body, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(201)
    expect(Instrument.where(symbol: "AAPL").count).to eq(1)
    expect(Transaction.where(portfolio_id: portfolio.id).count).to eq(1)
  end

  it "rejects an invalid transaction (zero quantity)" do
    body = JSON.dump(symbol: "AAPL", currency: "USD", quantity: "0", price: "150",
                     executed_at: "2026-05-20T10:00:00Z")
    post "/api/portfolios/#{portfolio.id}/transactions", body, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(422)
  end

  it "deletes a transaction" do
    inst = Instrument.create(symbol: "AAPL", currency: "USD")
    t = Transaction.create(portfolio_id: portfolio.id, instrument_id: inst.id, kind: "buy",
                           quantity: 1, price: 1, currency: "USD", executed_at: Time.now)
    delete "/api/transactions/#{t.id}"
    expect(last_response.status).to eq(204)
    expect(Transaction[t.id]).to be_nil
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests/transactions_spec.rb`
Expected: FAIL — controller missing.

- [ ] **Step 3: Write the controller**

```ruby
# api/app/controllers/transactions_controller.rb
require "market_data/twelve_data_client"

class TransactionsController < RageController::API
  def create
    instrument = resolve_instrument
    t = Transaction.new(
      portfolio_id: params[:id].to_i,
      instrument_id: instrument.id,
      kind: "buy",
      quantity: BigDecimal(params[:quantity].to_s),
      price: BigDecimal(params[:price].to_s),
      currency: params[:currency].to_s,
      executed_at: Time.parse(params[:executed_at].to_s)
    )
    if t.valid?
      t.save
      render json: { id: t.id }, status: :created
    else
      render json: { errors: t.errors }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    t = Transaction[params[:id].to_i] or return render(json: {}, status: :not_found)
    t.destroy
    head :no_content
  end

  private

  def resolve_instrument
    mic = params[:mic].to_s.empty? ? nil : params[:mic]
    inst = Instrument[symbol: params[:symbol], mic: mic]
    return inst if inst
    inst = Instrument.create(symbol: params[:symbol], mic: mic, currency: params[:currency].to_s)
    fetch_initial_price(inst)
    inst
  end

  def fetch_initial_price(inst)
    price = MarketData::TwelveDataClient.new.prices([inst.td_symbol])[inst.td_symbol]
    inst.update(last_price: price, last_price_at: Time.now) if price
  rescue StandardError => e
    Rage.logger.warn("initial price fetch failed for #{inst.td_symbol}: #{e.message}")
  end
end
```

- [ ] **Step 4: Stub the initial price fetch in the spec**

At the top of the first `it` block in `transactions_spec.rb`, add a WebMock stub so the best-effort fetch has no live call:
```ruby
    stub_request(:get, "https://api.twelvedata.com/price")
      .with(query: hash_including(symbol: "AAPL")).to_return(status: 200, body: '{"price":"150"}')
```
(Add `require "webmock/rspec"` is already loaded via spec_helper.)

- [ ] **Step 5: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests/transactions_spec.rb`
Expected: 3 examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add api/app/controllers/transactions_controller.rb api/spec/requests/transactions_spec.rb
git commit -m "feat: transactions create/destroy with instrument resolution"
```

### Task 5.3: InstrumentsController#search + RefreshController#create

**Files:**
- Create: `api/app/controllers/instruments_controller.rb`
- Create: `api/app/controllers/refresh_controller.rb`
- Modify: `api/app/services/market_data/twelve_data_client.rb` (add `#symbol_search`)
- Test: `api/spec/requests/instruments_search_spec.rb`, `api/spec/requests/refresh_spec.rb`

- [ ] **Step 1: Write failing specs**

```ruby
# api/spec/requests/instruments_search_spec.rb
require "rack/test"; require "json"
require File.expand_path("../../config/application", __dir__)

RSpec.describe "Instrument search API" do
  include Rack::Test::Methods
  def app = Rage.application

  it "proxies Twelve Data symbol_search" do
    stub_request(:get, "https://api.twelvedata.com/symbol_search")
      .with(query: hash_including(symbol: "appl"))
      .to_return(status: 200, body: '{"data":[{"symbol":"AAPL","instrument_name":"Apple Inc","exchange":"NASDAQ","currency":"USD","mic_code":"XNAS"}]}')
    get "/api/instruments/search?q=appl"
    expect(last_response.status).to eq(200)
    results = JSON.parse(last_response.body)
    expect(results.first["symbol"]).to eq("AAPL")
    expect(results.first["currency"]).to eq("USD")
  end
end
```

```ruby
# api/spec/requests/refresh_spec.rb
require "rack/test"; require "json"
require File.expand_path("../../config/application", __dir__)
require "portfolio"; require "instrument"; require "transaction"

RSpec.describe "Refresh API" do
  include Rack::Test::Methods
  def app = Rage.application

  it "triggers a refresh and reports a summary" do
    pf = Portfolio.create(name: "Main")
    inst = Instrument.create(symbol: "AAPL", currency: "USD")
    Transaction.create(portfolio_id: pf.id, instrument_id: inst.id, kind: "buy",
                       quantity: 1, price: 1, currency: "USD", executed_at: Time.now)
    stub_request(:get, "https://api.twelvedata.com/price")
      .with(query: hash_including(symbol: "AAPL")).to_return(status: 200, body: '{"price":"150"}')
    stub_request(:get, "https://api.twelvedata.com/exchange_rate")
      .with(query: hash_including(symbol: "USD/PLN")).to_return(status: 200, body: '{"rate":4.0}')

    post "/api/refresh"
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body["instruments_updated"]).to eq(1)
  end
end
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests/instruments_search_spec.rb spec/requests/refresh_spec.rb`
Expected: FAIL — controllers / `symbol_search` missing.

- [ ] **Step 3: Add `symbol_search` to the client**

Append inside `class TwelveDataClient`:
```ruby
    def symbol_search(query)
      body = get("/symbol_search", symbol: query)
      Array(body["data"]).map do |row|
        { symbol: row["symbol"], name: row["instrument_name"],
          exchange: row["exchange"], currency: row["currency"], mic: row["mic_code"] }
      end
    end
```

- [ ] **Step 4: Write the controllers**

```ruby
# api/app/controllers/instruments_controller.rb
require "market_data/twelve_data_client"

class InstrumentsController < RageController::API
  def search
    q = params[:q].to_s
    return render(json: []) if q.strip.empty?
    render json: MarketData::TwelveDataClient.new.symbol_search(q)
  end
end
```

```ruby
# api/app/controllers/refresh_controller.rb
require "refresh_service"

class RefreshController < RageController::API
  def create
    render json: RefreshService.new.call
  end
end
```

- [ ] **Step 5: Run to confirm pass**

Run: `docker run --rm -v "$PWD/api":/app -w /app portfolio-api bundle exec rspec spec/requests`
Expected: all request specs pass.

- [ ] **Step 6: Commit**

```bash
git add api/app/controllers/instruments_controller.rb api/app/controllers/refresh_controller.rb api/app/services/market_data/twelve_data_client.rb api/spec/requests/instruments_search_spec.rb api/spec/requests/refresh_spec.rb
git commit -m "feat: instrument search and manual refresh endpoints"
```

### Task 5.4: Scheduler initializer (rufus)

**Files:**
- Create: `api/config/initializers/scheduler.rb`

> Not unit-tested (we don't test rufus itself). The schedule calls the already-tested services. Guarded so it only runs in the server process, not under RSpec.

- [ ] **Step 1: Write the initializer**

```ruby
# api/config/initializers/scheduler.rb
return if ENV["RACK_ENV"] == "test" || defined?(RSpec)

require "rufus-scheduler"
require "refresh_service"
require "snapshot_service"

SCHEDULER = Rufus::Scheduler.new

# 3x/day, Europe/Warsaw. Morning EU, US open, after US close.
%w[09:30 15:35 22:15].each do |hhmm|
  SCHEDULER.cron("#{hhmm.split(':').reverse.join(' ')} * * * Europe/Warsaw") do
    begin
      RefreshService.new.call
    rescue StandardError => e
      Rage.logger.error("scheduled refresh failed: #{e.message}")
    end
  end
end

# Daily snapshot after the last refresh.
SCHEDULER.cron("30 22 * * * Europe/Warsaw") do
  begin
    SnapshotService.new.call
  rescue StandardError => e
    Rage.logger.error("scheduled snapshot failed: #{e.message}")
  end
end
```

> Note: rufus cron format is `min hour day month weekday`. `"09:30"` → `"30 9 * * * Europe/Warsaw"`. Verify the generated strings by logging them once at boot.

- [ ] **Step 2: Verify the server boots with the scheduler loaded**

Run:
```bash
docker run --rm -e TWELVE_DATA_API_KEY=dummy -e DATABASE_URL=sqlite:///tmp/s.sqlite3 \
  -v "$PWD/api":/app -w /app portfolio-api \
  bundle exec ruby -e 'require "./config/initializers/db"; require "./config/initializers/scheduler"; puts (defined?(SCHEDULER) ? SCHEDULER.jobs.size : "no scheduler"); '
```
Expected: prints `4` (3 refresh + 1 snapshot).

- [ ] **Step 3: Commit**

```bash
git add api/config/initializers/scheduler.rb
git commit -m "feat: rufus-scheduler runs 3x/day refresh and daily snapshot"
```

---

## Phase 6 — Frontend (Svelte + Vite + Tailwind)

### Task 6.1: Scaffold the Svelte app in Docker

**Files:**
- Create: `web/` (Vite Svelte template), `web/Dockerfile`, `web/tailwind.config.js`, `web/src/app.css`, `web/vite.config.js`

- [ ] **Step 1: Scaffold via a one-off Node container**

Run:
```bash
docker run --rm -v "$PWD":/out -w /out node:22-slim bash -lc \
  "npm create vite@latest web -- --template svelte && cd web && npm install && npm install -D tailwindcss @tailwindcss/postcss postcss vitest @testing-library/svelte jsdom"
```
Expected: `web/` contains a Svelte Vite project with `package.json`.

- [ ] **Step 2: Configure Tailwind v4 via PostCSS** — create `web/postcss.config.js`

```js
export default { plugins: { "@tailwindcss/postcss": {} } };
```

- [ ] **Step 3: Replace `web/src/app.css`**

```css
@import "tailwindcss";
```

- [ ] **Step 4: Configure Vite dev proxy** — `web/vite.config.js`

```js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: true,
    proxy: { "/api": "http://api:3000" },
  },
  test: { environment: "jsdom", globals: true },
});
```

- [ ] **Step 5: Write `web/Dockerfile`**

```dockerfile
FROM node:22-slim
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
```

- [ ] **Step 6: Commit**

```bash
git add web/ -f && git reset web/node_modules
git add .gitignore
git commit -m "chore: scaffold Svelte+Vite+Tailwind frontend in Docker"
```

### Task 6.2: Formatting helpers (TDD with Vitest)

**Files:**
- Create: `web/src/lib/format.js`
- Test: `web/src/lib/format.test.js`

- [ ] **Step 1: Write failing tests**

```js
// web/src/lib/format.test.js
import { describe, it, expect } from "vitest";
import { money, pnlClass } from "./format.js";

describe("money", () => {
  it("formats PLN with two decimals", () => {
    expect(money("1234.5", "PLN")).toBe("1 234,50 zł");
  });
  it("renders an em dash for null", () => {
    expect(money(null, "PLN")).toBe("—");
  });
});

describe("pnlClass", () => {
  it("is green for positive, red for negative, neutral for zero", () => {
    expect(pnlClass("10")).toBe("text-green-600");
    expect(pnlClass("-3")).toBe("text-red-600");
    expect(pnlClass("0")).toBe("text-gray-500");
  });
});
```

- [ ] **Step 2: Run to confirm failure**

Run: `docker run --rm -v "$PWD/web":/app -w /app node:22-slim bash -lc "npm install >/dev/null && npx vitest run src/lib/format.test.js"`
Expected: FAIL — cannot import money/pnlClass.

- [ ] **Step 3: Write the helpers**

```js
// web/src/lib/format.js
export function money(value, currency = "PLN") {
  if (value === null || value === undefined || value === "") return "—";
  const n = Number(value);
  const fmt = new Intl.NumberFormat("pl-PL", { style: "currency", currency });
  return fmt.format(n);
}

export function pnlClass(value) {
  const n = Number(value);
  if (n > 0) return "text-green-600";
  if (n < 0) return "text-red-600";
  return "text-gray-500";
}
```

- [ ] **Step 4: Run to confirm pass**

Run: `docker run --rm -v "$PWD/web":/app -w /app node:22-slim bash -lc "npm install >/dev/null && npx vitest run src/lib/format.test.js"`
Expected: 4 tests pass. (If the PLN currency string differs by Node ICU build, adjust the expected string to match the runtime output — keep the null/dash and class tests authoritative.)

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/format.js web/src/lib/format.test.js
git commit -m "feat: frontend money/pnl formatting helpers with tests"
```

### Task 6.3: API client + PortfolioList + PortfolioView + TransactionForm

**Files:**
- Create: `web/src/lib/api.js`
- Create: `web/src/lib/components/PortfolioList.svelte`, `PortfolioView.svelte`, `TransactionForm.svelte`
- Modify: `web/src/App.svelte`, `web/src/main.js`

- [ ] **Step 1: Write the API client**

```js
// web/src/lib/api.js
const json = (r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); };

export const api = {
  portfolios: () => fetch("/api/portfolios").then(json),
  portfolio: (id) => fetch(`/api/portfolios/${id}`).then(json),
  snapshots: (id) => fetch(`/api/portfolios/${id}/snapshots`).then(json),
  createPortfolio: (name) =>
    fetch("/api/portfolios", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  searchInstruments: (q) => fetch(`/api/instruments/search?q=${encodeURIComponent(q)}`).then(json),
  addTransaction: (portfolioId, payload) =>
    fetch(`/api/portfolios/${portfolioId}/transactions`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }).then(json),
  refresh: () => fetch("/api/refresh", { method: "POST" }).then(json),
};
```

- [ ] **Step 2: Write `PortfolioList.svelte`**

```svelte
<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass } from "../format.js";
  let { onSelect } = $props();
  let portfolios = $state([]);
  let newName = $state("");

  async function load() { portfolios = await api.portfolios(); }
  async function create() {
    if (!newName.trim()) return;
    await api.createPortfolio(newName.trim());
    newName = ""; await load();
  }
  onMount(load);
</script>

<div class="p-6 max-w-3xl mx-auto">
  <h1 class="text-2xl font-bold mb-4">Moje portfele</h1>
  <div class="flex gap-2 mb-6">
    <input class="border rounded px-3 py-2 flex-1" placeholder="Nazwa portfela" bind:value={newName} />
    <button class="bg-blue-600 text-white px-4 py-2 rounded" onclick={create}>Dodaj</button>
  </div>
  <ul class="space-y-2">
    {#each portfolios as p}
      <li class="border rounded p-4 flex justify-between cursor-pointer hover:bg-gray-50" onclick={() => onSelect(p.id)}>
        <span class="font-medium">{p.name}</span>
        <span class={pnlClass(p.pnl_pln)}>{money(p.market_value_pln)} ({money(p.pnl_pln)})</span>
      </li>
    {/each}
  </ul>
</div>
```

- [ ] **Step 3: Write `TransactionForm.svelte`**

```svelte
<script>
  import { api } from "../api.js";
  let { portfolioId, onAdded } = $props();
  let query = $state(""); let results = $state([]); let selected = $state(null);
  let quantity = $state(""); let price = $state(""); let executedAt = $state("");
  let error = $state("");

  async function search() { results = query.trim() ? await api.searchInstruments(query) : []; }
  function pick(r) { selected = r; query = `${r.symbol} — ${r.name}`; results = []; }
  async function submit() {
    error = "";
    if (!selected) { error = "Wybierz instrument z listy"; return; }
    try {
      await api.addTransaction(portfolioId, {
        symbol: selected.symbol, mic: selected.mic, currency: selected.currency,
        quantity, price, executed_at: new Date(executedAt).toISOString(),
      });
      query = ""; selected = null; quantity = ""; price = ""; executedAt = "";
      onAdded();
    } catch (e) { error = "Nie udało się zapisać transakcji"; }
  }
</script>

<div class="border rounded p-4 space-y-3">
  <h3 class="font-semibold">Dodaj transakcję</h3>
  <div class="relative">
    <input class="border rounded px-3 py-2 w-full" placeholder="Szukaj tickera (np. AAPL)" bind:value={query} oninput={search} />
    {#if results.length}
      <ul class="absolute z-10 bg-white border rounded w-full mt-1 max-h-48 overflow-auto">
        {#each results as r}
          <li class="px-3 py-2 hover:bg-gray-100 cursor-pointer" onclick={() => pick(r)}>{r.symbol} — {r.name} ({r.currency})</li>
        {/each}
      </ul>
    {/if}
  </div>
  <div class="grid grid-cols-3 gap-2">
    <input class="border rounded px-3 py-2" placeholder="Ilość" bind:value={quantity} />
    <input class="border rounded px-3 py-2" placeholder="Cena" bind:value={price} />
    <input class="border rounded px-3 py-2" type="date" bind:value={executedAt} />
  </div>
  {#if error}<p class="text-red-600 text-sm">{error}</p>{/if}
  <button class="bg-green-600 text-white px-4 py-2 rounded" onclick={submit}>Zapisz</button>
</div>
```

- [ ] **Step 4: Write `PortfolioView.svelte`** (table + form + chart placeholder slot)

```svelte
<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass } from "../format.js";
  import TransactionForm from "./TransactionForm.svelte";
  import PnlChart from "./PnlChart.svelte";
  let { id, onBack } = $props();
  let data = $state(null); let snapshots = $state([]);

  async function load() {
    data = await api.portfolio(id);
    snapshots = await api.snapshots(id);
  }
  async function refresh() { await api.refresh(); await load(); }
  onMount(load);
</script>

{#if data}
<div class="p-6 max-w-4xl mx-auto space-y-6">
  <button class="text-blue-600" onclick={onBack}>← Portfele</button>
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">{data.name}</h1>
    <button class="border px-3 py-1 rounded" onclick={refresh}>Odśwież ceny</button>
  </div>
  <div class="text-lg">
    Wartość: <strong>{money(data.totals.market_value_pln)}</strong>
    · <span class={pnlClass(data.totals.pnl_pln)}>P/L {money(data.totals.pnl_pln)}</span>
  </div>

  <table class="w-full text-sm border">
    <thead class="bg-gray-100"><tr>
      <th class="text-left p-2">Symbol</th><th class="text-right p-2">Ilość</th>
      <th class="text-right p-2">Śr. cena</th><th class="text-right p-2">Cena</th>
      <th class="text-right p-2">Wartość (PLN)</th><th class="text-right p-2">P/L (PLN)</th>
    </tr></thead>
    <tbody>
      {#each data.positions as pos}
        <tr class="border-t">
          <td class="p-2">{pos.symbol}</td>
          <td class="p-2 text-right">{pos.quantity}</td>
          <td class="p-2 text-right">{money(pos.avg_price, pos.currency)}</td>
          <td class="p-2 text-right">{money(pos.last_price, pos.currency)}</td>
          <td class="p-2 text-right">{money(pos.market_value_pln)}</td>
          <td class="p-2 text-right {pnlClass(pos.pnl_pln)}">{money(pos.pnl_pln)}</td>
        </tr>
      {/each}
    </tbody>
  </table>

  <PnlChart {snapshots} />
  <TransactionForm portfolioId={id} onAdded={load} />
</div>
{/if}
```

- [ ] **Step 5: Write `App.svelte` to switch between list and view**

```svelte
<script>
  import "./app.css";
  import PortfolioList from "./lib/components/PortfolioList.svelte";
  import PortfolioView from "./lib/components/PortfolioView.svelte";
  let selectedId = $state(null);
</script>

{#if selectedId}
  <PortfolioView id={selectedId} onBack={() => (selectedId = null)} />
{:else}
  <PortfolioList onSelect={(id) => (selectedId = id)} />
{/if}
```

> Note: import paths in components use `../api.js` / `../format.js` because components live in `lib/components/` and the helpers in `lib/`. Verify these resolve when the app builds.

- [ ] **Step 6: Verify the build compiles**

Run: `docker run --rm -v "$PWD/web":/app -w /app node:22-slim bash -lc "npm install >/dev/null && npm run build"`
Expected: Vite build succeeds (PnlChart must exist — created in Task 6.4; do this step after 6.4 or stub PnlChart first).

- [ ] **Step 7: Commit**

```bash
git add web/src/lib/api.js web/src/lib/components/PortfolioList.svelte web/src/lib/components/PortfolioView.svelte web/src/lib/components/TransactionForm.svelte web/src/App.svelte
git commit -m "feat: portfolio list, detail view, and transaction form"
```

### Task 6.4: PnlChart component

**Files:**
- Create: `web/src/lib/components/PnlChart.svelte`
- Modify: `web/package.json` (add `chart.js`)

- [ ] **Step 1: Install Chart.js**

Run: `docker run --rm -v "$PWD/web":/app -w /app node:22-slim bash -lc "npm install chart.js"`
Expected: `chart.js` added to dependencies.

- [ ] **Step 2: Write the component**

```svelte
<script>
  import { onMount } from "svelte";
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  let { snapshots } = $props();
  let canvas;
  onMount(() => {
    if (!snapshots?.length) return;
    new Chart(canvas, {
      type: "line",
      data: {
        labels: snapshots.map((s) => s.date),
        datasets: [{ label: "Wartość portfela (PLN)", data: snapshots.map((s) => Number(s.total_value_pln)), borderColor: "#2563eb", tension: 0.2 }],
      },
      options: { responsive: true, plugins: { legend: { display: true } } },
    });
  });
</script>

{#if snapshots?.length}
  <div class="border rounded p-4"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-gray-500 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
```

- [ ] **Step 3: Verify the full build compiles**

Run: `docker run --rm -v "$PWD/web":/app -w /app node:22-slim bash -lc "npm install >/dev/null && npm run build"`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/components/PnlChart.svelte web/package.json web/package-lock.json
git commit -m "feat: P/L history chart from daily snapshots"
```

### Task 6.5: Docker Compose wiring + end-to-end smoke test

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Write `docker-compose.yml`**

```yaml
services:
  api:
    build: ./api
    environment:
      - TWELVE_DATA_API_KEY=${TWELVE_DATA_API_KEY}
      - DATABASE_URL=sqlite:///data/portfolio.sqlite3
      - RACK_ENV=development
    volumes:
      - ./api:/app
      - api_data:/data
    ports:
      - "3000:3000"
  web:
    build: ./web
    volumes:
      - ./web:/app
      - /app/node_modules
    ports:
      - "5173:5173"
    depends_on:
      - api

volumes:
  api_data:
```

- [ ] **Step 2: Boot the stack**

Run: `cp .env.example .env` (then put the real key in `.env`), followed by `docker compose up --build`
Expected: `api` logs the scheduler loading 4 jobs and serves on :3000; `web` serves on :5173.

- [ ] **Step 3: Manual end-to-end verification (golden path)**

In a browser at `http://localhost:5173`:
1. Create a portfolio "IKE" → appears in the list.
2. Open it, add a transaction (search "AAPL", pick it, qty 10, price 150, today) → row appears in the table.
3. Click "Odśwież ceny" → price/value/PLN columns populate; P/L colored.
4. Confirm the chart shows the empty-state message (no snapshot yet).

Document the result explicitly (works / doesn't). If the search returns nothing, the API key or symbol coverage needs checking via `GET /api/instruments/search?q=...` directly.

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: docker-compose wiring for api + web"
```

- [ ] **Step 5: Full backend suite green**

Run: `docker compose run --rm api bundle exec rspec`
Expected: all specs pass.

---

## Addendum (added mid-execution per user request)

**RuboCop (Task A):** `rubocop` + `rubocop-rspec` added to the api test/dev group. Config at `api/.rubocop.yml` (`TargetRubyVersion 3.3`, excludes generated scaffold: `config/**/*`, `Rakefile`, `config.ru`, `db/migrations/**/*`). Existing code autocorrected to green. From Task A onward, every implementer runs `rubocop` on the files they touch and leaves them offense-free.

**dry-configurable (Task C):** App-wide configuration via a central `AppConfig` (`api/config/app_config.rb`, `extend Dry::Configurable`) for secrets + database: `twelve_data.api_key` (from `TWELVE_DATA_API_KEY` env), `twelve_data.base_url`, `database_url` (from `DATABASE_URL` env), `base_currency` (PLN), and refresh/snapshot times. `config/initializers/db.rb` connects via `AppConfig.config.database_url` (guarded `unless defined?(DB)` so request specs reuse the spec_helper DB). `MarketData::TwelveDataClient` defaults its key/base_url from AppConfig; `RefreshService` reads `base_currency` from AppConfig (drops the `BASE_CURRENCY` constant). `spec_helper.rb` requires `config/app_config` so the constant is available in all specs. The scheduler (Task 5.4) reads `refresh_times`/`snapshot_time` from AppConfig.

**dry-validation (Task B):** Input validation moves from Sequel model `validate` overrides to dry-validation contracts at the controller boundary (DRY: one validation path). Files: `api/app/contracts/portfolio_contract.rb`, `api/app/contracts/transaction_contract.rb`. The `Transaction`/`Portfolio` models keep their associations but DROP the `validate` override. The Task 1.2 model spec is refactored into a contract spec (`api/spec/contracts/transaction_contract_spec.rb`). Controllers (Tasks 5.1, 5.2) call the relevant contract, returning `422` with `result.errors.to_h` on failure. This supersedes the `model.valid?`/`p.errors` and `Portfolio#validate` steps written in Tasks 5.1/5.2 — use contracts there instead.

## Self-Review Notes (author checklist — already applied)

- **Spec coverage:** portfolios/multi-portfolio (5.1), transactions buy + sell-ready schema (1.2, 5.2), Twelve Data prices+FX (3.1), 3×/day refresh + daily snapshot (4.1, 4.2, 5.4), PLN base + valuation convention (Phase 2), SQLite + Sequel (Phase 0/1), Docker-only (Phase 0/6.5), instrument search (5.3), frontend list/view/form/chart (Phase 6). Fee column present but unused (1.2) per spec.
- **Deferred per spec (no task):** sells/FIFO, fee logic, GPW/crypto, auth — intentionally out of MVP.
- **Type consistency:** `Position` struct fields and `ValuationService.positions/totals` signatures defined in 2.1 are consumed unchanged in 4.2 and 5.1; `td_symbol` (1.1) used by 4.1/5.2; `fx_to_pln` (4.2) reused by 5.1; client `prices`/`fx_rate`/`symbol_search` consistent across 3.1/4.1/5.3.
- **Known execution caveats (verify, don't assume):** Rage's exact app entrypoint/`Rage.application` handle for Rack::Test, autoloading order of `app/models` vs the DB initializer, and rufus cron string formatting — each has a verification step that will surface a mismatch immediately.
