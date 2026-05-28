require 'rage/rspec'

RSpec.describe 'Settings API', type: :request do
  it 'returns the default refresh interval' do
    get '/api/settings'
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)['refresh_interval_minutes']).to eq(60)
  end

  it 'updates the refresh interval to an allowed value' do
    patch '/api/settings', params: { refresh_interval_minutes: 30 }, as: :json
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)['refresh_interval_minutes']).to eq(30)

    get '/api/settings'
    expect(JSON.parse(response.body)['refresh_interval_minutes']).to eq(30)
  end

  it 'rejects a disallowed interval' do
    patch '/api/settings', params: { refresh_interval_minutes: 7 }, as: :json
    expect(response.status).to eq(422)
  end
end
