# frozen_string_literal: true

class Order < ApplicationRecord
  # Associations
  belongs_to :customer
  belongs_to :shipping_address, class_name: 'Address', optional: true
  belongs_to :billing_address, class_name: 'Address', optional: true
  has_many :line_items, dependent: :destroy
  has_many :product_variants, through: :line_items
  has_many :shipments, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :order_notes, dependent: :destroy
  has_many :stock_reservations, dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :line_items, allow_destroy: true
  accepts_nested_attributes_for :shipping_address
  accepts_nested_attributes_for :billing_address

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, presence: true
  validates :subtotal, :total, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :processing, -> { where(status: 'processing') }
  scope :shipped, -> { where(status: 'shipped') }
  scope :delivered, -> { where(status: 'delivered') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Enums
  enum status: {
    draft: 'draft',
    pending: 'pending',
    confirmed: 'confirmed',
    processing: 'processing',
    shipped: 'shipped',
    delivered: 'delivered',
    cancelled: 'cancelled',
    refunded: 'refunded'
  }

  enum channel: {
    manual: 'manual',
    shopify: 'shopify',
    woocommerce: 'woocommerce',
    wholesale: 'wholesale',
    api: 'api'
  }

  # Callbacks
  before_validation :generate_order_number, on: :create
  before_save :calculate_totals
  after_commit :sync_to_integrations, on: [:create, :update]

  # State Machine
  include AASM

  aasm column: :status, enum: true do
    state :draft, initial: true
    state :pending, :confirmed, :processing, :shipped, :delivered, :cancelled, :refunded

    event :submit do
      transitions from: :draft, to: :pending
      after { reserve_inventory! }
    end

    event :confirm do
      transitions from: :pending, to: :confirmed
      after { notify_customer(:order_confirmed) }
    end

    event :process do
      transitions from: :confirmed, to: :processing
    end

    event :ship do
      transitions from: :processing, to: :shipped
      after { notify_customer(:order_shipped) }
    end

    event :deliver do
      transitions from: :shipped, to: :delivered
      after { finalize_order! }
    end

    event :cancel do
      transitions from: [:draft, :pending, :confirmed], to: :cancelled
      after { release_inventory! }
    end

    event :refund do
      transitions from: [:delivered, :shipped], to: :refunded
      after { process_refund! }
    end
  end

  # Instance Methods
  def calculate_totals
    self.subtotal = line_items.sum { |li| li.quantity * li.unit_price }
    self.tax_amount = calculate_tax
    self.shipping_amount ||= 0
    self.discount_amount ||= 0
    self.total = subtotal + tax_amount + shipping_amount - discount_amount
  end

  def reserve_inventory!
    line_items.each do |line_item|
      line_item.product_variant.reserve_stock!(
        line_item.quantity,
        order: self
      )
    end
  end

  def release_inventory!
    stock_reservations.each(&:release!)
  end

  def fulfill!
    transaction do
      line_items.each do |line_item|
        InventoryItem.adjust_stock(
          variant_id: line_item.product_variant_id,
          location_id: fulfillment_location_id,
          quantity: -line_item.quantity,
          reason: 'order_fulfillment',
          reference: self
        )
      end
    end
  end

  def paid?
    payments.completed.sum(:amount) >= total
  end

  # Location used when deducting stock on fulfillment. Defaults to the first
  # active location; override per-order via metadata['fulfillment_location_id'].
  def fulfillment_location_id
    metadata["fulfillment_location_id"] || Location.active.first&.id || Location.first&.id
  end

  def balance_due
    total - payments.completed.sum(:amount)
  end

  def export_to_quickbooks!
    Integrations::QuickbooksService.new.create_invoice(self)
  end

  def create_shipment!(tracking_number:, carrier:)
    shipments.create!(
      tracking_number: tracking_number,
      carrier: carrier,
      status: 'in_transit'
    )
    ship! if may_ship?
  end

  private

  def generate_order_number
    self.order_number ||= "ORD-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
  end

  def calculate_tax
    return 0 unless shipping_address&.state.present?

    tax_rate = TaxRate.for_state(shipping_address.state)
    (subtotal * tax_rate).round(2)
  end

  def sync_to_integrations
    OrderSyncJob.perform_later(id) if saved_change_to_status?
  end

  def notify_customer(event)
    OrderMailer.send(event, self).deliver_later
  end

  def finalize_order!
    update!(completed_at: Time.current)
    fulfill!
  end

  def process_refund!
    # Refund logic implementation
    RefundService.new(self).process!
  end
end


# == Schema Information
#
# Table name: orders
#
#  id                  :bigint           not null, primary key
#  order_number        :string           not null
#  customer_id         :bigint           not null
#  status              :string           default("draft")
#  channel             :string           default("manual")
#  subtotal            :decimal(10, 2)   default(0)
#  tax_amount          :decimal(10, 2)   default(0)
#  shipping_amount     :decimal(10, 2)   default(0)
#  discount_amount     :decimal(10, 2)   default(0)
#  total               :decimal(10, 2)   default(0)
#  currency            :string           default("USD")
#  shipping_address_id :bigint
#  billing_address_id  :bigint
#  notes               :text
#  shopify_order_id    :string
#  quickbooks_invoice_id :string
#  completed_at        :datetime
#  cancelled_at        :datetime
#  metadata            :jsonb            default({})
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
