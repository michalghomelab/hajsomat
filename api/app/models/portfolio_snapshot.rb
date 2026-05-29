class PortfolioSnapshot < Sequel::Model
  extend Upsertable

  many_to_one :portfolio

  dataset_module do
    def for_portfolio(portfolio_id) = where(portfolio_id: portfolio_id).order(:date)

    # One row per date, summing the value/cost/PnL across all portfolios.
    def totals_by_date
      select_group(:date)
        .select_append do
          [Sequel.function(:sum, :total_value_pln).as(:total_value_pln),
           Sequel.function(:sum, :total_cost_pln).as(:total_cost_pln),
           Sequel.function(:sum, :pnl_pln).as(:pnl_pln)]
        end
        .order(:date)
    end
  end

  # Atomic upsert keyed by the unique (portfolio_id, date) index.
  def self.upsert_snapshot(portfolio_id, date, totals)
    upsert(
      { portfolio_id: portfolio_id, date: date,
        total_value_pln: totals.market_value_pln, total_cost_pln: totals.cost_pln, pnl_pln: totals.pnl_pln },
      conflict_target: %i[portfolio_id date]
    )
  end
end
