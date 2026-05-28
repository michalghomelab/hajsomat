# Pushes a "refreshed" signal to WS clients (PricesChannel) so views reload.
# Safe to call from the web process; failures are logged, not raised.
module PriceBroadcast
  def self.refreshed
    Rage::Cable.broadcast('prices', { type: 'refreshed' })
  rescue StandardError => e
    Rage.logger.warn("cable broadcast failed: #{e.message}")
  end
end
