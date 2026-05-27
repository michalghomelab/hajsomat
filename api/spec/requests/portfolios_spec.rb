require 'rage/rspec'

RSpec.describe 'Portfolios API', type: :request do
  it 'creates and lists a portfolio' do
    post '/api/portfolios', params: { name: 'IKE' }, as: :json
    expect(response.status).to eq(201)
    created = response.parsed_body
    expect(created['name']).to eq('IKE')

    get '/api/portfolios'
    expect(response.status).to eq(200)
    list = response.parsed_body
    expect(list.map { |p| p['name'] }).to include('IKE')
    expect(list.first).to have_key('pnl_pln')
  end

  it 'rejects a portfolio without a name' do
    post '/api/portfolios', params: { name: '' }, as: :json
    expect(response.status).to eq(422)
  end
end
