require 'roo'
require 'time'
require 'bigdecimal'

# Imports buy transactions from an XTB "Cash Operations" .xlsx report. Each
# Stock-purchase row carries an operation ID (stored as external_ref) used to
# dedup, so re-uploading the same/overlapping report is idempotent. Instruments
# fully sold (net quantity <= 0) are skipped so closed positions don't reappear.
#
# Tickers are resolved by their base (the part before the exchange suffix, e.g.
# IGLN from IGLN.UK): an instrument we already hold matches directly; anything
# new is looked up on Yahoo — so no hand-maintained symbol map is needed.
class XtbReportImporter
  extend Callable

  SHEET = 'Cash Operations'.freeze
  ORDER = %r{(?:OPEN|CLOSE) BUY\s+([\d.]+)(?:/[\d.]+)?\s*@\s*([\d.]+)}

  def initialize(portfolio_id:, path:)
    @portfolio_id = portfolio_id
    @path = path
  end

  def call
    ops = parse_operations
    held = net_quantities(ops).select { |_base, qty| qty.positive? }.keys
    buys = ops.select { |o| o[:buy] && held.include?(o[:base]) }

    # All-or-nothing: if a row fails mid-way we roll back rather than leave a
    # partial import (re-uploading then completes it, deduped by external_ref).
    imported = DB.transaction { buys.count { |row| import_buy(row) } }
    { imported: imported, skipped: buys.size - imported }
  end

  private

  def parse_operations
    sheet = Roo::Excelx.new(@path, file_warning: :ignore).sheet(SHEET)
    header = (1..sheet.last_row).find { |i| sheet.row(i)[0].to_s.strip == 'Type' }
    raise "#{SHEET} header not found" unless header

    ((header + 1)..sheet.last_row).filter_map { |i| operation(sheet.row(i)) }
  end

  def operation(cells)
    type = cells[0].to_s.strip
    buy = type == 'Stock purchase'
    return nil unless buy || type == 'Stock sell'

    match = ORDER.match(cells[6].to_s)
    return nil unless match

    { buy: buy, base: cells[1].to_s.strip.split('.').first,
      quantity: BigDecimal(match[1]), price: BigDecimal(match[2]),
      executed_at: to_time(cells[3]), external_ref: cells[5].to_i.to_s }
  end

  def net_quantities(ops)
    ops.each_with_object(Hash.new(BigDecimal(0))) do |o, acc|
      acc[o[:base]] += o[:buy] ? o[:quantity] : -o[:quantity]
    end
  end

  # Returns the created Transaction, or nil when the external_ref already exists.
  def import_buy(row)
    return if Transaction.where(portfolio_id: @portfolio_id, external_ref: row[:external_ref]).any?

    instrument = resolve(row[:base])
    currency = instrument.currency
    Transaction.create(
      portfolio_id: @portfolio_id, instrument_id: instrument.id, kind: 'buy',
      quantity: row[:quantity], price: row[:price], currency: currency,
      executed_at: row[:executed_at], fx_rate: PurchaseFxRate.call(currency, row[:executed_at]),
      external_ref: row[:external_ref]
    )
  end

  # Match the XTB ticker base to an instrument we already hold; otherwise look it
  # up on Yahoo and create it.
  def resolve(base)
    existing_by_base[base] || InstrumentResolver.call(symbol: search_symbol(base) || base)
  end

  def existing_by_base
    @existing_by_base ||= Instrument.all.each_with_object({}) do |inst, acc|
      acc[inst.symbol.split('.').first] ||= inst
    end
  end

  def search_symbol(base)
    MarketData::YahooClient.new.symbol_search(base).find { |c| c[:currency] }&.dig(:symbol)
  end

  def to_time(value)
    value.is_a?(String) ? Time.parse(value) : value.to_time
  end
end
