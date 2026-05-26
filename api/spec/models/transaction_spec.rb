require "portfolio"
require "instrument"
require "transaction"

RSpec.describe Transaction do
  let(:portfolio) { Portfolio.create(name: "Main") }
  let(:instrument) { Instrument.create(symbol: "AAPL", currency: "USD") }

  it "is valid for a positive buy" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 10, price: 150, currency: "USD",
                         executed_at: Time.now)
    expect(t.valid?).to be true
  end

  it "rejects non-positive quantity" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 0, price: 150, currency: "USD",
                         executed_at: Time.now)
    expect(t.valid?).to be false
    expect(t.errors[:quantity]).not_to be_empty
  end

  it "rejects a future executed_at" do
    t = Transaction.new(portfolio_id: portfolio.id, instrument_id: instrument.id,
                         kind: "buy", quantity: 1, price: 1, currency: "USD",
                         executed_at: Time.now + 86_400)
    expect(t.valid?).to be false
  end
end
