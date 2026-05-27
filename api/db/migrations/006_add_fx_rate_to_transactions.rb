Sequel.migration do
  change do
    # PLN per 1 unit of the transaction currency at the purchase date (NBP table A).
    alter_table(:transactions) do
      add_column :fx_rate, BigDecimal, size: [20, 8]
    end
  end
end
