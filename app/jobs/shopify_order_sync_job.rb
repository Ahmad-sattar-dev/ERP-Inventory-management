# frozen_string_literal: true

class ShopifyOrderSyncJob < ApplicationJob
  queue_as :webhooks

  def perform(webhook_data, action)
    integration = Integration.shopify.active.first
    return unless integration

    service = Integrations::ShopifyService.new(integration)

    case action
    when 'create'
      create_order(service, webhook_data)
    when 'update'
      update_order(service, webhook_data)
    when 'cancel'
      cancel_order(webhook_data)
    end
  end

  private

  def create_order(service, webhook_data)
    Rails.logger.info("Processing Shopify order create: #{webhook_data['name']}")

    order = service.sync_order_from_shopify(webhook_data)

    # Auto-confirm paid orders
    if webhook_data['financial_status'] == 'paid' && order.may_confirm?
      order.confirm!
    end

    Rails.logger.info("Shopify order #{order.order_number} created successfully")
  end

  def update_order(service, webhook_data)
    Rails.logger.info("Processing Shopify order update: #{webhook_data['name']}")

    order = Order.find_by(shopify_order_id: webhook_data['id'].to_s)
    return create_order(service, webhook_data) unless order

    # Update order status based on Shopify status
    new_status = map_shopify_status(webhook_data)

    if order.status != new_status
      case new_status
      when 'confirmed' then order.confirm! if order.may_confirm?
      when 'shipped' then order.ship! if order.may_ship?
      when 'delivered' then order.deliver! if order.may_deliver?
      when 'cancelled' then order.cancel! if order.may_cancel?
      end
    end

    Rails.logger.info("Shopify order #{order.order_number} updated to #{order.status}")
  end

  def cancel_order(webhook_data)
    Rails.logger.info("Processing Shopify order cancel: #{webhook_data['name']}")

    order = Order.find_by(shopify_order_id: webhook_data['id'].to_s)
    return unless order

    if order.may_cancel?
      order.cancel!
      Rails.logger.info("Order #{order.order_number} cancelled via Shopify webhook")
    else
      Rails.logger.warn("Cannot cancel order #{order.order_number} - status: #{order.status}")
    end
  end

  def map_shopify_status(webhook_data)
    if webhook_data['cancelled_at'].present?
      'cancelled'
    elsif webhook_data['fulfillment_status'] == 'fulfilled'
      'delivered'
    elsif webhook_data['fulfillment_status'] == 'partial'
      'processing'
    elsif webhook_data['financial_status'] == 'paid'
      'confirmed'
    else
      'pending'
    end
  end
end
