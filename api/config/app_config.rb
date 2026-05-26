require 'dry/configurable'

class AppConfig
  extend Dry::Configurable

  setting :database_url, default: ENV.fetch('DATABASE_URL', 'sqlite://db/portfolio.sqlite3')
  setting :base_currency, default: 'PLN'

  setting :twelve_data do
    setting :api_key, default: ENV.fetch('TWELVE_DATA_API_KEY', nil)
    setting :base_url, default: 'https://api.twelvedata.com'
  end

  setting :refresh_times, default: %w[09:30 15:35 22:15]
  setting :snapshot_time, default: '22:30'
end
