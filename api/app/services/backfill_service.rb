require 'date'
require 'bigdecimal'

# Reconstructs daily portfolio snapshots from Yahoo historical closes + FX,
# valuing each day with the transactions in effect on that day.
class BackfillService
  def initialize(client: MarketData::YahooClient.new, range: '1y')
    @client = client
    @range = range
  end

  def call
    @instruments = Instrument.all
    return { snapshots_written: 0 } if @instruments.empty?

    @price_hist = @instruments.to_h { |i| [i.id, @client.history(i.symbol, range: @range)] }
    @fx_hist = fx_histories
    dates = snapshot_dates

    written = 0
    Portfolio.all.each do |portfolio|
      txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
      dates.each { |date| write_snapshot(portfolio, date, txns) }
      written += dates.size
    end
    { snapshots_written: written }
  end

  private

  def settings
    @settings ||= { fx_margin: AppConfig.config.fx_margin, base_currency: AppConfig.config.base_currency }
  end

  def fx_histories
    base = AppConfig.config.base_currency
    currencies = @instruments.map(&:currency).uniq.reject { |c| c == base }
    currencies.to_h { |cur| [cur, @client.history("#{cur}#{base}=X", range: @range)] }
  end

  def snapshot_dates
    earliest = Transaction.min(:executed_at)
    return [] unless earliest

    earliest = to_date(earliest)
    @price_hist.values.flat_map(&:keys).uniq.select { |d| d >= earliest && d < Date.today }.sort
  end

  def write_snapshot(portfolio, date, txns)
    as_of = txns.select { |t| to_date(t.executed_at) <= date }
    positions = ValuationService.positions(transactions: as_of, instruments_by_id: instruments_on(date),
                                           fx_to_pln: fx_on(date), **settings)
    upsert(portfolio.id, date, ValuationService.totals(positions))
  end

  def instruments_on(date)
    @instruments.to_h do |i|
      [i.id, { symbol: i.symbol, currency: i.currency, last_price: value_on(@price_hist[i.id], date) }]
    end
  end

  def fx_on(date)
    fx = { settings[:base_currency] => BigDecimal(1) }
    @fx_hist.each { |cur, hist| fx[cur] = value_on(hist, date) }
    fx.compact
  end

  def value_on(hist, date)
    return nil unless hist

    hist[date] || hist.keys.select { |d| d <= date }.max&.then { |d| hist[d] }
  end

  def to_date(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end

  def upsert(portfolio_id, date, totals)
    row = PortfolioSnapshot[portfolio_id: portfolio_id, date: date]
    attrs = { total_value_pln: totals[:market_value_pln], total_cost_pln: totals[:cost_pln],
              pnl_pln: totals[:pnl_pln] }
    row ? row.update(attrs) : PortfolioSnapshot.create(attrs.merge(portfolio_id: portfolio_id, date: date))
  end
end
