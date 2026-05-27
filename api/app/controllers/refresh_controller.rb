class RefreshController < RageController::API
  def create
    render json: RefreshService.new.call
  rescue MarketData::YahooClient::Error => e
    render json: { error: e.message }, status: :service_unavailable
  end
end
