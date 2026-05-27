require 'bigdecimal'

class ValuationService
  Position = Struct.new(
    :instrument_id, :symbol, :currency, :quantity, :avg_price, :cost_native,
    :last_price, :market_value_native, :pnl_native,
    :market_value_pln, :cost_pln, :pnl_pln, keyword_init: true
  )

  def self.positions(transactions:, instruments_by_id:, fx_to_pln:, fx_margin: 0, base_currency: 'PLN')
    fx = { rates: fx_to_pln, margin: BigDecimal(fx_margin.to_s), base: base_currency }
    transactions.group_by(&:instrument_id).map do |instrument_id, txns|
      build_position(instrument_id, txns, instruments_by_id, fx)
    end
  end

  def self.build_position(instrument_id, txns, instruments_by_id, fx_ctx)
    meta = instruments_by_id.fetch(instrument_id)
    currency = meta[:currency]
    rate = fx_ctx[:rates][currency]
    margin = currency == fx_ctx[:base] ? BigDecimal(0) : fx_ctx[:margin]
    quantity, cost_native, cost_pln, avg_price = aggregate(txns, rate)
    native = compute_native(quantity, meta[:last_price], cost_native)
    pln = compute_pln(native[:market_value_native], cost_pln, rate, margin)

    Position.new(
      instrument_id: instrument_id, symbol: meta[:symbol], currency: currency,
      quantity: quantity, avg_price: avg_price, cost_native: cost_native,
      last_price: meta[:last_price], cost_pln: cost_pln, **native, **pln
    )
  end
  private_class_method :build_position

  def self.aggregate(txns, rate)
    quantity = txns.sum(BigDecimal(0), &:quantity)
    cost_native = txns.sum(BigDecimal(0)) { |t| t.quantity * t.price }
    avg_price = quantity.zero? ? BigDecimal(0) : (cost_native / quantity).round(6, half: :up)
    [quantity, cost_native, cost_in_pln(txns, rate), avg_price]
  end
  private_class_method :aggregate

  # Historical PLN cost: each buy uses the FX rate captured at its purchase date
  # (NBP table A), falling back to the current rate only when that rate is missing.
  def self.cost_in_pln(txns, rate)
    total = BigDecimal(0)
    txns.each do |t|
      fx = tx_fx_rate(t) || rate
      return nil unless fx

      total += t.quantity * t.price * fx
    end
    total
  end
  private_class_method :cost_in_pln

  def self.tx_fx_rate(txn)
    txn.respond_to?(:fx_rate) ? txn.fx_rate : nil
  end
  private_class_method :tx_fx_rate

  def self.compute_native(quantity, last_price, cost_native)
    market_value_native = last_price ? quantity * last_price : nil
    pnl_native = market_value_native ? market_value_native - cost_native : nil
    { market_value_native: market_value_native, pnl_native: pnl_native }
  end
  private_class_method :compute_native

  # FX margin (broker spread) applies only to the current market value, not to the
  # historical cost basis, which is already in real PLN paid.
  def self.compute_pln(market_value_native, cost_pln, rate, margin)
    market_value_pln = market_value_native && rate ? market_value_native * rate * (BigDecimal(1) - margin) : nil
    pnl_pln = market_value_pln && cost_pln ? market_value_pln - cost_pln : nil
    { market_value_pln: market_value_pln, pnl_pln: pnl_pln }
  end
  private_class_method :compute_pln

  def self.totals(positions)
    {
      market_value_pln: positions.sum(BigDecimal(0)) { |p| p.market_value_pln || BigDecimal(0) },
      cost_pln: positions.sum(BigDecimal(0)) { |p| p.cost_pln || BigDecimal(0) },
      pnl_pln: positions.sum(BigDecimal(0)) { |p| p.pnl_pln || BigDecimal(0) },
      incomplete: incomplete?(positions)
    }
  end

  def self.incomplete?(positions)
    positions.any? { |p| p.market_value_pln.nil? }
  end
  private_class_method :incomplete?
end
