class TransactionsController < ApplicationController
  def create
    render_result(TransactionCreator.call(portfolio_id: params[:id].to_i, params: params), status: :created)
  end

  def destroy
    render_result(DeleteTransaction.call(params[:id]))
  end
end
