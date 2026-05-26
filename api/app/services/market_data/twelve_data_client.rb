require "net/http"
require "json"
require "bigdecimal"
require "uri"

module MarketData
  class TwelveDataClient
    def initialize(api_key: ENV.fetch("TWELVE_DATA_API_KEY"), http_base: "https://api.twelvedata.com")
      @api_key = api_key
      @http_base = http_base
    end

    def prices(symbols)
      return {} if symbols.empty?
      body = get("/price", symbol: symbols.join(","))
      result = {}
      if symbols.size == 1
        sym = symbols.first
        result[sym] = BigDecimal(body["price"]) if body["price"]
      else
        symbols.each do |sym|
          node = body[sym]
          result[sym] = BigDecimal(node["price"]) if node.is_a?(Hash) && node["price"]
        end
      end
      result
    end

    def fx_rate(base, quote)
      body = get("/exchange_rate", symbol: "#{base}/#{quote}")
      BigDecimal(body.fetch("rate").to_s)
    end

    private

    def get(path, params)
      uri = URI("#{@http_base}#{path}")
      uri.query = URI.encode_www_form(params.merge(apikey: @api_key))
      res = Net::HTTP.get_response(uri)
      JSON.parse(res.body)
    end
  end
end
