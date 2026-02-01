# frozen_string_literal: true

class Customer < ApplicationRecord
  # Associations
  has_many :orders, dependent: :restrict_with_error
  has_many :addresses, dependent: :destroy
  belongs_to :default_shipping_address, class_name: 'Address', optional: true
  belongs_to :default_billing_address, class_name: 'Address', optional: true
  belongs_to :price_list, optional: true

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :customer_type, inclusion: { in: %w[retail wholesale] }

  # Scopes
  scope :retail, -> { where(customer_type: 'retail') }
  scope :wholesale, -> { where(customer_type: 'wholesale') }
  scope :active, -> { where(active: true) }
  scope :with_orders, -> { joins(:orders).distinct }
  scope :by_total_spent, -> { left_joins(:orders).group(:id).order('SUM(orders.total) DESC') }

  # Enums
  enum customer_type: { retail: 'retail', wholesale: 'wholesale' }

  # Callbacks
  before_validation :normalize_email
  after_create :sync_to_crm

  # Instance Methods
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def display_name
    company_name.presence || full_name
  end

  def total_orders
    orders.count
  end

  def total_spent
    orders.delivered.sum(:total)
  end

  def average_order_value
    return 0 if total_orders.zero?
    (total_spent / total_orders).round(2)
  end

  def lifetime_value
    total_spent
  end

  def last_order_date
    orders.maximum(:created_at)
  end

  def days_since_last_order
    return nil unless last_order_date
    (Date.current - last_order_date.to_date).to_i
  end

  def eligible_for_wholesale?
    total_spent >= 10_000 || orders.count >= 10
  end

  def apply_discount(amount)
    discount_rate = price_list&.discount_rate || 0
    (amount * (1 - discount_rate / 100)).round(2)
  end

  def credit_available
    credit_limit - orders.where(status: %w[pending confirmed processing]).sum(:total)
  end

  def sync_to_shopify!
    Integrations::ShopifyService.new.sync_customer(self)
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def sync_to_crm
    CustomerSyncJob.perform_later(id)
  end
end


# == Schema Information
#
# Table name: customers
#
#  id                          :bigint           not null, primary key
#  email                       :string           not null
#  first_name                  :string
#  last_name                   :string
#  company_name                :string
#  phone                       :string
#  customer_type               :string           default("retail")
#  tax_exempt                  :boolean          default(false)
#  tax_id                      :string
#  credit_limit                :decimal(10, 2)   default(0)
#  payment_terms               :integer          default(0)
#  price_list_id               :bigint
#  default_shipping_address_id :bigint
#  default_billing_address_id  :bigint
#  shopify_customer_id         :string
#  quickbooks_customer_id      :string
#  active                      :boolean          default(true)
#  notes                       :text
#  metadata                    :jsonb            default({})
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
