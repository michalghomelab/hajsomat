require 'bigdecimal'

RSpec.describe InstrumentNameBackfiller do
  let(:client) do
    Class.new do
      def quote(symbol)
        { 'SXR8.DE' => { name: 'iShares Core S&P 500 UCITS ETF USD (Acc)' } }[symbol]
      end
    end.new
  end

  it 'names instruments that have none and leaves existing names untouched' do
    blank = Instrument.create(symbol: 'SXR8.DE', currency: 'EUR')
    named = Instrument.create(symbol: 'XTB.WA', currency: 'PLN', name: 'X-Trade Brokers')

    filled = described_class.call([blank, named], client: client)

    expect(filled).to eq(1)
    expect(blank.refresh.name).to eq('iShares Core S&P 500 UCITS ETF USD (Acc)')
    expect(named.refresh.name).to eq('X-Trade Brokers')
  end

  it 'skips an instrument whose quote has no name' do
    inst = Instrument.create(symbol: 'UNKNOWN', currency: 'USD')

    expect(described_class.call([inst], client: client)).to eq(0)
    expect(inst.refresh.name).to be_nil
  end

  it 'survives a failing quote without aborting the batch' do
    boom = Class.new do
      def quote(_symbol) = raise(MarketData::YahooClient::Error, 'rate limited')
    end.new
    inst = Instrument.create(symbol: 'SXR8.DE', currency: 'EUR')

    expect(described_class.call([inst], client: boom)).to eq(0)
    expect(inst.refresh.name).to be_nil
  end
end
