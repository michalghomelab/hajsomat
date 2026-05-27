# Refreshes the FX rate to the base currency for every currency the given
# instruments use. A single currency's failure is logged and skipped.
# Returns the number of currencies successfully updated.
class FxRateUpdater
  extend Callable

  def initialize(instruments, client: MarketData::YahooClient.new,
                 base_currency: AppConfig.config.base_currency)
    @instruments = instruments
    @client = client
    @base_currency = base_currency
  end

  def call
    currencies.count { |currency| update_one(currency) }
  end

  private

  def currencies
    @instruments.map(&:currency).uniq.reject { |c| c == @base_currency }
  end

  def update_one(currency)
    rate = @client.fx_rate(currency, @base_currency)
    FxRate.upsert_rate(currency, @base_currency, rate)
    true
  rescue StandardError => e
    Rage.logger.warn("FX update failed for #{currency}/#{@base_currency}: #{e.message}")
    false
  end
end
