# A single instrument's valued holding. Money fields are BigDecimal or nil.
Position = Struct.new(
  :instrument_id, :symbol, :currency, :quantity, :avg_price, :cost_native,
  :last_price, :market_value_native, :pnl_native,
  :market_value_pln, :cost_pln, :pnl_pln, keyword_init: true
)
