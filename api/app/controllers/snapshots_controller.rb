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
    render json: rows.map { |r|
      { date: r[:date].to_s, total_value_pln: r[:total_value_pln].to_s,
        total_cost_pln: r[:total_cost_pln].to_s, pnl_pln: r[:pnl_pln].to_s }
    }
  end
end
