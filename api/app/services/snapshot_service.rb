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
    instruments_by_id = InstrumentPriceMap.call

    DB.transaction do
      Portfolio.all.each do |portfolio|
        txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
        positions = ValuationService.positions(transactions: txns, instruments_by_id: instruments_by_id,
                                               fx_to_pln: fx, **AppConfig.valuation_settings)
        PortfolioSnapshot.upsert_snapshot(portfolio.id, @date, ValuationService.totals(positions))
      end.size
    end
  end
end
