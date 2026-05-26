require "instrument"

RSpec.describe Instrument do
  it "builds the Twelve Data symbol with MIC suffix when present" do
    i = Instrument.new(symbol: "VWCE", mic: "XETR", currency: "EUR")
    expect(i.td_symbol).to eq("VWCE:XETR")
  end

  it "uses the bare symbol for US tickers without a MIC" do
    i = Instrument.new(symbol: "AAPL", mic: nil, currency: "USD")
    expect(i.td_symbol).to eq("AAPL")
  end
end
