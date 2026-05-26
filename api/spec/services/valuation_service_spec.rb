require "bigdecimal"
require "valuation_service"

Txn = Struct.new(:instrument_id, :quantity, :price, keyword_init: true)

RSpec.describe ValuationService do
  def bd(x) = BigDecimal(x.to_s)

  it "aggregates two buys of one USD instrument and converts to PLN" do
    txns = [
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(100)),
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(120)),
    ]
    instruments = { 1 => { symbol: "AAPL", currency: "USD", last_price: bd(150) } }
    fx = { "USD" => bd(4), "PLN" => bd(1) }

    pos = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx)
    expect(pos.size).to eq(1)
    p = pos.first
    expect(p.quantity).to eq(bd(20))
    expect(p.cost_native).to eq(bd(2200))
    expect(p.avg_price).to eq(bd(110))
    expect(p.market_value_native).to eq(bd(3000))
    expect(p.pnl_native).to eq(bd(800))
    expect(p.market_value_pln).to eq(bd(12000))
    expect(p.cost_pln).to eq(bd(8800))
    expect(p.pnl_pln).to eq(bd(3200))
  end
end
