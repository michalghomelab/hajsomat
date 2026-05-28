# Clients subscribe here to be told when prices have been refreshed, so the UI
# can reload in step with the scheduler instead of polling.
class PricesChannel < Rage::Cable::Channel
  def subscribed
    stream_from 'prices'
  end
end
