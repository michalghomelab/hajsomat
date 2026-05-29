require 'fugit'

# Next scheduled times, parsed from the same crons rufus uses (AppConfig), so
# the UI countdowns always match the scheduler.
module Schedule
  module_function

  def next_at(cron) = Fugit.parse_cron(cron).next_time.to_t

  # Clock-aligned refresh cron derived from the app-wide interval: the minute
  # field of the session-window cron is swapped for the interval (e.g. */5,
  # */30, or 0 for hourly). nil when auto-refresh is off.
  def refresh_cron
    minutes = AppSettings.refresh_interval_minutes
    return nil if minutes.zero?

    fields = AppConfig.config.refresh_cron.split
    fields[0] = minutes >= 60 ? '0' : "*/#{minutes}"
    fields.join(' ')
  end

  # Next price refresh = next tick of that cron (already respects the session
  # window/timezone). nil when auto-refresh is off.
  def next_refresh_at
    cron = refresh_cron
    cron && next_at(cron)
  end

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
