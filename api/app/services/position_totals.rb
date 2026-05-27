require 'bigdecimal'

# Rolls valued positions up into portfolio totals (PLN), flagging the result
# incomplete when any position could not be priced.
class PositionTotals
  extend Callable

  def initialize(positions)
    @positions = positions
  end

  def call
    {
      market_value_pln: sum(&:market_value_pln),
      cost_pln: sum(&:cost_pln),
      pnl_pln: sum(&:pnl_pln),
      incomplete: @positions.any? { |p| p.market_value_pln.nil? }
    }
  end

  private

  def sum(&field)
    @positions.sum(BigDecimal(0)) { |p| field.call(p) || BigDecimal(0) }
  end
end
