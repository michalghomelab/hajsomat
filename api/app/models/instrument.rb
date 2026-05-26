class Instrument < Sequel::Model
  def td_symbol
    mic && !mic.empty? ? "#{symbol}:#{mic}" : symbol
  end
end
