class Portfolio < Sequel::Model
  one_to_many :transactions
  one_to_many :portfolio_snapshots
end
