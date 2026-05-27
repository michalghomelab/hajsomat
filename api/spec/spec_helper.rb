ENV['RAGE_ENV'] = 'test'
ENV['DATABASE_URL'] = 'sqlite::memory:'

require 'fileutils'
require 'webmock/rspec'
require 'sequel'
require 'bigdecimal'

FileUtils.mkdir_p(File.expand_path('../log', __dir__))

# Establish the in-memory DB and migrate BEFORE booting the app, so the guarded
# db initializer reuses this connection and Sequel models load against it.
DB = Sequel.connect(ENV.fetch('DATABASE_URL', nil))
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))

# Boot the Rage app so its Zeitwerk loader autoloads everything under app/.
require_relative '../config/application'

RSpec.configure do |config|
  config.around do |example|
    DB.transaction(rollback: :always) { example.run }
  end
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
