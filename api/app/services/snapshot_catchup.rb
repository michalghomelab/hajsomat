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
    expected = last_expected_day
    latest = latest_snapshot_date
    return if latest && latest >= expected

    BackfillService.call
    SnapshotService.call if expected == today
    Rage.logger.info("snapshot catch-up: filled up to #{expected} (latest was #{latest || 'none'})")
  end

  private

  def today = Date.parse(now.strftime('%Y-%m-%d'))

  def latest_snapshot_date
    max = PortfolioSnapshot.max(:date)
    max && Date.parse(max.to_s)
  end

  def last_expected_day = today
end
