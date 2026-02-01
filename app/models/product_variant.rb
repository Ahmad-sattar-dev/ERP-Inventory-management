# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  # Associations
  belongs_to :product
  has_many :inventory_items, dependent: :destroy
  has_many :line_items, dependent: :restrict_with_error

  # Validations
  validates :sku, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_size, ->(size) { where(size: size) }
  scope :by_color, ->(color) { where(color: color) }
  scope :in_stock, -> { joins(:inventory_items).where('inventory_items.quantity > 0').distinct }

  # Callbacks
  before_validation :generate_variant_sku, on: :create, if: -> { sku.blank? }

  # Instance Methods
  def display_name
    attributes = [size, color].compact.join(' / ')
    attributes.present? ? "#{product.name} - #{attributes}" : product.name
  end

  def total_quantity
    inventory_items.sum(:quantity)
  end

  def available_quantity
    inventory_items.available.sum(:quantity)
  end

  def reserved_quantity
    inventory_items.reserved.sum(:quantity)
  end

  def margin
    return nil unless cost_price.present? && cost_price > 0
    ((price - cost_price) / cost_price * 100).round(2)
  end

  def reserve_stock!(quantity, order:)
    available = available_quantity
    raise InsufficientStockError, "Only #{available} available" if quantity > available

    inventory_items.available.each do |item|
      break if quantity <= 0

      reserve_amount = [item.quantity, quantity].min
      item.reserve!(reserve_amount, order: order)
      quantity -= reserve_amount
    end
  end

  private

  def generate_variant_sku
    suffix = [size&.first, color&.first(3)].compact.join('-').upcase
    self.sku = "#{product.sku}-#{suffix}-#{SecureRandom.hex(2).upcase}"
  end
end


# == Schema Information
#
# Table name: product_variants
#
#  id                  :bigint           not null, primary key
#  product_id          :bigint           not null
#  sku                 :string           not null
#  size                :string
#  color               :string
#  price               :decimal(10, 2)   not null
#  cost_price          :decimal(10, 2)
#  compare_at_price    :decimal(10, 2)
#  barcode             :string
#  weight              :decimal(10, 2)
#  active              :boolean          default(true)
#  shopify_variant_id  :string
#  metadata            :jsonb            default({})
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
