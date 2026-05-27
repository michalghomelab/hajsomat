require 'bigdecimal'

module Decimals
  module_function

  # Plain decimal string for money values (e.g. "6000.0", not "0.6e4").
  # Coerces BigDecimal and Float (aggregate SUM rows arrive as Float); nil stays
  # nil; integers and strings (ids, currency codes) pass through untouched.
  def string(value)
    case value
    when BigDecimal then value.to_s('F')
    when Float then BigDecimal(value.to_s).to_s('F')
    else value
    end
  end
end
