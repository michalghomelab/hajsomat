require 'date'
require 'et-orbi'

# Runs once on scheduler startup to fill snapshots missed while the process was
# down — e.g. a deploy/restart straddling the nightly 22:30 window. Past weekdays
# are reconstructed from Yahoo history (BackfillService); today is captured from
# current prices only once its 22:30 window has passed. No-op (no Yahoo calls)
# when snapshots are already up to date.
class SnapshotCatchup
  extend Callable

  SNAPSHOT_HOUR = 22
  SNAPSHOT_MIN = 30

  def initialize(now: EtOrbi.now('Europe/Warsaw'))
    @now = now
  end

  def call
    expected = last_expected_day
    latest = latest_snapshot_date
    return if latest && latest >= expected

    BackfillService.call                          # reconstruct missed past weekdays from history
    SnapshotService.call if expected == today     # today's window already passed
    Rage.logger.info("snapshot catch-up: filled up to #{expected} (latest was #{latest || 'none'})")
  end

  private

  def today = Date.parse(@now.strftime('%Y-%m-%d'))

  def latest_snapshot_date
    max = PortfolioSnapshot.max(:date)
    max && Date.parse(max.to_s)
  end

  # Most recent weekday whose 22:30 snapshot window has already passed.
  def last_expected_day
    day = past_snapshot_time? ? today : today - 1
    day -= 1 while day.saturday? || day.sunday?
    day
  end

  def past_snapshot_time?
    @now.hour > SNAPSHOT_HOUR || (@now.hour == SNAPSHOT_HOUR && @now.min >= SNAPSHOT_MIN)
  end
end
