class TransactionsController < RageController::API
  def create
    result = TransactionContract.new.call(transaction_params)
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    data = result.to_h
    instrument = resolve_instrument(data)
    txn = Transaction.create(
      portfolio_id: params[:id].to_i,
      instrument_id: instrument.id,
      kind: 'buy',
      quantity: data[:quantity],
      price: data[:price],
      currency: data[:currency],
      executed_at: data[:executed_at]
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
    mic = data[:mic].to_s.empty? ? nil : data[:mic]
    existing = Instrument[symbol: data[:symbol], mic: mic]
    return existing if existing

    instrument = Instrument.create(symbol: data[:symbol], mic: mic, currency: data[:currency])
    fetch_initial_price(instrument)
    instrument
  end

  def fetch_initial_price(instrument)
    price = MarketData::TwelveDataClient.new.prices([instrument.td_symbol])[instrument.td_symbol]
    instrument.update(last_price: price, last_price_at: Time.now) if price
  rescue StandardError => e
    Rage.logger.warn("initial price fetch failed for #{instrument.td_symbol}: #{e.message}")
  end
end
