class PortfoliosController < RageController::API
  def index
    price_map = InstrumentPriceMap.call
    fx = SnapshotService.fx_to_pln
    render json: Portfolio.all.map { |p|
      PortfolioPresenter.call(p, positions: positions(p, price_map, fx), price_map: price_map)
    }
  end

  def show
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    price_map = InstrumentPriceMap.call
    txns = buys(portfolio)
    positions = value(txns, price_map)
    render json: PortfolioPresenter.call(portfolio, positions: positions, price_map: price_map,
                                                    transactions: txns.group_by(&:instrument_id))
  end

  def create
    input = { name: params[:name] }
    input[:base_currency] = params[:base_currency] if params[:base_currency]
    result = PortfolioContract.new.call(input)
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    render json: PortfolioPresenter.call(Portfolio.create(result.to_h), positions: [], price_map: {}),
           status: :created
  end

  def update
    portfolio = Portfolio[params[:id].to_i]
    return render json: { error: 'not found' }, status: :not_found unless portfolio

    result = PortfolioContract.new.call(name: params[:name])
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    portfolio.update(name: result[:name])
    render json: PortfolioPresenter.call(portfolio, positions: [], price_map: {})
  end

  private

  def buys(portfolio)
    Transaction.where(portfolio_id: portfolio.id, kind: 'buy').all
  end

  def positions(portfolio, price_map, rates)
    value(buys(portfolio), price_map, rates)
  end

  def value(txns, price_map, rates = SnapshotService.fx_to_pln)
    ValuationService.positions(transactions: txns, instruments_by_id: price_map,
                               fx_to_pln: rates, **AppConfig.valuation_settings)
  end
end
