require 'bigdecimal'

RSpec.describe MarketData::TwelveDataClient do
  let(:client) { described_class.new(api_key: 'TESTKEY') }

  it 'parses a single-symbol price response' do
    stub_request(:get, 'https://api.twelvedata.com/price')
      .with(query: { symbol: 'AAPL', apikey: 'TESTKEY' })
      .to_return(status: 200, body: '{"price":"150.10"}', headers: { 'Content-Type' => 'application/json' })

    expect(client.prices(['AAPL'])).to eq({ 'AAPL' => BigDecimal('150.10') })
  end

  it 'parses a multi-symbol price response' do
    stub_request(:get, 'https://api.twelvedata.com/price')
      .with(query: { symbol: 'AAPL,MSFT', apikey: 'TESTKEY' })
      .to_return(status: 200, body: '{"AAPL":{"price":"150.10"},"MSFT":{"price":"410.20"}}',
                 headers: { 'Content-Type' => 'application/json' })

    expect(client.prices(%w[AAPL MSFT]))
      .to eq({ 'AAPL' => BigDecimal('150.10'), 'MSFT' => BigDecimal('410.20') })
  end

  it 'omits symbols whose response carries an error status' do
    stub_request(:get, 'https://api.twelvedata.com/price')
      .with(query: { symbol: 'BAD', apikey: 'TESTKEY' })
      .to_return(status: 200, body: '{"status":"error","message":"symbol not found"}',
                 headers: { 'Content-Type' => 'application/json' })

    expect(client.prices(['BAD'])).to eq({})
  end

  it 'parses an exchange rate' do
    stub_request(:get, 'https://api.twelvedata.com/exchange_rate')
      .with(query: { symbol: 'USD/PLN', apikey: 'TESTKEY' })
      .to_return(status: 200, body: '{"symbol":"USD/PLN","rate":4.12}',
                 headers: { 'Content-Type' => 'application/json' })

    expect(client.fx_rate('USD', 'PLN')).to eq(BigDecimal('4.12'))
  end
end
