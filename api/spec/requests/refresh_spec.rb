require 'rage/rspec'

RSpec.describe 'Refresh API', type: :request do
  it 'triggers a refresh and reports a summary' do
    pf = Portfolio.create(name: 'Main')
    inst = Instrument.create(symbol: 'AAPL', currency: 'USD')
    Transaction.create(portfolio_id: pf.id, instrument_id: inst.id, kind: 'buy',
                       quantity: 1, price: 1, currency: 'USD', executed_at: Time.now)

    stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/AAPL})
      .to_return(status: 200,
                 body: { chart: { result: [{ meta: { currency: 'USD', symbol: 'AAPL',
                                                     regularMarketPrice: 150.0 } }],
                                  error: nil } }.to_json)

    stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/USDPLN})
      .to_return(status: 200,
                 body: { chart: { result: [{ meta: { currency: 'PLN', symbol: 'USDPLN=X',
                                                     regularMarketPrice: 4.0 } }],
                                  error: nil } }.to_json)

    post '/api/refresh'
    expect(response.status).to eq(200)
    expect(response.parsed_body['instruments_updated']).to eq(1)
  end
end
