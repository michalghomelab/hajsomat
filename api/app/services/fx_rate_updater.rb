# Refreshes the FX rate to the base currency for every currency the given
# instruments use. A single currency's failure is logged and skipped.
# Returns the number of currencies successfully updated.
class FxRateUpdater
  extend Callable
  extend Dry::Initializer

  param :instruments
  option :client, default: -> { MarketData.gateway }
  option :base_currency, default: -> { AppConfig.config.base_currency }

  def call
    currencies.count { |currency| update_one(currency) }
  end

  private

  def currencies
    instruments.map(&:currency).uniq.reject { |c| c == base_currency }
  end

  def update_one(currency)
    Safely.warn("FX update for #{currency}/#{base_currency}") do
      FxRate.upsert_rate(currency, base_currency, client.fx_rate(currency, base_currency))
      true
    end
  end
end
