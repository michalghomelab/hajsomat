class ScheduleController < RageController::API
  def index
    render json: {
      next_refresh_at: Schedule.next_refresh_at.iso8601,
      next_snapshot_at: Schedule.next_snapshot_at.iso8601
    }
  end
end
