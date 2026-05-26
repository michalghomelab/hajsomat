require "bigdecimal"

class ValuationService
  Position = Struct.new(
    :instrument_id, :symbol, :currency, :quantity, :avg_price, :cost_native,
    :last_price, :market_value_native, :pnl_native,
    :market_value_pln, :cost_pln, :pnl_pln, keyword_init: true
  )

  def self.positions(transactions:, instruments_by_id:, fx_to_pln:)
    grouped = transactions.group_by(&:instrument_id)
    grouped.map do |instrument_id, txns|
      meta = instruments_by_id.fetch(instrument_id)
      currency = meta[:currency]
      quantity = txns.sum(BigDecimal(0)) { |t| t.quantity }
      cost_native = txns.sum(BigDecimal(0)) { |t| t.quantity * t.price }
      avg_price = quantity.zero? ? BigDecimal(0) : (cost_native / quantity).round(6, half: :up)
      last_price = meta[:last_price]
      fx = fx_to_pln[currency]

      market_value_native = last_price ? quantity * last_price : nil
      pnl_native = market_value_native ? market_value_native - cost_native : nil
      market_value_pln = (market_value_native && fx) ? market_value_native * fx : nil
      cost_pln = fx ? cost_native * fx : nil
      pnl_pln = (market_value_pln && cost_pln) ? market_value_pln - cost_pln : nil

      Position.new(
        instrument_id: instrument_id, symbol: meta[:symbol], currency: currency,
        quantity: quantity, avg_price: avg_price, cost_native: cost_native,
        last_price: last_price, market_value_native: market_value_native,
        pnl_native: pnl_native, market_value_pln: market_value_pln,
        cost_pln: cost_pln, pnl_pln: pnl_pln
      )
    end
  end

  def self.totals(positions)
    {
      market_value_pln: positions.sum(BigDecimal(0)) { |p| p.market_value_pln || BigDecimal(0) },
      cost_pln: positions.sum(BigDecimal(0)) { |p| p.cost_pln || BigDecimal(0) },
      pnl_pln: positions.sum(BigDecimal(0)) { |p| p.pnl_pln || BigDecimal(0) },
    }
  end
end
