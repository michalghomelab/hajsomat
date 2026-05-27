RSpec.describe PortfolioContract do
  subject(:contract) { described_class.new }

  it 'passes with a name' do
    expect(contract.call(name: 'IKE')).to be_success
  end

  it 'fails without a name' do
    expect(contract.call(name: '').errors.to_h[:name]).not_to be_nil
  end
end
