# frozen_string_literal: true

class StockReservation < ApplicationRecord
  belongs_to :inventory_item
  belongs_to :order

  validates :quantity, numericality: { greater_than: 0 }

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Releases the reservation and restores the held quantity on the inventory item.
  def release!
    inventory_item.release_reservation!(self)
  end
end
