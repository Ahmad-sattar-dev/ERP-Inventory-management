# frozen_string_literal: true

class InventoryMovement < ApplicationRecord
  belongs_to :inventory_item

  validates :quantity_change, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
