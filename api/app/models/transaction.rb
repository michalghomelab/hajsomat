class Transaction < Sequel::Model
  many_to_one :portfolio
  many_to_one :instrument
end
