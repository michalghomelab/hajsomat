require 'rage/rspec'

RSpec.describe 'Portfolio detail API', type: :request do
  it 'returns positions and totals for a portfolio' do
    portfolio = Portfolio.create(name: 'Main')
    inst = Instrument.create(symbol: 'AAPL', currency: 'USD', last_price: BigDecimal('150'))
    Transaction.create(portfolio_id: portfolio.id, instrument_id: inst.id, kind: 'buy',
                       quantity: 10, price: 100, currency: 'USD', executed_at: Time.now)
    FxRate.upsert_rate('USD', 'PLN', BigDecimal('4'))

    get "/api/portfolios/#{portfolio.id}"
    expect(response.status).to eq(200)
    body = response.parsed_body
    expect(body['name']).to eq('Main')
    expect(body['positions'].first['symbol']).to eq('AAPL')
    expect(body['totals']['market_value_pln']).to eq('5970.0') # 10*150*4*(1-0.005) FX margin
    expect(body['totals']['incomplete']).to be(false)

    txns = body['positions'].first['transactions']
    expect(txns.size).to eq(1)
    expect(txns.first['quantity']).to eq('10.0')
    expect(txns.first['price']).to eq('100.0')
  end

  it 'renames a portfolio' do
    portfolio = Portfolio.create(name: 'Old')
    patch "/api/portfolios/#{portfolio.id}", params: { name: 'IKE Plus' }, as: :json
    expect(response.status).to eq(200)
    expect(response.parsed_body['name']).to eq('IKE Plus')
    expect(Portfolio[portfolio.id].name).to eq('IKE Plus')
  end

  it 'rejects renaming to a blank name' do
    portfolio = Portfolio.create(name: 'Keep')
    patch "/api/portfolios/#{portfolio.id}", params: { name: '' }, as: :json
    expect(response.status).to eq(422)
    expect(Portfolio[portfolio.id].name).to eq('Keep')
  end

  it 'returns snapshots for a portfolio' do
    portfolio = Portfolio.create(name: 'Main')
    PortfolioSnapshot.create(portfolio_id: portfolio.id, date: Date.new(2026, 5, 26),
                             total_value_pln: BigDecimal('100'), total_cost_pln: BigDecimal('80'),
                             pnl_pln: BigDecimal('20'))
    get "/api/portfolios/#{portfolio.id}/snapshots"
    expect(response.status).to eq(200)
    row = response.parsed_body.first
    expect(row['date']).to eq('2026-05-26')
    expect(row['total_value_pln']).to eq('100.0')
  end
end
