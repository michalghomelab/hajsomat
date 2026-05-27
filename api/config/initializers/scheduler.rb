require 'rufus-scheduler'
require_relative '../app_config'

unless defined?(RSpec) || ENV['RAGE_ENV'] == 'test'
  SCHEDULER = Rufus::Scheduler.new

  SCHEDULER.cron(AppConfig.config.refresh_cron) do
    RefreshService.call
  rescue StandardError => e
    Rage.logger.error("scheduled refresh failed: #{e.message}")
  end

  SCHEDULER.cron(AppConfig.config.snapshot_cron) do
    SnapshotService.call
  rescue StandardError => e
    Rage.logger.error("scheduled snapshot failed: #{e.message}")
  end
end
