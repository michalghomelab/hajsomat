# Finds an existing instrument by symbol, or creates one seeded with a live quote.
class InstrumentResolver
  extend Callable

  def initialize(symbol:, mic: nil, currency: nil, client: MarketData::YahooClient.new)
    @symbol = symbol
    @mic = mic
    @currency = currency
    @client = client
  end

  def call
    Instrument[symbol: @symbol] || create
  end

  private

  def create
    quote = fetch_quote
    Instrument.create(
      symbol: @symbol,
      mic: @mic,
      currency: quote&.dig(:currency) || @currency,
      last_price: quote&.dig(:price),
      last_price_at: (Time.now if quote)
    )
  end

  def fetch_quote
    @client.quote(@symbol)
  rescue StandardError => e
    Rage.logger.warn("initial quote failed for #{@symbol}: #{e.message}")
    nil
  end
end
