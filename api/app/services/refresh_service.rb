class RefreshService
  extend Callable

  def initialize(client: MarketData::YahooClient.new)
    @client = client
  end

  def call
    instruments = instruments_in_use
    instruments_updated = update_prices(instruments)
    fx_updated = update_fx(instruments)
    { instruments_updated: instruments_updated, fx_updated: fx_updated }
  end

  private

  def instruments_in_use = Instrument.where(id: Transaction.distinct.select(:instrument_id)).all

  def update_prices(instruments)
    return 0 if instruments.empty?

    by_symbol = instruments.to_h { |i| [i.symbol, i] }
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

  def update_fx(instruments)
    currencies = instruments.map(&:currency).uniq.reject { |c| c == base_currency }
    currencies.count { |cur| update_one_fx(cur) }
  end

  def update_one_fx(currency)
    rate = @client.fx_rate(currency, base_currency)
    FxRate.upsert_rate(currency, base_currency, rate)
    true
  rescue StandardError => e
    Rage.logger.warn("FX update failed for #{currency}/#{base_currency}: #{e.message}")
    false
  end

  def base_currency
    AppConfig.config.base_currency
  end
end
