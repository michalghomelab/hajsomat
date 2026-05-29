require 'dry/monads'

# Read facade behind the portfolios API: builds the shared price map + FX once,
# values each portfolio's buys, and returns presenter-ready JSON. Keeps the
# controller logic-free.
class PortfolioValuation
  include Dry::Monads[:result]

  def self.summary = new.summary
  def self.detail(id) = new.detail(id)

  def summary
    Success(Portfolio.all.map { |p| present(p, buys(p)) })
  end

  def detail(id)
    portfolio = Portfolio[id.to_i]
    return Failure([:not_found, { error: 'not found' }]) unless portfolio

    txns = buys(portfolio)
    Success(present(portfolio, txns, transactions: txns.group_by(&:instrument_id)))
  end

  private

  def present(portfolio, txns, transactions: nil)
    positions = ValuationService.positions(transactions: txns, instruments_by_id: price_map,
                                           fx_to_pln: fx, **AppConfig.valuation_settings)
    PortfolioPresenter.call(portfolio, positions: positions, price_map: price_map, transactions: transactions)
  end

  def buys(portfolio) = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
  def price_map = @price_map ||= InstrumentPriceMap.call
  def fx = @fx ||= SnapshotService.fx_to_pln
end
