class FxRate < Sequel::Model
  extend Upsertable

  # Atomic upsert keyed by the unique (base, quote) index.
  def self.upsert_rate(base, quote, rate, now = Time.now)
    upsert({ base: base, quote: quote, rate: rate, fetched_at: now }, conflict_target: %i[base quote])
  end
end
