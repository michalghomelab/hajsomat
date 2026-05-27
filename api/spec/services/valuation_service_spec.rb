require 'bigdecimal'

Txn = Struct.new(:instrument_id, :quantity, :price, keyword_init: true)

RSpec.describe ValuationService do
  def bd(val) = BigDecimal(val.to_s)

  it 'aggregates two buys of one USD instrument and converts to PLN' do
    txns = [
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(100)),
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(120))
    ]
    instruments = { 1 => { symbol: 'AAPL', currency: 'USD', last_price: bd(150) } }
    fx = { 'USD' => bd(4), 'PLN' => bd(1) }

    pos = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx)
    expect(pos.size).to eq(1)
    p = pos.first
    expect(p.quantity).to eq(bd(20))
    expect(p.cost_native).to eq(bd(2200))
    expect(p.avg_price).to eq(bd(110))
    expect(p.market_value_native).to eq(bd(3000))
    expect(p.pnl_native).to eq(bd(800))
    expect(p.market_value_pln).to eq(bd(12_000))
    expect(p.cost_pln).to eq(bd(8800))
    expect(p.pnl_pln).to eq(bd(3200))
  end

  it 'sums totals across USD and EUR positions' do
    txns = [
      Txn.new(instrument_id: 1, quantity: bd(10), price: bd(100)), # USD
      Txn.new(instrument_id: 2, quantity: bd(5),  price: bd(50)) # EUR
    ]
    instruments = {
      1 => { symbol: 'AAPL', currency: 'USD', last_price: bd(120) },
      2 => { symbol: 'VWCE', currency: 'EUR', last_price: bd(60) }
    }
    fx = { 'USD' => bd(4), 'EUR' => bd(4.3), 'PLN' => bd(1) }

    pos = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx)
    totals = described_class.totals(pos)
    # USD: value 1200*4=4800, cost 1000*4=4000 ; EUR: value 300*4.3=1290, cost 250*4.3=1075
    expect(totals[:market_value_pln]).to eq(bd(6090))
    expect(totals[:cost_pln]).to eq(bd(5075))
    expect(totals[:pnl_pln]).to eq(bd(1015))
  end

  it 'leaves PLN fields nil when last_price is missing' do
    txns = [Txn.new(instrument_id: 1, quantity: bd(1), price: bd(10))]
    instruments = { 1 => { symbol: 'X', currency: 'USD', last_price: nil } }
    fx = { 'USD' => bd(4), 'PLN' => bd(1) }
    p = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx).first
    expect(p.market_value_native).to be_nil
    expect(p.pnl_pln).to be_nil
    expect(p.cost_pln).to eq(bd(40)) # cost still converts with FX
  end

  it 'treats nil PLN values as zero in totals' do
    txns = [Txn.new(instrument_id: 1, quantity: bd(1), price: bd(10))]
    instruments = { 1 => { symbol: 'X', currency: 'USD', last_price: nil } }
    fx = { 'USD' => bd(4), 'PLN' => bd(1) }
    totals = described_class.totals(described_class.positions(transactions: txns, instruments_by_id: instruments,
                                                              fx_to_pln: fx))
    expect(totals[:market_value_pln]).to eq(bd(0))
  end

  it 'leaves all PLN fields nil when the FX rate is missing' do
    txns = [Txn.new(instrument_id: 1, quantity: bd(1), price: bd(10))]
    instruments = { 1 => { symbol: 'X', currency: 'USD', last_price: bd(15) } }
    fx = {} # no USD rate
    p = described_class.positions(transactions: txns, instruments_by_id: instruments, fx_to_pln: fx).first
    expect(p.cost_pln).to be_nil
    expect(p.market_value_pln).to be_nil
    expect(p.pnl_pln).to be_nil
    # native fields still computed
    expect(p.market_value_native).to eq(bd(15))
    expect(p.pnl_native).to eq(bd(5))
  end

  it 'returns empty positions for empty transactions' do
    expect(described_class.positions(transactions: [], instruments_by_id: {}, fx_to_pln: {})).to eq([])
  end

  it 'returns zero totals for empty positions' do
    expect(described_class.totals([])[:market_value_pln]).to eq(bd(0))
  end
end
