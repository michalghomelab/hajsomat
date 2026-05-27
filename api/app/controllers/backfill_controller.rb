class BackfillController < RageController::API
  def create
    render json: BackfillService.call
  rescue MarketData::YahooClient::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end
end
