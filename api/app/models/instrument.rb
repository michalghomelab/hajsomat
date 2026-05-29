class Instrument < Sequel::Model
  dataset_module do
    # Instruments referenced by at least one transaction.
    def in_use = where(id: Transaction.distinct.select(:instrument_id))
  end
end
