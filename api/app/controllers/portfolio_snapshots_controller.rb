class PortfolioSnapshotsController < ApplicationController
  def index
    render json: SnapshotPresenter.call(PortfolioSnapshot.for_portfolio(params[:id].to_i).all)
  end
end
