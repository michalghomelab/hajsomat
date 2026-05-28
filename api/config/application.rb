require "bundler/setup"
require "rage"
Bundler.require(*Rage.groups)

require "rage/all"

Rage.configure do
  # Self-hosted single-user app — accept WebSocket connections from any origin
  # (dev serves the SPA on a different port, prod is same-origin behind nginx).
  config.cable.allowed_request_origins = [/.*/]
end

require "rage/setup"
