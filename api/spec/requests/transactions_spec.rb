require 'rage/rspec'

RSpec.describe 'Transactions API', type: :request do
  let(:portfolio) { Portfolio.create(name: 'Main') }

  it 'creates a transaction and the instrument when new' do
    stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/AAPL})
      .to_return(status: 200,
                 body: { chart: { result: [{ meta: { currency: 'USD', symbol: 'AAPL',
                                                     regularMarketPrice: 150.0 } }],
                                  error: nil } }.to_json)

    post "/api/portfolios/#{portfolio.id}/transactions",
         params: { symbol: 'AAPL', quantity: '10', price: '150',
                   executed_at: '2026-05-20T10:00:00Z' }, as: :json
    expect(response.status).to eq(201)
    expect(Instrument.where(symbol: 'AAPL').count).to eq(1)
    expect(Instrument.first(symbol: 'AAPL').currency).to eq('USD')
    expect(Transaction.where(portfolio_id: portfolio.id).count).to eq(1)
  end

  it 'rejects an invalid transaction (zero quantity)' do
    post "/api/portfolios/#{portfolio.id}/transactions",
         params: { symbol: 'AAPL', currency: 'USD', quantity: '0', price: '150',
                   executed_at: '2026-05-20T10:00:00Z' }, as: :json
    expect(response.status).to eq(422)
  end

  it 'deletes a transaction' do
    inst = Instrument.create(symbol: 'AAPL', currency: 'USD')
    t = Transaction.create(portfolio_id: portfolio.id, instrument_id: inst.id, kind: 'buy',
                           quantity: 1, price: 1, currency: 'USD', executed_at: Time.now)
    delete "/api/transactions/#{t.id}"
    expect(response.status).to eq(204)
    expect(Transaction[t.id]).to be_nil
  end
end
