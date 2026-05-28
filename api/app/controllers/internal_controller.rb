# Internal-only (blocked at the edge by nginx): the scheduler hits this after a
# price refresh so the web process can push a "refreshed" signal to WS clients.
class InternalController < RageController::API
  def refreshed
    Rage::Cable.broadcast('prices', { type: 'refreshed' })
    head :no_content
  rescue StandardError => e
    Rage.logger.warn("cable broadcast failed: #{e.message}")
    head :no_content
  end
end
