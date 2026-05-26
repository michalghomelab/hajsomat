require 'date'
require 'valuation_service'

class SnapshotService
  def self.fx_to_pln
    rates = FxRate.all.to_h { |r| [r.base, r.rate] }
    rates.merge('PLN' => BigDecimal(1))
  end

  def call(date: Date.today)
    fx = self.class.fx_to_pln
    instruments_by_id = Instrument.all.to_h do |i|
      [i.id, { symbol: i.symbol, currency: i.currency, last_price: i.last_price }]
    end

    count = 0
    Portfolio.all.each do |portfolio|
      txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
      positions = ValuationService.positions(
        transactions: txns, instruments_by_id: instruments_by_id, fx_to_pln: fx
      )
      totals = ValuationService.totals(positions)
      upsert_snapshot(portfolio.id, date, totals)
      count += 1
    end
    count
  end

  private

  def upsert_snapshot(portfolio_id, date, totals)
    row = PortfolioSnapshot[portfolio_id: portfolio_id, date: date]
    attrs = {
      total_value_pln: totals[:market_value_pln],
      total_cost_pln: totals[:cost_pln],
      pnl_pln: totals[:pnl_pln]
    }
    row ? row.update(attrs) : PortfolioSnapshot.create(attrs.merge(portfolio_id: portfolio_id, date: date))
  end
end
