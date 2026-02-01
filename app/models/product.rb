# frozen_string_literal: true

class Product < ApplicationRecord
  # Associations
  has_many :product_variants, dependent: :destroy
  has_many :inventory_items, through: :product_variants
  has_many :line_items, through: :product_variants
  belongs_to :category, optional: true

  # Validations
  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active draft archived] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :with_low_stock, -> { joins(:inventory_items).where('inventory_items.quantity <= inventory_items.reorder_point') }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  # Enums
  enum status: { draft: 'draft', active: 'active', archived: 'archived' }

  # Callbacks
  before_validation :generate_sku, on: :create, if: -> { sku.blank? }

  # Instance Methods
  def total_stock
    inventory_items.sum(:quantity)
  end

  def available_stock
    inventory_items.where(status: 'available').sum(:quantity)
  end

  def low_stock?
    inventory_items.any? { |item| item.quantity <= item.reorder_point }
  end

  def sync_to_shopify!
    return unless shopify_product_id.present? || should_sync_to_shopify?

    Integrations::ShopifyService.new.sync_product(self)
  end

  private

  def generate_sku
    self.sku = "PRD-#{SecureRandom.hex(4).upcase}"
  end

  def should_sync_to_shopify?
    Integration.shopify.active.exists?
  end
end


# == Schema Information
#
# Table name: products
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  sku                :string           not null
#  description        :text
#  status             :string           default("draft")
#  category_id        :bigint
#  brand              :string
#  material           :string
#  weight             :decimal(10, 2)
#  shopify_product_id :string
#  quickbooks_item_id :string
#  metadata           :jsonb            default({})
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
