require 'forwardable'

module MarketData
  # The single seam between the app and a market-data provider. Services depend
  # on the Gateway (not a concrete client), so swapping or adding a provider is a
  # config + registry change — see MarketData::PROVIDERS.
  class Gateway
    extend Dry::Initializer
    extend Forwardable

    option :provider, default: -> { MarketData.provider }

    def_delegators :provider, :quote, :prices, :fx_rate, :history, :symbol_search
  end
end
