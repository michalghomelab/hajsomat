# Runtime, app-wide settings backed by the DB so the web and scheduler processes
# share them. Distinct from AppConfig (static boot-time config).
module AppSettings
  REFRESH_INTERVAL_KEY = 'refresh_interval_minutes'.freeze
  ALLOWED_REFRESH_INTERVALS = [0, 5, 30, 60].freeze # minutes; 0 = off
  DEFAULT_REFRESH_INTERVAL = 60

  def self.refresh_interval_minutes
    Setting.get(REFRESH_INTERVAL_KEY, DEFAULT_REFRESH_INTERVAL.to_s).to_i
  end

  def self.refresh_interval_minutes=(minutes)
    Setting.put(REFRESH_INTERVAL_KEY, minutes.to_i.to_s)
  end
end
