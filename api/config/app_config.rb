require 'dry/configurable'

class AppConfig
  extend Dry::Configurable

  setting :database_url, default: ENV.fetch('DATABASE_URL', 'sqlite://db/portfolio.sqlite3')
  setting :base_currency, default: 'PLN'

  setting :market_data do
    setting :base_url, default: 'https://query1.finance.yahoo.com'
  end

  setting :refresh_times, default: %w[09:30 15:35 22:15]
  setting :snapshot_time, default: '22:30'
end
