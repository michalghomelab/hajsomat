# Namespace for external market-data providers and the Gateway the app talks to.
module MarketData
  # Registered providers. To add one, implement the Gateway's methods
  # (quote / prices / fx_rate / history / symbol_search) in a new client and add
  # it here, then point AppConfig.market_data.provider at its key.
  PROVIDERS = {
    'yahoo' => -> { YahooClient.new }
  }.freeze

  def self.gateway
    Gateway.new
  end

  def self.provider
    PROVIDERS.fetch(AppConfig.config.market_data.provider.to_s) { PROVIDERS.fetch('yahoo') }.call
  end
end
