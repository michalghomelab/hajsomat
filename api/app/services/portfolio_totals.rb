require 'dry/struct'

# Portfolio-level rollup of valued positions (PLN). Money fields are nil when a
# position couldn't be priced; `incomplete` then flags the sum as partial.
class PortfolioTotals < Dry::Struct
  attribute :market_value_pln, Types::Any.optional
  attribute :cost_pln, Types::Any.optional
  attribute :pnl_pln, Types::Any.optional
  attribute :incomplete, Types::Bool
end
