require 'net/http'
require 'json'
require 'bigdecimal'
require 'date'
require 'uri'

module MarketData
  # Fetches historical PLN reference rates (NBP table A). Used to value a purchase
  # in PLN at the FX rate from its actual purchase date.
  class NbpClient
    class Error < StandardError; end

    MAX_LOOKBACK = 7 # step back over weekends/holidays with no published table

    def initialize(http_base: 'https://api.nbp.pl')
      @http_base = http_base
    end

    # PLN per 1 unit of `code` (e.g. "EUR") on `date`. PLN -> 1.
    def rate(code, date)
      return BigDecimal(1) if code.to_s.upcase == 'PLN'

      day = date.is_a?(Date) ? date : Date.parse(date.to_s)
      MAX_LOOKBACK.times do
        mid = fetch(code, day)
        return mid if mid

        day -= 1
      end
      raise Error, "No NBP rate for #{code} near #{date}"
    end

    private

    def fetch(code, day)
      uri = URI("#{@http_base}/api/exchangerates/rates/a/#{code.downcase}/#{day.strftime('%Y-%m-%d')}/?format=json")
      res = Net::HTTP.get_response(uri)
      return nil if res.code == '404'
      raise Error, "NBP #{code} returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      mid = JSON.parse(res.body).dig('rates', 0, 'mid')
      mid && BigDecimal(mid.to_s)
    end
  end
end
