require "sequel"

DB = Sequel.connect(ENV.fetch("DATABASE_URL", "sqlite://db/portfolio.sqlite3"))
DB.run("PRAGMA foreign_keys = ON") if DB.adapter_scheme == :sqlite

Sequel.extension :migration
migrations_path = File.expand_path("../../db/migrations", __dir__)
Sequel::Migrator.run(DB, migrations_path) if Dir.exist?(migrations_path)
