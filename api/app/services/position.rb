require 'dry/struct'

# A single instrument's valued holding. Money fields are BigDecimal or nil
# (nil when the instrument or some buy couldn't be priced/converted).
class Position < Dry::Struct
  attribute :instrument_id, Types::Any
  attribute :symbol, Types::String
  attribute? :name, Types::String.optional
  attribute :currency, Types::String
  attribute :quantity, Types::Any
  attribute :avg_price, Types::Any
  attribute :cost_native, Types::Any
  attribute :last_price, Types::Any.optional
  attribute :market_value_native, Types::Any.optional
  attribute :pnl_native, Types::Any.optional
  attribute :market_value_pln, Types::Any.optional
  attribute :cost_pln, Types::Any.optional
  attribute :pnl_pln, Types::Any.optional
end
