require 'sequel'
require_relative '../app_config'

unless defined?(DB)
  DB = Sequel.connect(AppConfig.config.database_url)
  DB.run('PRAGMA foreign_keys = ON') if DB.adapter_scheme == :sqlite
  Sequel.extension :migration
  migrations_path = File.expand_path('../../db/migrations', __dir__)
  Sequel::Migrator.run(DB, migrations_path) if Dir.exist?(migrations_path)
end
