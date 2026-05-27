# Fetches the latest price for each instrument and writes them in one transaction.
# Returns the number of instruments updated.
class PriceUpdater
  extend Callable

  def initialize(instruments, client: MarketData::YahooClient.new)
    @instruments = instruments
    @client = client
  end

  def call
    return 0 if @instruments.empty?

    by_symbol = @instruments.to_h { |i| [i.symbol, i] }
    prices = @client.prices(by_symbol.keys)
    now = Time.now
    DB.transaction do
      prices.sum do |symbol, price|
        inst = by_symbol[symbol]
        next 0 unless inst

        inst.update(last_price: price, last_price_at: now)
        1
      end
    end
  end
end
