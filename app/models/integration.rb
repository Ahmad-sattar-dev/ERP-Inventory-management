# frozen_string_literal: true

class Integration < ApplicationRecord
  # Encrypts sensitive credentials
  encrypts :credentials

  # Validations
  validates :name, presence: true
  validates :provider, presence: true, inclusion: {
    in: %w[shopify woocommerce quickbooks xero shipstation easypost]
  }
  validates :provider, uniqueness: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :shopify, -> { where(provider: 'shopify') }
  scope :quickbooks, -> { where(provider: 'quickbooks') }
  scope :shipping, -> { where(provider: %w[shipstation easypost]) }

  # Callbacks
  after_update :clear_cached_client

  # Class Methods
  def self.for_provider(provider)
    find_by(provider: provider, active: true)
  end

  # Instance Methods
  def configured?
    credentials.present? && required_credentials_present?
  end

  def test_connection!
    service_class.new(self).test_connection
  rescue StandardError => e
    update!(last_error: e.message, last_error_at: Time.current)
    false
  end

  def sync!
    return unless active? && configured?

    update!(last_sync_started_at: Time.current, sync_status: 'running')

    begin
      service_class.new(self).full_sync
      update!(
        last_sync_at: Time.current,
        sync_status: 'completed',
        last_error: nil
      )
    rescue StandardError => e
      update!(
        sync_status: 'failed',
        last_error: e.message,
        last_error_at: Time.current
      )
      raise
    end
  end

  def webhook_secret
    credentials&.dig('webhook_secret')
  end

  def api_credentials
    case provider
    when 'shopify'
      {
        shop_domain: credentials['shop_domain'],
        api_key: credentials['api_key'],
        api_secret: credentials['api_secret'],
        access_token: credentials['access_token']
      }
    when 'quickbooks'
      {
        client_id: credentials['client_id'],
        client_secret: credentials['client_secret'],
        refresh_token: credentials['refresh_token'],
        realm_id: credentials['realm_id']
      }
    when 'shipstation'
      {
        api_key: credentials['api_key'],
        api_secret: credentials['api_secret']
      }
    else
      credentials
    end
  end

  def refresh_oauth_token!
    return unless oauth_provider?

    new_tokens = service_class.new(self).refresh_token
    update!(credentials: credentials.merge(new_tokens))
  end

  private

  def service_class
    "Integrations::#{provider.camelize}Service".constantize
  end

  def required_credentials_present?
    case provider
    when 'shopify'
      %w[shop_domain access_token].all? { |k| credentials[k].present? }
    when 'quickbooks'
      %w[client_id client_secret refresh_token realm_id].all? { |k| credentials[k].present? }
    when 'shipstation'
      %w[api_key api_secret].all? { |k| credentials[k].present? }
    else
      true
    end
  end

  def oauth_provider?
    %w[shopify quickbooks xero].include?(provider)
  end

  def clear_cached_client
    Rails.cache.delete("integration_client_#{id}")
  end
end


# == Schema Information
#
# Table name: integrations
#
#  id                    :bigint           not null, primary key
#  name                  :string           not null
#  provider              :string           not null
#  credentials           :text
#  settings              :jsonb            default({})
#  active                :boolean          default(false)
#  sync_products         :boolean          default(true)
#  sync_orders           :boolean          default(true)
#  sync_customers        :boolean          default(true)
#  sync_inventory        :boolean          default(true)
#  last_sync_at          :datetime
#  last_sync_started_at  :datetime
#  sync_status           :string
#  last_error            :text
#  last_error_at         :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
