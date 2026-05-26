Sequel.migration do
  change do
    create_table(:portfolios) do
      primary_key :id
      String :name, null: false
      String :base_currency, null: false, default: "PLN"
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
