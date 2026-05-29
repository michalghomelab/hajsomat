require 'date'
require 'bigdecimal'

# Reconstructs daily portfolio snapshots from Yahoo historical closes + FX,
# valuing each day with the transactions in effect on that day.
class BackfillService
  extend Callable
  extend Dry::Initializer

  option :client, default: -> { MarketData.gateway }

  def call
    @instruments = Instrument.all
    @from = earliest_purchase
    return { snapshots_written: 0 } if @instruments.empty? || @from.nil?

    @price_hist = @instruments.to_h { |i| [i.id, Series.new(client.history(i.symbol, from: @from))] }
    @fx_hist = fx_histories
    dates = snapshot_dates

    written = DB.transaction { write_all(dates) }
    { snapshots_written: written }
  end

  private

  def earliest_purchase
    ts = Transaction.min(:executed_at)
    ts && to_date(ts)
  end

  def write_all(dates)
    Portfolio.all.sum do |portfolio|
      txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
      dates.each { |date| write_snapshot(portfolio, date, txns) }
      dates.size
    end
  end

  def fx_histories
    base = AppConfig.config.base_currency
    currencies = @instruments.map(&:currency).uniq.reject { |c| c == base }
    currencies.to_h { |cur| [cur, Series.new(client.history("#{cur}#{base}=X", from: @from))] }
  end

  def snapshot_dates
    @price_hist.values.flat_map(&:dates).uniq.select { |d| d >= @from && d < Date.today }.sort
  end

  def write_snapshot(portfolio, date, txns)
    as_of = txns.select { |t| to_date(t.executed_at) <= date }
    positions = ValuationService.positions(transactions: as_of, instruments_by_id: instruments_on(date),
                                           fx_to_pln: fx_on(date), **AppConfig.valuation_settings)
    PortfolioSnapshot.upsert_snapshot(portfolio.id, date, ValuationService.totals(positions))
  end

  def instruments_on(date)
    @instruments.to_h do |i|
      [i.id, InstrumentPrice.new(symbol: i.symbol, currency: i.currency, name: i.name,
                                 last_price: @price_hist[i.id].on(date), last_price_at: nil)]
    end
  end

  def fx_on(date)
    fx = { AppConfig.config.base_currency => BigDecimal(1) }
    @fx_hist.each { |cur, series| fx[cur] = series.on(date) }
    fx.compact
  end

  def to_date(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end
end
