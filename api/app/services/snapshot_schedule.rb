require 'fugit'

# Next scheduled daily-snapshot time, parsed from the same cron rufus uses
# (AppConfig.snapshot_cron), so the UI countdown always matches the scheduler.
module SnapshotSchedule
  module_function

  def next_at
    Fugit.parse_cron(AppConfig.config.snapshot_cron).next_time.to_t
  end
end
