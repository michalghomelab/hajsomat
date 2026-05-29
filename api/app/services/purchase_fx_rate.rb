# PLN per 1 unit of `currency` at the purchase date (NBP table A); nil on failure.
class PurchaseFxRate
  extend Callable
  extend Dry::Initializer

  param :currency
  param :date
  option :client, default: -> { MarketData::NbpClient.new }

  def call
    Safely.warn("NBP rate lookup for #{currency} @ #{date}") { client.rate(currency, date) }
  end
end
