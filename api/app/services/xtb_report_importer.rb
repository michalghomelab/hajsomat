require 'roo'
require 'time'
require 'bigdecimal'

# Imports buy transactions from an XTB "Cash Operations" .xlsx report. Each
# Stock-purchase row carries an operation ID (stored as external_ref) used to
# dedup, so re-uploading the same/overlapping report is idempotent. Instruments
# fully sold (net quantity <= 0) are skipped so closed positions don't reappear.
class XtbReportImporter
  extend Callable

  SHEET = 'Cash Operations'.freeze
  # XTB exchange suffix -> Yahoo suffix (nil = drop it, e.g. US tickers).
  SUFFIX_MAP = {
    'UK' => 'L',   # London
    'PL' => 'WA',  # Warsaw
    'US' => nil,   # US — no Yahoo suffix
    'DE' => 'DE',  # Xetra
    'FR' => 'PA',  # Paris
    'NL' => 'AS',  # Amsterdam
    'IT' => 'MI',  # Milan
    'ES' => 'MC'   # Madrid
  }.freeze
  # Instruments whose XTB listing differs from where Yahoo carries them.
  SYMBOL_OVERRIDES = { 'SDJ600.DE' => 'SDJ600.MI' }.freeze
  ORDER = %r{(?:OPEN|CLOSE) BUY\s+([\d.]+)(?:/[\d.]+)?\s*@\s*([\d.]+)}

  def initialize(portfolio_id:, path:)
    @portfolio_id = portfolio_id
    @path = path
  end

  def call
    ops = parse_operations
    held = net_quantities(ops).select { |_sym, qty| qty.positive? }.keys
    buys = ops.select { |o| o[:buy] && held.include?(o[:symbol]) }

    # All-or-nothing: if a row fails mid-way we roll back rather than leave a
    # partial import (re-uploading then completes it, deduped by external_ref).
    imported = DB.transaction { buys.count { |buy| import_buy(buy) } }
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

    { buy: buy, symbol: map_symbol(cells[1].to_s.strip),
      quantity: BigDecimal(match[1]), price: BigDecimal(match[2]),
      executed_at: to_time(cells[3]), external_ref: cells[5].to_i.to_s }
  end

  # XTB ticker (e.g. IGLN.UK) -> Yahoo symbol (IGLN.L). Unknown suffixes pass
  # through unchanged so InstrumentResolver can still try them on Yahoo.
  def map_symbol(ticker)
    return SYMBOL_OVERRIDES[ticker] if SYMBOL_OVERRIDES.key?(ticker)

    base, suffix = ticker.split('.', 2)
    return ticker unless suffix && SUFFIX_MAP.key?(suffix)

    yahoo = SUFFIX_MAP[suffix]
    yahoo ? "#{base}.#{yahoo}" : base
  end

  def net_quantities(ops)
    ops.each_with_object(Hash.new(BigDecimal(0))) do |o, acc|
      acc[o[:symbol]] += o[:buy] ? o[:quantity] : -o[:quantity]
    end
  end

  # Returns the created Transaction, or nil when the external_ref already exists.
  def import_buy(operation)
    return if Transaction.where(portfolio_id: @portfolio_id, external_ref: operation[:external_ref]).any?

    instrument = InstrumentResolver.call(symbol: operation[:symbol])
    currency = instrument.currency
    Transaction.create(
      portfolio_id: @portfolio_id, instrument_id: instrument.id, kind: 'buy',
      quantity: operation[:quantity], price: operation[:price], currency: currency,
      executed_at: operation[:executed_at], fx_rate: PurchaseFxRate.call(currency, operation[:executed_at]),
      external_ref: operation[:external_ref]
    )
  end

  def to_time(value)
    value.is_a?(String) ? Time.parse(value) : value.to_time
  end
end
