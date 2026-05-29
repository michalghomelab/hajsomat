# Runtime, app-wide settings backed by the DB so the web and scheduler processes
# share them. Distinct from AppConfig (static boot-time config).
module AppSettings
  REFRESH_INTERVAL_KEY = 'refresh_interval_minutes'.freeze
  ALLOWED_REFRESH_INTERVALS = [5, 30, 60].freeze # minutes — auto-refresh can't be turned off
  DEFAULT_REFRESH_INTERVAL = 60

  # Falls back to the default for any out-of-range value (incl. a legacy 0/"off"
  # that may still be in the DB), so auto-refresh is never disabled.
  def self.refresh_interval_minutes
    value = Setting.get(REFRESH_INTERVAL_KEY, DEFAULT_REFRESH_INTERVAL.to_s).to_i
    ALLOWED_REFRESH_INTERVALS.include?(value) ? value : DEFAULT_REFRESH_INTERVAL
  end

  def self.refresh_interval_minutes=(minutes)
    Setting.put(REFRESH_INTERVAL_KEY, minutes.to_i.to_s)
  end
end
