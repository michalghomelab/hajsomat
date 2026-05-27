require 'date'

class SnapshotService
  extend Callable

  def self.fx_to_pln
    rates = FxRate.all.to_h { |r| [r.base, r.rate] }
    rates.merge('PLN' => BigDecimal(1))
  end

  def initialize(date: Date.today)
    @date = date
  end

  def call
    fx = self.class.fx_to_pln
    instruments_by_id = Instrument.all.to_h do |i|
      [i.id, { symbol: i.symbol, currency: i.currency, last_price: i.last_price }]
    end

    Portfolio.all.each do |portfolio|
      txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
      positions = ValuationService.positions(transactions: txns, instruments_by_id: instruments_by_id,
                                             fx_to_pln: fx, **AppConfig.valuation_settings)
      upsert_snapshot(portfolio.id, ValuationService.totals(positions))
    end.size
  end

  private

  def upsert_snapshot(portfolio_id, totals)
    row = PortfolioSnapshot[portfolio_id: portfolio_id, date: @date]
    attrs = {
      total_value_pln: totals[:market_value_pln],
      total_cost_pln: totals[:cost_pln],
      pnl_pln: totals[:pnl_pln]
    }
    row ? row.update(attrs) : PortfolioSnapshot.create(attrs.merge(portfolio_id: portfolio_id, date: @date))
  end
end
