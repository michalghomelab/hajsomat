require 'bigdecimal'
require 'date'

RSpec.describe BackfillService do
  let(:portfolio) { Portfolio.create(name: 'Main') }
  let(:inst) { Instrument.create(symbol: 'SXR8.DE', currency: 'EUR') }
  let(:fake_client) do
    Class.new do
      def history(symbol, range:) # rubocop:disable Lint/UnusedMethodArgument
        if symbol == 'EURPLN=X'
          { Date.new(2026, 2, 12) => BigDecimal('4'), Date.new(2026, 2, 13) => BigDecimal('4') }
        else
          { Date.new(2026, 2, 12) => BigDecimal('100'), Date.new(2026, 2, 13) => BigDecimal('110') }
        end
      end
    end.new
  end

  before do
    Transaction.create(portfolio_id: portfolio.id, instrument_id: inst.id, kind: 'buy',
                       quantity: 1, price: 100, currency: 'EUR', executed_at: Time.utc(2026, 2, 12))
  end

  it 'writes one snapshot per historical trading day with margined values' do
    allow(Date).to receive(:today).and_return(Date.new(2026, 2, 14))

    result = described_class.new(client: fake_client).call
    expect(result[:snapshots_written]).to eq(2)

    snap = PortfolioSnapshot[portfolio_id: portfolio.id, date: Date.new(2026, 2, 13)]
    expect(snap.total_value_pln).to eq(BigDecimal('437.8'))  # 1*110*4*(1-0.005)
    expect(snap.total_cost_pln).to eq(BigDecimal('402'))     # 1*100*4*(1+0.005)
  end
end
