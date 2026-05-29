require 'dry/monads'

# Validates and creates a buy transaction: resolves the instrument and stamps the
# historical NBP table-A FX rate for the purchase date. Success({ id: }) or
# Failure([422, errors]).
class TransactionCreator
  extend Callable
  extend Dry::Initializer
  include Dry::Monads[:result]

  option :portfolio_id
  option :params

  def call
    result = TransactionContract.new.call(attrs)
    return Failure([422, { errors: result.errors.to_h }]) if result.failure?

    Success({ id: create(result.to_h).id })
  end

  private

  def attrs
    { symbol: params[:symbol], mic: params[:mic], currency: params[:currency],
      quantity: params[:quantity], price: params[:price], executed_at: params[:executed_at] }
  end

  def create(data)
    instrument = InstrumentResolver.call(symbol: data[:symbol], mic: data[:mic], currency: data[:currency])
    currency = data[:currency] || instrument.currency
    Transaction.create(
      portfolio_id: portfolio_id, instrument_id: instrument.id, kind: 'buy',
      quantity: data[:quantity], price: data[:price], currency: currency,
      executed_at: data[:executed_at], fx_rate: PurchaseFxRate.call(currency, data[:executed_at])
    )
  end
end
