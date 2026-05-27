RSpec.describe AppConfig do
  it 'defaults the base currency to PLN' do
    expect(described_class.config.base_currency).to eq('PLN')
  end

  it 'defaults the Yahoo Finance base url' do
    expect(described_class.config.market_data.base_url).to eq('https://query1.finance.yahoo.com')
  end
end
