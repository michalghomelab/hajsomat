class PortfoliosController < ApplicationController
  def index
    render_result(PortfolioValuation.summary)
  end

  def show
    render_result(PortfolioValuation.detail(params[:id]))
  end

  def create
    render_result(CreatePortfolio.call(params), status: :created)
  end

  def update
    render_result(RenamePortfolio.call(id: params[:id], name: params[:name]))
  end
end
