require 'date'
require 'et-orbi'

# Runs once on scheduler startup to fill snapshots missed while the process was
# down — e.g. a deploy/restart that spanned a whole session. Past weekdays are
# reconstructed from Yahoo history (BackfillService); today is captured from
# current prices once its session has started. No-op (no Yahoo calls) when
# snapshots are already up to date.
class SnapshotCatchup
  extend Callable
  extend Dry::Initializer

  SESSION_START_HOUR = 9 # snapshots run hourly from this hour (Europe/Warsaw)

  option :now, default: -> { EtOrbi.now('Europe/Warsaw') }

  def call
    expected = last_expected_day
    latest = latest_snapshot_date
    return if latest && latest >= expected

    BackfillService.call                          # reconstruct missed past weekdays from history
    SnapshotService.call if expected == today     # today's window already passed
    Rage.logger.info("snapshot catch-up: filled up to #{expected} (latest was #{latest || 'none'})")
  end

  private

  def today = Date.parse(now.strftime('%Y-%m-%d'))

  def latest_snapshot_date
    max = PortfolioSnapshot.max(:date)
    max && Date.parse(max.to_s)
  end

  # Most recent weekday whose session (and thus first snapshot) has started.
  def last_expected_day
    day = now.hour >= SESSION_START_HOUR ? today : today - 1
    day -= 1 while day.saturday? || day.sunday?
    day
  end
end
