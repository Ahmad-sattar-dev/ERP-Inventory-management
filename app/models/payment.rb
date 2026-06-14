# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :completed, -> { where(status: "completed") }

  enum status: {
    pending: "pending",
    completed: "completed",
    failed: "failed",
    refunded: "refunded"
  }
end
