RSpec.describe FxRate do
  it 'inserts then updates the same base/quote pair' do
    described_class.upsert_rate('USD', 'PLN', BigDecimal('4.10'))
    described_class.upsert_rate('USD', 'PLN', BigDecimal('4.25'))
    rows = described_class.where(base: 'USD', quote: 'PLN').all
    expect(rows.size).to eq(1)
    expect(rows.first.rate).to eq(BigDecimal('4.25'))
  end
end
