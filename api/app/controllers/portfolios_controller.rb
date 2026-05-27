class PortfoliosController < RageController::API
  def index
    fx = SnapshotService.fx_to_pln
    instruments_by_id = instruments_map
    payload = Portfolio.all.map do |portfolio|
      totals = ValuationService.totals(positions_for(portfolio, instruments_by_id, fx))
      portfolio_json(portfolio).merge(totals.transform_values(&:to_s))
    end
    render json: payload
  end

  def show
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    fx = SnapshotService.fx_to_pln
    positions = positions_for(portfolio, instruments_map, fx)
    render json: portfolio_json(portfolio).merge(
      totals: ValuationService.totals(positions).transform_values(&:to_s),
      positions: positions.map { |pos| position_json(pos) }
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

  def snapshots
    rows = PortfolioSnapshot.where(portfolio_id: params[:id].to_i).order(:date).all
    render json: rows.map { |s|
      { date: s.date.to_s, total_value_pln: s.total_value_pln.to_s,
        total_cost_pln: s.total_cost_pln.to_s, pnl_pln: s.pnl_pln.to_s }
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
    pos.to_h.transform_values { |v| v.is_a?(BigDecimal) ? v.to_s : v }
  end
end
