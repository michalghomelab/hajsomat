# Pushes a "refreshed" signal to WS clients (PricesChannel) so views reload.
# Safe to call from the web process; failures are logged, not raised.
module PriceBroadcast
  def self.refreshed
    Safely.warn('cable broadcast') { Rage::Cable.broadcast('prices', { type: 'refreshed' }) }
  end
end
