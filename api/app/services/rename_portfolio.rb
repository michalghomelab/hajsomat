require 'dry/monads'

# Renames a portfolio. Success(presented), Failure([:not_found, …]) or
# Failure([422, errors]).
class RenamePortfolio
  extend Callable
  extend Dry::Initializer
  include Dry::Monads[:result]

  option :id
  option :name

  def call
    portfolio = Portfolio[id.to_i]
    return Failure([:not_found, { error: 'not found' }]) unless portfolio

    result = PortfolioContract.new.call(name: name)
    return Failure([422, { errors: result.errors.to_h }]) if result.failure?

    portfolio.update(name: result[:name])
    Success(PortfolioPresenter.call(portfolio, positions: [], price_map: {}))
  end
end
