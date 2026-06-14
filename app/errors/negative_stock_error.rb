# frozen_string_literal: true

# Raised when an inventory adjustment would drive quantity below zero.
class NegativeStockError < StandardError; end
