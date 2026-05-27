# PLN per 1 unit of `currency` at the purchase date (NBP table A); nil on failure.
class PurchaseFxRate
  extend Callable

  def initialize(currency, date, client: MarketData::NbpClient.new)
    @currency = currency
    @date = date
    @client = client
  end

  def call
    @client.rate(@currency, @date)
  rescue StandardError => e
    Rage.logger.warn("NBP rate lookup failed for #{@currency} @ #{@date}: #{e.message}")
    nil
  end
end
