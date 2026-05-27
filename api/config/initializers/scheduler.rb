require 'rufus-scheduler'
require_relative '../app_config'

unless defined?(RSpec) || ENV['RAGE_ENV'] == 'test'
  SCHEDULER = Rufus::Scheduler.new

  AppConfig.config.refresh_times.each do |hhmm|
    hour, minute = hhmm.split(':')
    SCHEDULER.cron("#{minute} #{hour} * * * Europe/Warsaw") do
      RefreshService.new.call
    rescue StandardError => e
      Rage.logger.error("scheduled refresh failed: #{e.message}")
    end
  end

  snapshot_hour, snapshot_minute = AppConfig.config.snapshot_time.split(':')
  SCHEDULER.cron("#{snapshot_minute} #{snapshot_hour} * * * Europe/Warsaw") do
    SnapshotService.new.call
  rescue StandardError => e
    Rage.logger.error("scheduled snapshot failed: #{e.message}")
  end
end
