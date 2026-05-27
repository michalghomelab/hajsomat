require 'sequel'
require_relative '../app_config'

unless defined?(DB)
  DB = Sequel.connect(AppConfig.config.database_url)
  if DB.adapter_scheme == :sqlite
    DB.run('PRAGMA foreign_keys = ON')
    DB.run('PRAGMA journal_mode = WAL')   # allow the web + scheduler processes to share the DB
    DB.run('PRAGMA busy_timeout = 5000')
  end
  Sequel.extension :migration
  migrations_path = File.expand_path('../../db/migrations', __dir__)
  Sequel::Migrator.run(DB, migrations_path) if Dir.exist?(migrations_path)
end
