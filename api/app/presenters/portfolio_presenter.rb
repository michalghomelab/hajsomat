# Serializes a portfolio. Omit `transactions:` for the list summary; pass the
# { instrument_id => [txns] } map to get the full detail view with positions.
class PortfolioPresenter
  def self.call(portfolio, positions:, price_map:, transactions: nil)
    new(portfolio, positions, price_map).as_json(transactions)
  end

  def initialize(portfolio, positions, price_map)
    @portfolio = portfolio
    @positions = positions
    @price_map = price_map
  end

  def as_json(transactions)
    transactions ? detail(transactions) : summary
  end

  private

  def summary
    base.merge(serialized_totals, last_updated: last_updated)
  end

  def detail(txns_by_instrument)
    base.merge(
      totals: serialized_totals,
      last_updated: last_updated,
      positions: @positions.map { |pos| position(pos, txns_by_instrument) }
    )
  end

  def base
    { id: @portfolio.id, name: @portfolio.name, base_currency: @portfolio.base_currency }
  end

  def serialized_totals
    totals = ValuationService.totals(@positions)
    {
      market_value_pln: Decimals.string(totals[:market_value_pln]),
      cost_pln: Decimals.string(totals[:cost_pln]),
      pnl_pln: Decimals.string(totals[:pnl_pln]),
      incomplete: totals[:incomplete]
    }
  end

  def last_updated
    @positions.filter_map { |p| @price_map[p.instrument_id].last_price_at }.max&.iso8601
  end

  def position(pos, txns_by_instrument)
    fields = pos.to_h.transform_values { |v| Decimals.string(v) }
    fields.merge(transactions: TransactionPresenter.call(txns_by_instrument[pos.instrument_id]))
  end
end
