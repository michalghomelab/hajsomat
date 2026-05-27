class PortfoliosController < RageController::API
  def index
    fx = SnapshotService.fx_to_pln
    instruments_by_id = instruments_map
    payload = Portfolio.all.map do |portfolio|
      totals = ValuationService.totals(positions_for(portfolio, instruments_by_id, fx))
      portfolio_json(portfolio).merge(serialize_totals(totals))
    end
    render json: payload
  end

  def show
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    fx = SnapshotService.fx_to_pln
    txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
    positions = ValuationService.positions(transactions: txns, instruments_by_id: instruments_map, fx_to_pln: fx)
    txns_by_instrument = txns.group_by(&:instrument_id)
    render json: portfolio_json(portfolio).merge(
      totals: serialize_totals(ValuationService.totals(positions)),
      positions: positions.map { |pos|
        position_json(pos).merge(transactions: serialize_transactions(txns_by_instrument[pos.instrument_id]))
      }
    )
  end

  def create
    input = { name: params[:name] }
    input[:base_currency] = params[:base_currency] if params[:base_currency]
    result = PortfolioContract.new.call(input)
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    portfolio = Portfolio.create(result.to_h)
    render json: portfolio_json(portfolio), status: :created
  end

  def update
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    result = PortfolioContract.new.call(name: params[:name])
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    portfolio.update(name: result[:name])
    render json: portfolio_json(portfolio)
  end

  def snapshots
    rows = PortfolioSnapshot.where(portfolio_id: params[:id].to_i).order(:date).all
    render json: rows.map { |s|
      { date: s.date.to_s, total_value_pln: decimal_string(s.total_value_pln),
        total_cost_pln: decimal_string(s.total_cost_pln), pnl_pln: decimal_string(s.pnl_pln) }
    }
  end

  private

  def instruments_map
    Instrument.all.to_h { |i| [i.id, { symbol: i.symbol, currency: i.currency, last_price: i.last_price }] }
  end

  def positions_for(portfolio, instruments_by_id, fx_rates)
    txns = Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
    ValuationService.positions(transactions: txns, instruments_by_id: instruments_by_id, fx_to_pln: fx_rates)
  end

  def portfolio_json(portfolio)
    { id: portfolio.id, name: portfolio.name, base_currency: portfolio.base_currency }
  end

  def position_json(pos)
    pos.to_h.transform_values { |v| decimal_string(v) }
  end

  def serialize_transactions(txns)
    (txns || []).sort_by(&:executed_at).map do |t|
      { id: t.id, quantity: decimal_string(t.quantity), price: decimal_string(t.price),
        currency: t.currency, executed_at: t.executed_at.iso8601 }
    end
  end

  def serialize_totals(totals)
    {
      market_value_pln: decimal_string(totals[:market_value_pln]),
      cost_pln: decimal_string(totals[:cost_pln]),
      pnl_pln: decimal_string(totals[:pnl_pln]),
      incomplete: totals[:incomplete]
    }
  end

  # Plain decimal notation ("6000.0"), not BigDecimal's default engineering form ("0.6e4").
  def decimal_string(value)
    value.is_a?(BigDecimal) ? value.to_s('F') : value
  end
end
