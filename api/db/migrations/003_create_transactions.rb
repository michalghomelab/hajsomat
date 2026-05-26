Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id
      foreign_key :portfolio_id, :portfolios, null: false, on_delete: :cascade
      foreign_key :instrument_id, :instruments, null: false
      String :kind, null: false, default: "buy"   # buy|sell (MVP: buy only)
      BigDecimal :quantity, size: [20, 6], null: false
      BigDecimal :price, size: [20, 6], null: false        # in instrument currency
      String :currency, null: false
      BigDecimal :fee, size: [20, 6]                       # unused in MVP
      DateTime :executed_at, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
