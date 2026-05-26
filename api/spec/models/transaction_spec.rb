require 'portfolio'
require 'instrument'
require 'transaction'

RSpec.describe Transaction do
  it 'persists and associates portfolio and instrument' do
    portfolio = Portfolio.create(name: 'Main')
    instrument = Instrument.create(symbol: 'AAPL', currency: 'USD')
    t = described_class.create(portfolio_id: portfolio.id, instrument_id: instrument.id,
                               kind: 'buy', quantity: 10, price: 150, currency: 'USD',
                               executed_at: Time.now)
    expect(t.portfolio.id).to eq(portfolio.id)
    expect(t.instrument.symbol).to eq('AAPL')
  end
end
