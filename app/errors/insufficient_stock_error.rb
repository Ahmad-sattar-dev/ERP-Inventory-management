# frozen_string_literal: true

# Raised when there isn't enough available stock to reserve or fulfill.
class InsufficientStockError < StandardError; end
