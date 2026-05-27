class Instrument < Sequel::Model
  # Instruments referenced by at least one transaction.
  def self.in_use = where(id: Transaction.distinct.select(:instrument_id))
end
