# Runs a block that may fail on a transient external call, logging the error and
# returning nil instead of raising — for non-critical lookups that should
# degrade rather than abort (a missing quote, a throttled FX fetch, a failed
# cable broadcast).
module Safely
  module_function

  def warn(context)
    yield
  rescue StandardError => e
    Rage.logger.warn("#{context}: #{e.message}") if defined?(Rage)
    nil
  end
end
