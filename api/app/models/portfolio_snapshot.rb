class PortfolioSnapshot < Sequel::Model
  many_to_one :portfolio
end
