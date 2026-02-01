# frozen_string_literal: true

class OrderSyncJob < ApplicationJob
  queue_as :critical

  def perform(order_id)
    order = Order.find(order_id)

    sync_to_quickbooks(order) if should_sync_to_quickbooks?(order)
    sync_to_shipstation(order) if should_sync_to_shipstation?(order)
  end

  private

  def should_sync_to_quickbooks?(order)
    Integration.quickbooks.active.exists? &&
      order.confirmed? &&
      order.quickbooks_invoice_id.blank?
  end

  def should_sync_to_shipstation?(order)
    Integration.shipping.active.exists? &&
      %w[confirmed processing].include?(order.status) &&
      order.metadata['shipstation_order_id'].blank?
  end

  def sync_to_quickbooks(order)
    Rails.logger.info("Syncing order #{order.order_number} to QuickBooks")

    integration = Integration.quickbooks.active.first
    service = Integrations::QuickbooksService.new(integration)

    service.create_invoice(order)

    Rails.logger.info("Order #{order.order_number} synced to QuickBooks")
  rescue StandardError => e
    Rails.logger.error("QuickBooks sync failed for order #{order.order_number}: #{e.message}")
    # Don't raise - allow shipstation sync to continue
  end

  def sync_to_shipstation(order)
    Rails.logger.info("Syncing order #{order.order_number} to ShipStation")

    integration = Integration.shipping.active.first
    service = Integrations::ShipstationService.new(integration)

    service.create_order(order)

    Rails.logger.info("Order #{order.order_number} synced to ShipStation")
  rescue StandardError => e
    Rails.logger.error("ShipStation sync failed for order #{order.order_number}: #{e.message}")
    raise
  end
end
