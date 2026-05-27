class TransactionsController < RageController::API
  def create
    result = TransactionContract.new.call(transaction_params)
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    data = result.to_h
    instrument = resolve_instrument(data)
    currency = data[:currency] || instrument.currency
    txn = Transaction.create(
      portfolio_id: params[:id].to_i,
      instrument_id: instrument.id,
      kind: 'buy',
      quantity: data[:quantity],
      price: data[:price],
      currency: currency,
      executed_at: data[:executed_at],
      fx_rate: purchase_fx_rate(currency, data[:executed_at])
    )
    render json: { id: txn.id }, status: :created
  end

  def destroy
    txn = Transaction[params[:id].to_i]
    return render json: {}, status: :not_found unless txn

    txn.destroy
    head :no_content
  end

  private

  def transaction_params
    { symbol: params[:symbol], mic: params[:mic], currency: params[:currency],
      quantity: params[:quantity], price: params[:price], executed_at: params[:executed_at] }
  end

  def resolve_instrument(data)
    existing = Instrument[symbol: data[:symbol]]
    return existing if existing

    instrument = Instrument.new(symbol: data[:symbol], mic: data[:mic])
    q = fetch_quote(instrument.symbol)
    instrument.currency = q&.dig(:currency) || data[:currency]
    instrument.last_price = q&.dig(:price)
    instrument.last_price_at = Time.now if q
    instrument.save
    instrument
  end

  def fetch_quote(symbol)
    MarketData::YahooClient.new.quote(symbol)
  rescue StandardError => e
    Rage.logger.warn("initial quote failed for #{symbol}: #{e.message}")
    nil
  end

  # PLN per 1 unit of `currency` at the purchase date (NBP table A); nil on failure.
  def purchase_fx_rate(currency, executed_at)
    MarketData::NbpClient.new.rate(currency, executed_at)
  rescue StandardError => e
    Rage.logger.warn("NBP rate lookup failed for #{currency} @ #{executed_at}: #{e.message}")
    nil
  end
end
