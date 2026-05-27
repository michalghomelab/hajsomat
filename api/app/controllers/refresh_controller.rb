require_relative '../services/refresh_service'

class RefreshController < RageController::API
  def create
    render json: RefreshService.new.call
  end
end
