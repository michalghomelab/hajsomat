require 'dry/monads'

# Validates and creates a portfolio. Success(presented) or Failure([422, errors]).
class CreatePortfolio
  extend Callable
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :params

  def call
    result = PortfolioContract.new.call(attrs)
    return Failure([422, { errors: result.errors.to_h }]) if result.failure?

    portfolio = Portfolio.create(result.to_h)
    Success(PortfolioPresenter.call(portfolio, positions: [], price_map: {}))
  end

  private

  def attrs
    attrs = { name: params[:name] }
    attrs[:base_currency] = params[:base_currency] if params[:base_currency]
    attrs
  end
end
