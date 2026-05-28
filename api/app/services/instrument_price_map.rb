# Builds { instrument_id => InstrumentPrice } for the valuation layer.
class InstrumentPriceMap
  extend Callable

  def initialize(instruments = Instrument.all)
    @instruments = instruments
  end

  def call
    @instruments.to_h do |i|
      [i.id, InstrumentPrice.new(symbol: i.symbol, currency: i.currency, name: i.name,
                                 last_price: i.last_price, last_price_at: i.last_price_at)]
    end
  end
end
