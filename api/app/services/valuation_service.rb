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
    quantity, cost_native, avg_price = aggregate(txns)
    rate = fx_ctx[:rates][meta[:currency]]
    # FX margin applies only when converting a foreign currency, not the base currency itself.
    margin = meta[:currency] == fx_ctx[:base] ? BigDecimal(0) : fx_ctx[:margin]
    native = compute_native(quantity, meta[:last_price], cost_native)
    pln = compute_pln(native, cost_native, rate, margin)

    Position.new(
      instrument_id: instrument_id, symbol: meta[:symbol], currency: meta[:currency],
      quantity: quantity, avg_price: avg_price, cost_native: cost_native,
      last_price: meta[:last_price], **native, **pln
    )
  end
  private_class_method :build_position

  def self.aggregate(txns)
    quantity = txns.sum(BigDecimal(0), &:quantity)
    cost_native = txns.sum(BigDecimal(0)) { |t| t.quantity * t.price }
    avg_price = quantity.zero? ? BigDecimal(0) : (cost_native / quantity).round(6, half: :up)
    [quantity, cost_native, avg_price]
  end
  private_class_method :aggregate

  def self.compute_native(quantity, last_price, cost_native)
    market_value_native = last_price ? quantity * last_price : nil
    pnl_native = market_value_native ? market_value_native - cost_native : nil
    { market_value_native: market_value_native, pnl_native: pnl_native }
  end
  private_class_method :compute_native

  def self.compute_pln(native, cost_native, rate, margin)
    return { market_value_pln: nil, cost_pln: nil, pnl_pln: nil } unless rate

    one = BigDecimal(1)
    mv_native = native[:market_value_native]
    market_value_pln = mv_native ? mv_native * rate * (one - margin) : nil
    cost_pln = cost_native * rate * (one + margin)
    pnl_pln = market_value_pln ? market_value_pln - cost_pln : nil
    { market_value_pln: market_value_pln, cost_pln: cost_pln, pnl_pln: pnl_pln }
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
