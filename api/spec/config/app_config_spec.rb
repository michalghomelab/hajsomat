RSpec.describe AppConfig do
  it 'defaults the base currency to PLN' do
    expect(described_class.config.base_currency).to eq('PLN')
  end

  it 'defaults the Twelve Data base url' do
    expect(described_class.config.twelve_data.base_url).to eq('https://api.twelvedata.com')
  end

  it 'exposes a Twelve Data api_key setting' do
    expect(described_class.config.twelve_data).to respond_to(:api_key)
  end
end
