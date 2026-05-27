class PortfolioSnapshotsController < RageController::API
  def index
    rows = PortfolioSnapshot.where(portfolio_id: params[:id].to_i).order(:date).all
    render json: SnapshotPresenter.call(rows)
  end
end
