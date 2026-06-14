# frozen_string_literal: true

module Integrations
  # Raised when a third-party API rejects the supplied credentials (HTTP 401).
  class AuthenticationError < StandardError; end
end
