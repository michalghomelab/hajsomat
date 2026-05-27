require 'bigdecimal'
require 'date'

RSpec.describe MarketData::YahooClient do
  let(:client) { described_class.new }

  let(:chart_200_body) do
    { chart: { result: [{ meta: { currency: 'EUR', symbol: 'SXR8.DE',
                                  regularMarketPrice: 696.62 } }], error: nil } }.to_json
  end

  let(:chart_404_body) do
    { chart: { result: nil, error: { code: 'Not Found', description: 'No fundamentals data found' } } }.to_json
  end

  describe '#quote' do
    it 'returns price and currency on a 200 response' do
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/SXR8\.DE})
        .to_return(status: 200, body: chart_200_body)

      result = client.quote('SXR8.DE')
      expect(result[:price]).to eq(BigDecimal('696.62'))
      expect(result[:currency]).to eq('EUR')
    end

    it 'returns nil when the symbol is not found (404)' do
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/NOPE})
        .to_return(status: 404, body: chart_404_body)

      expect(client.quote('NOPE')).to be_nil
    end
  end

  describe '#prices' do
    it 'returns a hash keyed by symbol on success' do
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/SXR8\.DE})
        .to_return(status: 200, body: chart_200_body)

      expect(client.prices(['SXR8.DE'])).to eq({ 'SXR8.DE' => BigDecimal('696.62') })
    end

    it 'omits symbols that return 404' do
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/NOPE})
        .to_return(status: 404, body: chart_404_body)

      expect(client.prices(['NOPE'])).to eq({})
    end
  end

  describe '#fx_rate' do
    it 'returns the rate as a BigDecimal' do
      fx_body = { chart: { result: [{ meta: { currency: 'PLN', symbol: 'EURPLN=X',
                                              regularMarketPrice: 4.2372 } }], error: nil } }.to_json
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/EURPLN})
        .to_return(status: 200, body: fx_body)

      expect(client.fx_rate('EUR', 'PLN')).to eq(BigDecimal('4.2372'))
    end

    it 'raises an error when the FX pair is not found' do
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/EURPLN})
        .to_return(status: 404, body: chart_404_body)

      expect { client.fx_rate('EUR', 'PLN') }.to raise_error(MarketData::YahooClient::Error, /no FX rate/)
    end
  end

  describe '#history' do
    it 'maps timestamps to dates and closes to BigDecimals, skipping nils' do
      ts1 = Time.utc(2026, 2, 12).to_i
      ts2 = Time.utc(2026, 2, 13).to_i
      ts3 = Time.utc(2026, 2, 14).to_i
      body = { chart: { result: [{ timestamp: [ts1, ts2, ts3],
                                   indicators: { quote: [{ close: [100.0, nil, 101.5] }] } }],
                        error: nil } }.to_json
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v8/finance/chart/SXR8\.DE})
        .to_return(status: 200, body: body)

      h = client.history('SXR8.DE', range: '5d')
      expect(h[Date.new(2026, 2, 12)]).to eq(BigDecimal('100.0'))
      expect(h[Date.new(2026, 2, 14)]).to eq(BigDecimal('101.5'))
      expect(h).not_to have_key(Date.new(2026, 2, 13)) # nil close skipped
    end
  end

  describe '#symbol_search' do
    it 'returns an array of result hashes' do
      search_body = {
        quotes: [
          { symbol: 'SDJ600.MI', exchange: 'MIL', shortname: 'INVESCO STOXX EUROPE 600 UCITS',
            quoteType: 'ETF' }
        ]
      }.to_json
      stub_request(:get, %r{query1\.finance\.yahoo\.com/v1/finance/search})
        .to_return(status: 200, body: search_body)

      results = client.symbol_search('inv')
      expect(results.first[:symbol]).to eq('SDJ600.MI')
      expect(results.first[:name]).to eq('INVESCO STOXX EUROPE 600 UCITS')
      expect(results.first[:exchange]).to eq('MIL')
    end
  end
end
