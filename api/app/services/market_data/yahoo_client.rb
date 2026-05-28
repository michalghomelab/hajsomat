require 'net/http'
require 'json'
require 'bigdecimal'
require 'uri'

module MarketData
  class YahooClient
    class Error < StandardError; end

    def initialize(http_base: AppConfig.config.market_data.base_url)
      @http_base = http_base
    end

    # symbol -> { price: BigDecimal, currency: String } ; nil if not found
    def quote(symbol)
      body = get("/v8/finance/chart/#{URI.encode_www_form_component(symbol)}", interval: '1d', range: '1d')
      meta = body&.dig('chart', 'result', 0, 'meta')
      return nil unless meta && meta['regularMarketPrice']

      { price: BigDecimal(meta['regularMarketPrice'].to_s), currency: meta['currency'],
        name: meta['longName'] || meta['shortName'] }
    end

    # array of symbols -> { symbol => BigDecimal } ; unknown symbols omitted
    def prices(symbols)
      symbols.each_with_object({}) do |sym, acc|
        q = quote(sym)
        acc[sym] = q[:price] if q
      rescue Error => e
        # Skip a throttled/failed symbol so one bad quote doesn't abort the whole refresh.
        Rage.logger.warn("price fetch failed for #{sym}: #{e.message}") if defined?(Rage)
      end
    end

    def fx_rate(base, quote_currency)
      q = quote("#{base}#{quote_currency}=X")
      raise Error, "Yahoo: no FX rate for #{base}/#{quote_currency}" unless q

      q[:price]
    end

    # symbol -> { Date => BigDecimal(close) } daily history over the given range
    def history(symbol, from: nil, range: '1y')
      body = get("/v8/finance/chart/#{URI.encode_www_form_component(symbol)}", history_params(from, range))
      result = body&.dig('chart', 'result', 0)
      return {} unless result

      timestamps = Array(result['timestamp'])
      closes = Array(result.dig('indicators', 'quote', 0, 'close'))
      timestamps.zip(closes).each_with_object({}) do |(ts, close), acc|
        t = Time.at(ts).utc
        acc[Date.new(t.year, t.month, t.day)] = BigDecimal(close.to_s) if close
      end
    end

    def symbol_search(query)
      body = get('/v1/finance/search', q: query, quotesCount: 10, newsCount: 0)
      Array(body['quotes']).map do |row|
        { symbol: row['symbol'], name: row['shortname'] || row['longname'],
          exchange: row['exchange'], currency: row['currency'], mic: nil }
      end
    end

    private

    # Yahoo chart accepts either an explicit period1/period2 window (unix seconds)
    # or a relative `range` string. Prefer the window when a start date is given.
    def history_params(from, range)
      return { interval: '1d', range: range } unless from

      { interval: '1d', period1: from.to_time.to_i, period2: (Time.now + 86_400).to_i }
    end

    def get(path, params)
      uri = URI("#{@http_base}#{path}")
      uri.query = URI.encode_www_form(params)
      res = perform(uri)
      if res.code == '429' # transient rate limit — back off once and retry
        sleep 1
        res = perform(uri)
      end
      return nil if res.code == '404'
      raise Error, "Yahoo #{path} returned HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def perform(uri)
      req = Net::HTTP::Get.new(uri)
      req['User-Agent'] = 'Mozilla/5.0'
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    end
  end
end
