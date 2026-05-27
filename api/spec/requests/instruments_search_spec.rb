require 'rage/rspec'

RSpec.describe 'Instrument search API', type: :request do
  it 'proxies Yahoo Finance symbol_search' do
    stub_request(:get, %r{query1\.finance\.yahoo\.com/v1/finance/search})
      .with(query: hash_including(q: 'appl'))
      .to_return(status: 200,
                 body: { quotes: [{ symbol: 'AAPL', shortname: 'Apple Inc',
                                    exchange: 'NMS', currency: 'USD',
                                    quoteType: 'EQUITY' }] }.to_json)

    get '/api/instruments', params: { q: 'appl' }
    expect(response.status).to eq(200)
    results = response.parsed_body
    expect(results.first['symbol']).to eq('AAPL')
    expect(results.first['currency']).to eq('USD')
  end

  it 'returns an empty array for a blank query' do
    get '/api/instruments', params: { q: '' }
    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq([])
  end
end
