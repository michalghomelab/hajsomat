Sequel.migration do
  change do
    create_table(:fx_rates) do
      primary_key :id
      String :base, null: false    # e.g. USD
      String :quote, null: false   # e.g. PLN
      BigDecimal :rate, size: [20, 8], null: false
      DateTime :fetched_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      index [:base, :quote], unique: true
    end
  end
end
