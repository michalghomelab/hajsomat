require 'fugit'

# Next scheduled times, parsed from the same crons rufus uses (AppConfig), so
# the UI countdowns always match the scheduler.
module Schedule
  module_function

  def next_refresh_at = next_at(AppConfig.config.refresh_cron)
  def next_snapshot_at = next_at(AppConfig.config.snapshot_cron)

  def next_at(cron) = Fugit.parse_cron(cron).next_time.to_t
end
