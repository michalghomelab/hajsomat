require 'date'

RSpec.describe SnapshotCatchup do
  let(:portfolio) { Portfolio.create(name: 'Main') }
  let(:instrument) { Instrument.create(symbol: 'SXR8.DE', currency: 'EUR') }

  before do
    allow(BackfillService).to receive(:call)
    allow(SnapshotService).to receive(:call)
  end

  def buy_on(date)
    Transaction.create(portfolio_id: portfolio.id, instrument_id: instrument.id, kind: 'buy',
                       quantity: 1, price: 100, currency: 'EUR', executed_at: Time.utc(date.year, date.month, date.day))
  end

  def snapshot_on(date)
    PortfolioSnapshot.create(portfolio_id: portfolio.id, date: date,
                             total_value_pln: 1, total_cost_pln: 1, pnl_pln: 0)
  end

  # 2026-05-29 is a Friday; the weekend is 30–31.
  it 'does nothing when the latest snapshot already covers today' do
    buy_on(Date.new(2026, 5, 29))
    snapshot_on(Date.new(2026, 5, 29))

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).not_to have_received(:call)
    expect(SnapshotService).not_to have_received(:call)
  end

  it 'expects today even before the market session starts' do
    buy_on(Date.new(2026, 5, 26))
    snapshot_on(Date.new(2026, 5, 26)) # Wed — Thu 28 missing

    described_class.call(now: Time.utc(2026, 5, 29, 6, 0))

    expect(BackfillService).to have_received(:call)
    expect(SnapshotService).to have_received(:call)
  end

  it 'captures today and backfills the gap' do
    buy_on(Date.new(2026, 5, 27))
    snapshot_on(Date.new(2026, 5, 27))

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).to have_received(:call)
    expect(SnapshotService).to have_received(:call)
  end

  it 'captures weekend days too' do
    buy_on(Date.new(2026, 5, 29))
    snapshot_on(Date.new(2026, 5, 29)) # Fri present

    described_class.call(now: Time.utc(2026, 5, 30, 12, 0)) # Sat

    expect(BackfillService).not_to have_received(:call)
    expect(SnapshotService).to have_received(:call)
  end

  it 'runs catch-up on first boot when there are no snapshots yet' do
    buy_on(Date.new(2026, 5, 29))

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(SnapshotService).to have_received(:call)
  end

  it 'backfills when a calendar date is missing before today' do
    buy_on(Date.new(2026, 5, 27))
    snapshot_on(Date.new(2026, 5, 27))
    snapshot_on(Date.new(2026, 5, 29))

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).to have_received(:call)
  end

  it 'backfills when one portfolio is missing snapshots' do
    other = Portfolio.create(name: 'Other')
    buy_on(Date.new(2026, 5, 28))
    snapshot_on(Date.new(2026, 5, 28))
    snapshot_on(Date.new(2026, 5, 29))
    PortfolioSnapshot.create(portfolio_id: other.id, date: Date.new(2026, 5, 29),
                             total_value_pln: 1, total_cost_pln: 1, pnl_pln: 0)

    described_class.call(now: Time.utc(2026, 5, 29, 9, 0))

    expect(BackfillService).to have_received(:call)
  end
end
