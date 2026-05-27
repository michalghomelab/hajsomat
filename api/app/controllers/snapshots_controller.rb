class SnapshotsController < RageController::API
  def index
    rows = DB[:portfolio_snapshots]
           .select_group(:date)
           .select_append do
             [Sequel.function(:sum, :total_value_pln).as(:total_value_pln),
              Sequel.function(:sum, :total_cost_pln).as(:total_cost_pln),
              Sequel.function(:sum, :pnl_pln).as(:pnl_pln)]
           end
           .order(:date)
           .all
    render json: SnapshotPresenter.call(rows)
  end
end
