class TransactionsController < RageController::API
  def create
    result = TransactionContract.new.call(transaction_params)
    return render json: { errors: result.errors.to_h }, status: 422 if result.failure?

    txn = TransactionCreator.call(portfolio_id: params[:id].to_i, data: result.to_h)
    render json: { id: txn.id }, status: :created
  end

  def destroy
    txn = Transaction[params[:id].to_i]
    return render json: {}, status: :not_found unless txn

    txn.destroy
    head :no_content
  end

  private

  def transaction_params
    { symbol: params[:symbol], mic: params[:mic], currency: params[:currency],
      quantity: params[:quantity], price: params[:price], executed_at: params[:executed_at] }
  end
end
