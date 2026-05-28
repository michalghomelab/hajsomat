require 'dry/configurable'

class AppConfig
  extend Dry::Configurable

  setting :database_url, default: ENV.fetch('DATABASE_URL', 'sqlite://db/portfolio.sqlite3')
  setting :base_currency, default: 'PLN'
  # Broker FX spread applied to foreign-currency conversions (0.005 = 0.5%).
  setting :fx_margin, default: '0.005'

  setting :market_data do
    setting :base_url, default: 'https://query1.finance.yahoo.com'
  end

  # rufus cron (min hour day month weekday tz). Hourly on weekdays during market
  # hours (GPW/Xetra/US session window); daily snapshot after US close.
  setting :refresh_cron, default: '0 9-22 * * 1-5 Europe/Warsaw'
  setting :snapshot_cron, default: '30 22 * * 1-5 Europe/Warsaw'

  # Where the scheduler reaches the web process to push WS notifications
  # (dev: the api service; prod: same container on localhost).
  setting :internal_base_url, default: ENV.fetch('INTERNAL_BASE_URL', 'http://localhost:3000')

  def self.valuation_settings
    { fx_margin: config.fx_margin, base_currency: config.base_currency }
  end
end
