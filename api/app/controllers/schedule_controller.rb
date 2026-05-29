class ScheduleController < RageController::API
  def index
    render json: {
      next_refresh_at: Schedule.next_refresh_at&.iso8601,
      market_open: Schedule.market_open?
    }
  end
end
