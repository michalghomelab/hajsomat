require 'fugit'

# Next scheduled times, parsed from the same crons rufus uses (AppConfig), so
# the UI countdowns always match the scheduler.
module Schedule
  module_function

  def next_snapshot_at = next_at(AppConfig.config.snapshot_cron)

  def next_at(cron) = Fugit.parse_cron(cron).next_time.to_t

  # Next price refresh, derived from the app-wide interval setting: last refresh
  # (max last_price_at) + interval while the session is open; the next session
  # open otherwise; nil when auto-refresh is off.
  def next_refresh_at
    minutes = AppSettings.refresh_interval_minutes
    return nil if minutes.zero?
    return next_at(AppConfig.config.refresh_cron) unless market_open?

    candidate = (last_price_refresh_at || Time.now) + (minutes * 60)
    [candidate, Time.now].max
  end

  # Time of the most recent price update (typecast via the model, since a dataset
  # aggregate would hand back a raw string), or nil if nothing's priced yet.
  def last_price_refresh_at
    Instrument.exclude(last_price_at: nil).order(Sequel.desc(:last_price_at)).first&.last_price_at
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
