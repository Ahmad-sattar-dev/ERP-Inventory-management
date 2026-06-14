# frozen_string_literal: true

module Integrations
  # Raised to signal that a request should be retried (e.g. after a token refresh).
  class RetryableError < StandardError; end
end
