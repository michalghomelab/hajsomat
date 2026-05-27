require 'fugit'

# Next scheduled times, parsed from the same crons rufus uses (AppConfig), so
# the UI countdowns always match the scheduler.
module Schedule
  module_function

  def next_refresh_at = next_at(AppConfig.config.refresh_cron)
  def next_snapshot_at = next_at(AppConfig.config.snapshot_cron)

  def next_at(cron) = Fugit.parse_cron(cron).next_time.to_t

  # Whether we're inside the refresh window (the cron's active weekdays/hours,
  # in its own timezone) — i.e. the market session prices update during.
  def market_open?
    cron = Fugit.parse_cron(AppConfig.config.refresh_cron)
    now = EtOrbi.now(cron.zone)
    (cron.hours.nil? || cron.hours.include?(now.hour)) &&
      (cron.weekdays.nil? || cron.weekdays.flatten.include?(now.wday))
  end
end
