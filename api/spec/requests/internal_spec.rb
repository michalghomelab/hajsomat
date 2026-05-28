require 'rage/rspec'

RSpec.describe 'Internal API', type: :request do
  it 'accepts a refresh notification' do
    post '/api/internal/refreshed'
    expect(response.status).to eq(204)
  end
end
