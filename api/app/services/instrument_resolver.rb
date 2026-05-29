# Finds an existing instrument by symbol, or creates one seeded with a live quote.
class InstrumentResolver
  extend Callable
  extend Dry::Initializer

  option :symbol
  option :mic, default: -> {}
  option :currency, default: -> {}
  option :client, default: -> { MarketData::YahooClient.new }

  def call
    Instrument[symbol: symbol] || create
  end

  private

  def create
    quote = fetch_quote
    Instrument.create(
      symbol: symbol,
      mic: mic,
      name: quote&.dig(:name),
      currency: quote&.dig(:currency) || currency,
      last_price: quote&.dig(:price),
      last_price_at: (Time.now if quote)
    )
  end

  def fetch_quote
    Safely.warn("initial quote for #{symbol}") { client.quote(symbol) }
  end
end
