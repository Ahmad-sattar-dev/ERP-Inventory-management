# frozen_string_literal: true

module Integrations
  # Raised when a third-party API responds with HTTP 429 (rate limited).
  class RateLimitError < StandardError; end
end
