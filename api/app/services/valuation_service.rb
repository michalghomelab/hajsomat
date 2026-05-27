require 'bigdecimal'

# Facade over the valuation pieces: builds Positions from transactions, prices
# and FX rates, then rolls them up into totals.
class ValuationService
  def self.positions(transactions:, instruments_by_id:, fx_to_pln:, fx_margin: 0, base_currency: 'PLN')
    margin = BigDecimal(fx_margin.to_s)
    transactions.group_by(&:instrument_id).map do |instrument_id, txns|
      price = instruments_by_id.fetch(instrument_id)
      PositionBuilder.call(
        instrument_id: instrument_id, txns: txns, price: price,
        rate: fx_to_pln[price.currency],
        margin: price.currency == base_currency ? BigDecimal(0) : margin
      )
    end
  end

  def self.totals(positions)
    PositionTotals.call(positions)
  end
end
