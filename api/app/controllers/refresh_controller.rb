class RefreshController < RageController::API
  def create
    result = RefreshService.call
    PriceBroadcast.refreshed # also notify other connected clients
    render json: result
  rescue MarketData::YahooClient::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end
end
