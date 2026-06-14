# frozen_string_literal: true

class PurchaseOrder < ApplicationRecord
  has_many :line_items, class_name: "PurchaseOrderLineItem", dependent: :destroy

  scope :pending, -> { where(status: "pending") }

  enum status: {
    draft: "draft",
    pending: "pending",
    ordered: "ordered",
    received: "received",
    cancelled: "cancelled"
  }
end
