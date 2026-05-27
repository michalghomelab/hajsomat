RSpec.describe TransactionContract do
  subject(:contract) { described_class.new }

  let(:valid_input) do
    { symbol: 'AAPL', currency: 'USD', quantity: '10', price: '150',
      executed_at: '2026-05-20T10:00:00Z' }
  end

  it 'passes for valid input' do
    expect(contract.call(valid_input)).to be_success
  end

  it 'fails for non-positive quantity' do
    result = contract.call(valid_input.merge(quantity: '0'))
    expect(result).to be_failure
    expect(result.errors.to_h[:quantity]).not_to be_nil
  end

  it 'fails for negative price' do
    result = contract.call(valid_input.merge(price: '-5'))
    expect(result.errors.to_h[:price]).not_to be_nil
  end

  it 'fails for a future executed_at' do
    future = (Time.now + 86_400).utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    result = contract.call(valid_input.merge(executed_at: future))
    expect(result.errors.to_h[:executed_at]).not_to be_nil
  end

  it 'fails when symbol is missing' do
    result = contract.call(valid_input.except(:symbol))
    expect(result.errors.to_h[:symbol]).not_to be_nil
  end
end
