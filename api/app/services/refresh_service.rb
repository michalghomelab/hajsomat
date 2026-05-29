# Orchestrates a market-data refresh for instruments in use: prices, FX rates,
# and a one-off fill of any missing instrument names.
class RefreshService
  extend Callable
  extend Dry::Initializer

  option :client, default: -> { MarketData.gateway }

  def call
    instruments = Instrument.in_use.all
    {
      instruments_updated: PriceUpdater.call(instruments, client: client),
      fx_updated: FxRateUpdater.call(instruments, client: client),
      names_filled: InstrumentNameBackfiller.call(instruments, client: client)
    }
  end
end
