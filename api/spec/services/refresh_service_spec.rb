require 'bigdecimal'

RSpec.describe RefreshService do
  let(:portfolio) { Portfolio.create(name: 'Main') }
  let(:fake_client) do
    Class.new do
      def prices(symbols)
        { 'AAPL' => BigDecimal('150'), 'VWCE:XETR' => BigDecimal('60') }
          .slice(*symbols)
      end

      def fx_rate(base, _quote) = base == 'USD' ? BigDecimal('4.0') : BigDecimal('4.3')
    end.new
  end
  let(:aapl) { Instrument.create(symbol: 'AAPL', currency: 'USD') }
  let(:vwce) { Instrument.create(symbol: 'VWCE', mic: 'XETR', currency: 'EUR') }

  before do
    Transaction.create(portfolio_id: portfolio.id, instrument_id: aapl.id, kind: 'buy',
                       quantity: 1, price: 100, currency: 'USD', executed_at: Time.now)
    Transaction.create(portfolio_id: portfolio.id, instrument_id: vwce.id, kind: 'buy',
                       quantity: 1, price: 50, currency: 'EUR', executed_at: Time.now)
  end

  it 'updates instrument prices and FX rates' do
    summary = described_class.new(client: fake_client).call

    expect(aapl.refresh.last_price).to eq(BigDecimal('150'))
    expect(vwce.refresh.last_price).to eq(BigDecimal('60'))
    expect(FxRate[base: 'USD', quote: 'PLN'].rate).to eq(BigDecimal('4.0'))
    expect(FxRate[base: 'EUR', quote: 'PLN'].rate).to eq(BigDecimal('4.3'))
    expect(summary[:instruments_updated]).to eq(2)
    expect(summary[:fx_updated]).to eq(2)
  end
end
