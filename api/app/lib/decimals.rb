require 'bigdecimal'

module Decimals
  module_function

  # Plain decimal string for BigDecimals (e.g. "6000.0", not "0.6e4"); other values pass through.
  def string(value)
    value.is_a?(BigDecimal) ? value.to_s('F') : value
  end
end
