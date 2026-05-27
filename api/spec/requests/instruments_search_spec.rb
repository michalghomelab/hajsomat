require 'rage/rspec'

RSpec.describe 'Instrument search API', type: :request do
  it 'proxies Twelve Data symbol_search' do
    stub_request(:get, 'https://api.twelvedata.com/symbol_search')
      .with(query: hash_including(symbol: 'appl'))
      .to_return(status: 200,
                 body: '{"data":[{"symbol":"AAPL","instrument_name":"Apple Inc",' \
                       '"exchange":"NASDAQ","currency":"USD","mic_code":"XNAS"}]}')

    get '/api/instruments/search', params: { q: 'appl' }
    expect(response.status).to eq(200)
    results = response.parsed_body
    expect(results.first['symbol']).to eq('AAPL')
    expect(results.first['currency']).to eq('USD')
  end

  it 'returns an empty array for a blank query' do
    get '/api/instruments/search', params: { q: '' }
    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq([])
  end
end
