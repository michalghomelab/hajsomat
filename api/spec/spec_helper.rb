ENV['DATABASE_URL'] = 'sqlite::memory:'
require 'webmock/rspec'
require 'sequel'
require 'bigdecimal'

DB = Sequel.connect(ENV.fetch('DATABASE_URL', nil))
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))
$LOAD_PATH.unshift File.expand_path('../app/contracts', __dir__)
$LOAD_PATH.unshift File.expand_path('../app/models', __dir__)
$LOAD_PATH.unshift File.expand_path('../app/services', __dir__)

RSpec.configure do |config|
  config.around do |example|
    DB.transaction(rollback: :always) { example.run }
  end
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
