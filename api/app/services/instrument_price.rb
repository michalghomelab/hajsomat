require 'dry/struct'

# Typed view of an instrument's pricing data, consumed by ValuationService.
class InstrumentPrice < Dry::Struct
  attribute :symbol, Types::String
  attribute? :name, Types::String.optional
  attribute :currency, Types::String
  attribute :last_price, Types::Any.optional
  attribute :last_price_at, Types::Any.optional
end
