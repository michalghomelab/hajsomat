RSpec.describe Instrument do
  it 'persists and reads back symbol and currency' do
    inst = described_class.create(symbol: 'SXR8.DE', currency: 'EUR')
    found = described_class[inst.id]
    expect(found.symbol).to eq('SXR8.DE')
    expect(found.currency).to eq('EUR')
  end
end
