require 'bigdecimal'

# Values a single instrument's position from its buys, the latest price, and the
# FX rate to the base currency. The broker FX spread (`margin`) is added to the
# PLN cost at purchase time and subtracted from the PLN market value.
class PositionBuilder
  extend Callable
  extend Dry::Initializer

  option :instrument_id
  option :txns
  option :price
  option :rate
  option :margin

  def call
    quantity = txns.sum(BigDecimal(0), &:quantity)
    cost_native = txns.sum(BigDecimal(0)) { |t| t.quantity * t.price }
    build(quantity, cost_native)
  end

  private

  def build(quantity, cost_native)
    mv_native = market_value_native(quantity)
    mv_pln = market_value_pln(mv_native)
    cost_pln = cost_in_pln

    Position.new(
      instrument_id: instrument_id, symbol: price.symbol, name: price.name, currency: price.currency,
      quantity: quantity, avg_price: average_price(quantity, cost_native), cost_native: cost_native,
      last_price: price.last_price,
      market_value_native: mv_native, pnl_native: diff(mv_native, cost_native),
      cost_pln: cost_pln, market_value_pln: mv_pln, pnl_pln: diff(mv_pln, cost_pln)
    )
  end

  def market_value_native(quantity)
    price.last_price ? quantity * price.last_price : nil
  end

  def market_value_pln(mv_native)
    mv_native && rate ? mv_native * rate * (BigDecimal(1) - margin) : nil
  end

  def diff(value, base)
    value && base ? value - base : nil
  end

  def average_price(quantity, cost_native)
    return BigDecimal(0) if quantity.zero?

    (cost_native / quantity).round(6, half: :up)
  end

  # Each buy uses the FX rate captured at its purchase date (NBP table A),
  # falling back to the current rate; the broker spread is added on top.
  # nil when no rate is available for some buy.
  def cost_in_pln
    total = BigDecimal(0)
    txns.each do |t|
      fx = (t.fx_rate if t.respond_to?(:fx_rate)) || rate
      return nil unless fx

      total += t.quantity * t.price * fx
    end
    total * (BigDecimal(1) + margin)
  end
end
