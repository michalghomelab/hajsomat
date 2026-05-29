require 'date'

class SnapshotService
  extend Callable
  extend Dry::Initializer

  option :date, default: -> { Date.today }

  def self.fx_to_pln
    rates = FxRate.all.to_h { |r| [r.base, r.rate] }
    rates.merge('PLN' => BigDecimal(1))
  end

  def call
    fx = self.class.fx_to_pln
    instruments_by_id = InstrumentPriceMap.call

    DB.transaction do
      portfolios = Portfolio.all
      txns_by_portfolio = Transaction.buys_by_portfolio(portfolios.map(&:id))

      portfolios.each do |portfolio|
        txns = txns_by_portfolio.fetch(portfolio.id, [])
        positions = ValuationService.positions(transactions: txns, instruments_by_id: instruments_by_id,
                                               fx_to_pln: fx, **AppConfig.valuation_settings)
        PortfolioSnapshot.upsert_snapshot(portfolio.id, date, ValuationService.totals(positions))
      end.size
    end
  end
end
