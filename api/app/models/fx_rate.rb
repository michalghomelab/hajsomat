class FxRate < Sequel::Model
  # Atomic upsert keyed by the unique (base, quote) index.
  def self.upsert_rate(base, quote, rate, now = Time.now)
    dataset.insert_conflict(
      target: %i[base quote],
      update: { rate: rate, fetched_at: now }
    ).insert(base: base, quote: quote, rate: rate, fetched_at: now)
  end
end
