module RageCable
  # No auth — single-user, self-hosted app; accept every connection.
  class Connection < Rage::Cable::Connection
    def connect; end
  end
end
