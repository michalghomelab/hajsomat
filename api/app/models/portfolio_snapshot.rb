class PortfolioSnapshot < Sequel::Model
  many_to_one :portfolio

  # Atomic upsert keyed by the unique (portfolio_id, date) index.
  def self.upsert_snapshot(portfolio_id, date, totals)
    values = {
      total_value_pln: totals[:market_value_pln],
      total_cost_pln: totals[:cost_pln],
      pnl_pln: totals[:pnl_pln]
    }
    dataset.insert_conflict(target: %i[portfolio_id date], update: values)
           .insert(values.merge(portfolio_id: portfolio_id, date: date))
  end
end
