require 'dry/struct'

# Typed view of an instrument's pricing data, consumed by ValuationService.
class InstrumentPrice < Dry::Struct
  attribute :symbol, Types::String
  attribute? :name, Types::String.optional
  attribute :currency, Types::String
  attribute :last_price, Types::Any.optional
  attribute :last_price_at, Types::Any.optional

  # Builds the view from an Instrument record + a price source (the current
  # last_price, or a historical close for backfill).
  def self.from(instrument, last_price:, last_price_at: nil)
    new(symbol: instrument.symbol, currency: instrument.currency, name: instrument.name,
        last_price: last_price, last_price_at: last_price_at)
  end
end
