require 'bigdecimal'
require 'date'

RSpec.describe SnapshotService do
  let(:portfolio) { Portfolio.create(name: 'Main') }
  let(:aapl) { Instrument.create(symbol: 'AAPL', currency: 'USD', last_price: BigDecimal('150')) }

  before do
    Transaction.create(portfolio_id: portfolio.id, instrument_id: aapl.id, kind: 'buy',
                       quantity: 10, price: 100, currency: 'USD', executed_at: Time.now)
    FxRate.upsert_rate('USD', 'PLN', BigDecimal('4'))
  end

  it 'writes one snapshot per portfolio with correct PLN totals' do
    count = described_class.call(date: Date.new(2026, 5, 26))
    expect(count).to eq(1)
    snap = PortfolioSnapshot[portfolio_id: portfolio.id, date: Date.new(2026, 5, 26)]
    # FX margin round-trip: value down 0.5%, cost up 0.5%
    expect(snap.total_value_pln).to eq(BigDecimal('5970')) # 10*150*4*(1-0.005)
    expect(snap.total_cost_pln).to eq(BigDecimal('4020'))  # 10*100*4*(1+0.005)
    expect(snap.pnl_pln).to eq(BigDecimal('1950'))
  end

  it 'is idempotent for the same date' do
    described_class.call(date: Date.new(2026, 5, 26))
    described_class.call(date: Date.new(2026, 5, 26))
    expect(PortfolioSnapshot.where(portfolio_id: portfolio.id, date: Date.new(2026, 5, 26)).count).to eq(1)
  end
end
