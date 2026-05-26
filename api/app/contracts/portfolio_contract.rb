require 'dry/validation'

class PortfolioContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    optional(:base_currency).filled(:string)
  end
end
