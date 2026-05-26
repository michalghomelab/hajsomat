Sequel.migration do
  change do
    create_table(:portfolio_snapshots) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false, on_delete: :cascade
      Date :date, null: false
      BigDecimal :total_value_pln, size: [20, 2], null: false
      BigDecimal :total_cost_pln, size: [20, 2], null: false
      BigDecimal :pnl_pln, size: [20, 2], null: false
      index [:portfolio_id, :date], unique: true
    end
  end
end
