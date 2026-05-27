require 'rage/rspec'
require 'portfolio'
require 'instrument'
require 'transaction'

RSpec.describe 'Refresh API', type: :request do
  it 'triggers a refresh and reports a summary' do
    pf = Portfolio.create(name: 'Main')
    inst = Instrument.create(symbol: 'AAPL', currency: 'USD')
    Transaction.create(portfolio_id: pf.id, instrument_id: inst.id, kind: 'buy',
                       quantity: 1, price: 1, currency: 'USD', executed_at: Time.now)

    stub_request(:get, 'https://api.twelvedata.com/price')
      .with(query: hash_including(symbol: 'AAPL')).to_return(status: 200, body: '{"price":"150"}')
    stub_request(:get, 'https://api.twelvedata.com/exchange_rate')
      .with(query: hash_including(symbol: 'USD/PLN')).to_return(status: 200, body: '{"rate":4.0}')

    post '/api/refresh'
    expect(response.status).to eq(200)
    expect(response.parsed_body['instruments_updated']).to eq(1)
  end
end
