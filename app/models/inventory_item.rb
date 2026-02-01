# frozen_string_literal: true

class InventoryItem < ApplicationRecord
  # Associations
  belongs_to :product_variant
  belongs_to :location
  has_many :inventory_movements, dependent: :destroy
  has_many :stock_reservations, dependent: :destroy

  # Validations
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :product_variant_id, uniqueness: { scope: :location_id }
  validates :reorder_point, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :available, -> { where(status: 'available') }
  scope :reserved, -> { where(status: 'reserved') }
  scope :low_stock, -> { where('quantity <= reorder_point') }
  scope :out_of_stock, -> { where(quantity: 0) }
  scope :at_location, ->(location_id) { where(location_id: location_id) }

  # Enums
  enum status: { available: 'available', reserved: 'reserved', damaged: 'damaged' }

  # Callbacks
  after_save :check_low_stock_alert, if: :saved_change_to_quantity?
  after_update :record_movement, if: :saved_change_to_quantity?

  # Class Methods
  def self.adjust_stock(variant_id:, location_id:, quantity:, reason:, reference: nil)
    item = find_or_create_by!(product_variant_id: variant_id, location_id: location_id) do |i|
      i.quantity = 0
      i.status = 'available'
    end

    item.with_lock do
      new_quantity = item.quantity + quantity
      raise NegativeStockError, "Cannot reduce stock below 0" if new_quantity < 0

      item.update!(quantity: new_quantity)
      item.inventory_movements.create!(
        quantity_change: quantity,
        reason: reason,
        reference_type: reference&.class&.name,
        reference_id: reference&.id,
        resulting_quantity: new_quantity
      )
    end

    item
  end

  # Instance Methods
  def reserve!(quantity, order:)
    with_lock do
      raise InsufficientStockError if quantity > self.quantity

      stock_reservations.create!(
        quantity: quantity,
        order: order,
        expires_at: 30.minutes.from_now
      )

      update!(reserved_quantity: reserved_quantity + quantity)
    end
  end

  def release_reservation!(reservation)
    with_lock do
      reservation.destroy!
      update!(reserved_quantity: reserved_quantity - reservation.quantity)
    end
  end

  def fulfill!(quantity)
    with_lock do
      raise InsufficientStockError if quantity > self.quantity

      update!(quantity: self.quantity - quantity)
      record_movement(-quantity, 'fulfillment')
    end
  end

  def low_stock?
    reorder_point.present? && quantity <= reorder_point
  end

  private

  def check_low_stock_alert
    return unless low_stock?

    LowStockAlertJob.perform_later(id)
  end

  def record_movement(change = nil, reason = 'adjustment')
    change ||= quantity - quantity_before_last_save
    return if change.zero?

    inventory_movements.create!(
      quantity_change: change,
      reason: reason,
      resulting_quantity: quantity
    )
  end
end


# == Schema Information
#
# Table name: inventory_items
#
#  id                 :bigint           not null, primary key
#  product_variant_id :bigint           not null
#  location_id        :bigint           not null
#  quantity           :integer          default(0), not null
#  reserved_quantity  :integer          default(0)
#  reorder_point      :integer
#  reorder_quantity   :integer
#  status             :string           default("available")
#  bin_location       :string
#  last_counted_at    :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
