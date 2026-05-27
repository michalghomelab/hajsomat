require 'net/http'
require 'json'
require 'bigdecimal'
require 'uri'

module MarketData
  class TwelveDataClient
    # Raised for global provider failures worth surfacing (bad API key, rate limit).
    class Error < StandardError; end

    # Twelve Data error codes that affect the whole request, not a single symbol.
    GLOBAL_ERROR_CODES = [401, 429].freeze

    def initialize(api_key: AppConfig.config.twelve_data.api_key, http_base: AppConfig.config.twelve_data.base_url)
      @api_key = api_key
      @http_base = http_base
    end

    def prices(symbols)
      return {} if symbols.empty?

      body = get('/price', symbol: symbols.join(','))
      result = {}
      if symbols.size == 1
        sym = symbols.first
        result[sym] = BigDecimal(body['price']) if body['price']
      else
        symbols.each do |sym|
          node = body[sym]
          result[sym] = BigDecimal(node['price']) if node.is_a?(Hash) && node['price']
        end
      end
      result
    end

    def fx_rate(base, quote)
      body = get('/exchange_rate', symbol: "#{base}/#{quote}")
      BigDecimal(body.fetch('rate').to_s)
    end

    def symbol_search(query)
      body = get('/symbol_search', symbol: query)
      Array(body['data']).map do |row|
        { symbol: row['symbol'], name: row['instrument_name'],
          exchange: row['exchange'], currency: row['currency'], mic: row['mic_code'] }
      end
    end

    private

    def get(path, params)
      uri = URI("#{@http_base}#{path}")
      uri.query = URI.encode_www_form(params.merge(apikey: @api_key))
      res = Net::HTTP.get_response(uri)
      raise Error, "Twelve Data #{path} returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      body = JSON.parse(res.body)
      if body.is_a?(Hash) && body['status'] == 'error' && GLOBAL_ERROR_CODES.include?(body['code'])
        raise Error, "Twelve Data: #{body['message']}"
      end

      body
    end
  end
end
