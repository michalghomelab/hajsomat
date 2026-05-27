require 'fugit'

# Next scheduled times, parsed from the same crons rufus uses (AppConfig), so
# the UI countdowns always match the scheduler.
module Schedule
  module_function

  def next_refresh_at = next_at(AppConfig.config.refresh_cron)
  def next_snapshot_at = next_at(AppConfig.config.snapshot_cron)

  def next_at(cron) = Fugit.parse_cron(cron).next_time.to_t

  # Whether we're inside the refresh window (the cron's active weekdays/hours,
  # in its own timezone) — i.e. the market session prices update during. The
  # last hour counts as open only at :00 (its final tick), since the markets
  # close then and no later refresh fires.
  def market_open?
    cron = Fugit.parse_cron(AppConfig.config.refresh_cron)
    now = EtOrbi.now(cron.zone)
    return false if cron.weekdays && !cron.weekdays.flatten.include?(now.wday)
    return true if cron.hours.nil?

    min_h, max_h = cron.hours.minmax
    now.hour >= min_h && (now.hour < max_h || (now.hour == max_h && now.min.zero?))
  end
end
