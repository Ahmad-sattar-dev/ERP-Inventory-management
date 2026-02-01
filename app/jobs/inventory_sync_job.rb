# frozen_string_literal: true

class InventorySyncJob < ApplicationJob
  queue_as :default

  def perform(integration_id = nil)
    integrations = if integration_id
                     [Integration.find(integration_id)]
                   else
                     Integration.active.where(sync_inventory: true)
                   end

    integrations.each do |integration|
      sync_inventory_for(integration)
    end
  end

  private

  def sync_inventory_for(integration)
    Rails.logger.info("Syncing inventory for #{integration.provider}")

    case integration.provider
    when 'shopify'
      sync_shopify_inventory(integration)
    when 'woocommerce'
      sync_woocommerce_inventory(integration)
    else
      Rails.logger.warn("Unknown provider for inventory sync: #{integration.provider}")
    end
  rescue StandardError => e
    Rails.logger.error("Inventory sync failed for #{integration.provider}: #{e.message}")
    integration.update!(
      last_error: e.message,
      last_error_at: Time.current
    )
    raise
  end

  def sync_shopify_inventory(integration)
    service = Integrations::ShopifyService.new(integration)

    # Get all inventory items that need syncing
    ProductVariant.where.not(shopify_variant_id: nil).find_each do |variant|
      current_stock = variant.available_quantity

      variant.inventory_items.each do |item|
        next unless item.location.shopify_location_id.present?

        service.update_inventory_level(
          variant,
          item.location.shopify_location_id,
          item.quantity - item.reserved_quantity
        )
      end
    end

    integration.update!(last_sync_at: Time.current, sync_status: 'completed')
  end

  def sync_woocommerce_inventory(integration)
    # WooCommerce inventory sync implementation
    # Similar pattern to Shopify
  end
end
