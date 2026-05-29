# Fills in the display name for instruments that don't have one yet (e.g. created
# before names were captured, or imported from a broker report). Names are
# stable metadata, so we only fetch for blanks and never overwrite an existing
# name. Returns the number of instruments named.
class InstrumentNameBackfiller
  extend Callable
  extend Dry::Initializer

  param :instruments
  option :client, default: -> { MarketData::YahooClient.new }

  def call
    instruments.select { |i| i.name.to_s.strip.empty? }.filter_map { |i| backfill(i) }.size
  end

  private

  def backfill(instrument)
    name = fetch_name(instrument.symbol)
    return unless name

    instrument.update(name: name)
  end

  def fetch_name(symbol)
    Safely.warn("name backfill for #{symbol}") { client.quote(symbol)&.dig(:name) }
  end
end
