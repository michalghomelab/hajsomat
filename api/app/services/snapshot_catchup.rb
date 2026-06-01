require 'date'
require 'et-orbi'

# Runs once on scheduler startup to fill snapshots missed while the process was
# down. Past calendar days are reconstructed from Yahoo history, carrying the
# last observed prices forward over weekends/holidays (BackfillService); today
# is captured from current prices. No-op when snapshots are already up to date.
class SnapshotCatchup
  extend Callable
  extend Dry::Initializer

  option :now, default: -> { EtOrbi.now('Europe/Warsaw') }

  def call
    return if portfolio_ids.empty?

    historical_missing = snapshots_missing?(historical_dates)
    today_missing = snapshots_missing?([today])
    return unless historical_missing || today_missing

    BackfillService.call if historical_missing
    SnapshotService.call if today_missing
    Rage.logger.info("snapshot catch-up: filled missing snapshots through #{today}")
  end

  private

  def today = Date.parse(now.strftime('%Y-%m-%d'))

  def portfolio_ids
    @portfolio_ids ||= Portfolio.select_map(:id)
  end

  def historical_dates
    return [] unless first_snapshot_day

    (first_snapshot_day...today).to_a
  end

  def first_snapshot_day
    ts = Transaction.min(:executed_at)
    ts && Date.parse(ts.to_s)
  end

  def snapshots_missing?(dates)
    return false if dates.empty?

    expected = portfolio_ids.size * dates.size
    actual = PortfolioSnapshot.where(portfolio_id: portfolio_ids, date: dates).count
    actual < expected
  end
end
