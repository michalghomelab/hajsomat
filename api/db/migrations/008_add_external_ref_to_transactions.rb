Sequel.migration do
  change do
    alter_table(:transactions) do
      add_column :external_ref, String # XTB operation ID; nil for manually-added
      # Unique per portfolio (SQLite treats NULLs as distinct, so manual rows are fine)
      add_index %i[portfolio_id external_ref], unique: true, name: :transactions_portfolio_external_ref
    end
  end
end
