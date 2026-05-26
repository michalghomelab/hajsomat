class FxRate < Sequel::Model
  def self.upsert_rate(base, quote, rate)
    row = self[base: base, quote: quote]
    if row
      row.update(rate: rate, fetched_at: Time.now)
    else
      create(base: base, quote: quote, rate: rate, fetched_at: Time.now)
    end
  end
end
