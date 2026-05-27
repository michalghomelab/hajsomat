require 'bigdecimal'

# Serializes snapshot rows — works for PortfolioSnapshot models and aggregate
# dataset rows alike (both respond to `[:date]`, `[:total_value_pln]`, …).
class SnapshotPresenter
  def self.call(rows)
    rows.map do |r|
      {
        date: r[:date].to_s,
        total_value_pln: money(r[:total_value_pln]),
        total_cost_pln: money(r[:total_cost_pln]),
        pnl_pln: money(r[:pnl_pln])
      }
    end
  end

  def self.money(value)
    value.nil? ? nil : Decimals.string(BigDecimal(value.to_s))
  end
end
