class ScheduleController < RageController::API
  def index
    render json: { next_snapshot_at: SnapshotSchedule.next_at.iso8601 }
  end
end
