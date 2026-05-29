# Fetches the latest price for each instrument and writes them in a single bulk
# upsert. Returns the number of instruments updated.
class PriceUpdater
  extend Callable
  extend Dry::Initializer

  param :instruments
  option :client, default: -> { MarketData::YahooClient.new }

  def call
    return 0 if instruments.empty?

    by_symbol = instruments.to_h { |i| [i.symbol, i] }
    prices = client.prices(by_symbol.keys)
    now = Time.now
    rows = prices.filter_map do |symbol, price|
      inst = by_symbol[symbol]
      [inst.id, inst.symbol, inst.currency, price, now] if inst
    end
    return 0 if rows.empty?

    DB[:instruments].insert_conflict(
      target: :id,
      update: { last_price: Sequel[:excluded][:last_price], last_price_at: Sequel[:excluded][:last_price_at] }
    ).import(%i[id symbol currency last_price last_price_at], rows)
    rows.size
  end
end
