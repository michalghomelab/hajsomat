class InstrumentsController < RageController::API
  def search
    query = params[:q].to_s
    return render json: [] if query.strip.empty?

    render json: MarketData::TwelveDataClient.new.symbol_search(query)
  end
end
