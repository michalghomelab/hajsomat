require 'market_data/twelve_data_client'

class RefreshService
  def initialize(client: MarketData::TwelveDataClient.new)
    @client = client
  end

  def call
    instruments = instruments_in_use
    instruments_updated = update_prices(instruments)
    fx_updated = update_fx(instruments)
    { instruments_updated: instruments_updated, fx_updated: fx_updated }
  end

  private

  def instruments_in_use
    ids = Transaction.distinct.select_map(:instrument_id)
    Instrument.where(id: ids).all
  end

  def update_prices(instruments)
    return 0 if instruments.empty?

    by_td = instruments.to_h { |i| [i.td_symbol, i] }
    prices = @client.prices(by_td.keys)
    updated = 0
    prices.each do |td_symbol, price|
      inst = by_td[td_symbol]
      next unless inst

      inst.update(last_price: price, last_price_at: Time.now)
      updated += 1
    end
    updated
  end

  def update_fx(instruments)
    currencies = instruments.map(&:currency).uniq.reject { |c| c == base_currency }
    currencies.each do |cur|
      rate = @client.fx_rate(cur, base_currency)
      FxRate.upsert_rate(cur, base_currency, rate)
    end
    currencies.size
  end

  def base_currency
    AppConfig.config.base_currency
  end
end
