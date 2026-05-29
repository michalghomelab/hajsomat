class InstrumentsController < RageController::API
  def index
    query = params[:q].to_s
    return render json: [] if query.strip.empty?

    render json: MarketData.gateway.symbol_search(query)
  end
end
