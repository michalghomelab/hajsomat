# Serializes snapshot rows — works for PortfolioSnapshot models and aggregate
# dataset rows alike (both respond to `[:date]`, `[:total_value_pln]`, …).
class SnapshotPresenter
  def self.call(rows)
    rows.map do |r|
      {
        date: r[:date].to_s,
        total_value_pln: Decimals.string(r[:total_value_pln]),
        total_cost_pln: Decimals.string(r[:total_cost_pln]),
        pnl_pln: Decimals.string(r[:pnl_pln])
      }
    end
  end
end
