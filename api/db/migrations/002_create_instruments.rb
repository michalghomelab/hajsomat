Sequel.migration do
  change do
    create_table(:instruments) do
      primary_key :id
      String :symbol, null: false
      String :mic            # exchange MIC, e.g. XETR; null for plain US tickers
      String :name
      String :currency, null: false   # USD, EUR, ...
      String :kind, null: false, default: "etf"  # stock|etf
      BigDecimal :last_price, size: [20, 6]
      DateTime :last_price_at
      index [:symbol, :mic], unique: true
    end
  end
end
