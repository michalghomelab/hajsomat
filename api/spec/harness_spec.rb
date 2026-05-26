RSpec.describe 'harness' do
  it 'has the portfolios table' do
    expect(DB.tables).to include(:portfolios)
  end
end
