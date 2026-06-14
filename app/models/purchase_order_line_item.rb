# frozen_string_literal: true

class PurchaseOrderLineItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product_variant

  validates :quantity, numericality: { greater_than: 0 }
end
