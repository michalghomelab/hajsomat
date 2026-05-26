require "fx_rate"

RSpec.describe FxRate do
  it "inserts then updates the same base/quote pair" do
    FxRate.upsert_rate("USD", "PLN", BigDecimal("4.10"))
    FxRate.upsert_rate("USD", "PLN", BigDecimal("4.25"))
    rows = FxRate.where(base: "USD", quote: "PLN").all
    expect(rows.size).to eq(1)
    expect(rows.first.rate).to eq(BigDecimal("4.25"))
  end
end
