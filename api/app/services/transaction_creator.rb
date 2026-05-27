# Persists a buy transaction: resolves (or creates) the instrument and stamps
# the historical NBP table-A FX rate for the purchase date.
class TransactionCreator
  extend Callable

  def initialize(portfolio_id:, data:, market_client: MarketData::YahooClient.new,
                 nbp_client: MarketData::NbpClient.new)
    @portfolio_id = portfolio_id
    @data = data
    @market_client = market_client
    @nbp_client = nbp_client
  end

  def call
    instrument = resolve_instrument
    currency = @data[:currency] || instrument.currency
    Transaction.create(
      portfolio_id: @portfolio_id,
      instrument_id: instrument.id,
      kind: 'buy',
      quantity: @data[:quantity],
      price: @data[:price],
      currency: currency,
      executed_at: @data[:executed_at],
      fx_rate: purchase_fx_rate(currency, @data[:executed_at])
    )
  end

  private

  def resolve_instrument
    existing = Instrument[symbol: @data[:symbol]]
    return existing if existing

    instrument = Instrument.new(symbol: @data[:symbol], mic: @data[:mic])
    quote = fetch_quote(instrument.symbol)
    instrument.currency = quote&.dig(:currency) || @data[:currency]
    instrument.last_price = quote&.dig(:price)
    instrument.last_price_at = Time.now if quote
    instrument.save
    instrument
  end

  def fetch_quote(symbol)
    @market_client.quote(symbol)
  rescue StandardError => e
    Rage.logger.warn("initial quote failed for #{symbol}: #{e.message}")
    nil
  end

  # PLN per 1 unit of `currency` at the purchase date (NBP table A); nil on failure.
  def purchase_fx_rate(currency, executed_at)
    @nbp_client.rate(currency, executed_at)
  rescue StandardError => e
    Rage.logger.warn("NBP rate lookup failed for #{currency} @ #{executed_at}: #{e.message}")
    nil
  end
end
