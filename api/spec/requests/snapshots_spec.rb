require 'rage/rspec'

RSpec.describe 'Aggregate snapshots API', type: :request do
  it 'sums snapshots across portfolios by date' do
    p1 = Portfolio.create(name: 'A')
    p2 = Portfolio.create(name: 'B')
    date = Date.new(2026, 5, 26)
    PortfolioSnapshot.create(portfolio_id: p1.id, date: date, total_value_pln: BigDecimal('100'),
                             total_cost_pln: BigDecimal('80'), pnl_pln: BigDecimal('20'))
    PortfolioSnapshot.create(portfolio_id: p2.id, date: date, total_value_pln: BigDecimal('50'),
                             total_cost_pln: BigDecimal('40'), pnl_pln: BigDecimal('10'))

    get '/api/snapshots'
    expect(response.status).to eq(200)
    row = response.parsed_body.first
    expect(row['date']).to eq('2026-05-26')
    expect(Float(row['total_value_pln'])).to eq(150.0)
    expect(Float(row['pnl_pln'])).to eq(30.0)
  end
end
