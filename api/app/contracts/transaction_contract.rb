require 'dry/validation'

class TransactionContract < Dry::Validation::Contract
  params do
    required(:symbol).filled(:string)
    optional(:mic).maybe(:string)
    required(:currency).filled(:string)
    required(:quantity).filled(:decimal)
    required(:price).filled(:decimal)
    required(:executed_at).filled(:time)
  end

  rule(:quantity) do
    key.failure('must be > 0') if value && value <= 0
  end

  rule(:price) do
    key.failure('must be >= 0') if value&.negative?
  end

  rule(:executed_at) do
    key.failure('cannot be in the future') if value && value > Time.now
  end
end
