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
    expect(body['totals']['market_value_pln']).to eq('0.6e4')
    expect(body['totals']['incomplete']).to be(false)
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
    expect(row['total_value_pln']).to eq('0.1e3')
  end
end
