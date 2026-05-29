class SnapshotsController < ApplicationController
  def index
    render json: SnapshotPresenter.call(PortfolioSnapshot.totals_by_date.all)
  end

  # Writes today's snapshot for every portfolio from current prices/FX, on demand
  # (the scheduler also does this hourly during the session).
  def create
    render json: { snapshots_written: SnapshotService.call }
  end
end
