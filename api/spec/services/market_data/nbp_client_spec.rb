require 'bigdecimal'
require 'date'

RSpec.describe MarketData::NbpClient do
  let(:client) { described_class.new }

  it 'returns the mid rate for a date' do
    stub_request(:get, %r{api\.nbp\.pl/api/exchangerates/rates/a/eur/2025-07-31})
      .to_return(status: 200, body: { rates: [{ mid: 4.2718 }] }.to_json)
    expect(client.rate('EUR', Date.new(2025, 7, 31))).to eq(BigDecimal('4.2718'))
  end

  it 'returns 1 for PLN without calling the API' do
    expect(client.rate('PLN', Date.new(2025, 7, 31))).to eq(BigDecimal(1))
  end

  it 'steps back to the previous published day when a date has no table (404)' do
    stub_request(:get, %r{rates/a/usd/2026-05-24}).to_return(status: 404, body: 'not found')
    stub_request(:get, %r{rates/a/usd/2026-05-23}).to_return(status: 404, body: 'not found')
    stub_request(:get, %r{rates/a/usd/2026-05-22})
      .to_return(status: 200, body: { rates: [{ mid: 3.65 }] }.to_json)
    expect(client.rate('USD', Date.new(2026, 5, 24))).to eq(BigDecimal('3.65'))
  end
end
