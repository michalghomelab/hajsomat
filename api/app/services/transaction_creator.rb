# Orchestrates creating a buy transaction: resolves the instrument and stamps
# the historical NBP table-A FX rate for the purchase date.
class TransactionCreator
  extend Callable
  extend Dry::Initializer

  option :portfolio_id
  option :data

  def call
    instrument = InstrumentResolver.call(symbol: data[:symbol], mic: data[:mic], currency: data[:currency])
    currency = data[:currency] || instrument.currency
    Transaction.create(
      portfolio_id: portfolio_id,
      instrument_id: instrument.id,
      kind: 'buy',
      quantity: data[:quantity],
      price: data[:price],
      currency: currency,
      executed_at: data[:executed_at],
      fx_rate: PurchaseFxRate.call(currency, data[:executed_at])
    )
  end
end
