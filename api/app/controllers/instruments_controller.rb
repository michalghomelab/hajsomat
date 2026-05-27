class InstrumentsController < RageController::API
  def index
    query = params[:q].to_s
    return render json: [] if query.strip.empty?

    render json: MarketData::YahooClient.new.symbol_search(query)
  end
end
