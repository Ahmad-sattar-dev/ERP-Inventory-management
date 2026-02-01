# frozen_string_literal: true

class LowStockAlertJob < ApplicationJob
  queue_as :low

  def perform(inventory_item_id)
    item = InventoryItem.find(inventory_item_id)
    return unless item.low_stock?

    # Check if we've already sent an alert recently
    cache_key = "low_stock_alert:#{inventory_item_id}"
    return if Rails.cache.exist?(cache_key)

    # Send notifications
    notify_inventory_managers(item)
    create_reorder_suggestion(item)

    # Cache to prevent duplicate alerts (1 hour)
    Rails.cache.write(cache_key, true, expires_in: 1.hour)
  end

  private

  def notify_inventory_managers(item)
    variant = item.product_variant
    product = variant.product

    # Email notification
    InventoryMailer.low_stock_alert(
      item: item,
      product: product,
      variant: variant
    ).deliver_later

    # Slack notification (if configured)
    if ENV['SLACK_INVENTORY_WEBHOOK'].present?
      send_slack_notification(item, product, variant)
    end

    Rails.logger.info(
      "Low stock alert sent for #{product.name} (#{variant.sku}) - " \
      "Quantity: #{item.quantity}, Reorder Point: #{item.reorder_point}"
    )
  end

  def send_slack_notification(item, product, variant)
    payload = {
      text: ":warning: *Low Stock Alert*",
      attachments: [
        {
          color: "warning",
          fields: [
            { title: "Product", value: product.name, short: true },
            { title: "SKU", value: variant.sku, short: true },
            { title: "Current Quantity", value: item.quantity.to_s, short: true },
            { title: "Reorder Point", value: item.reorder_point.to_s, short: true },
            { title: "Location", value: item.location.name, short: true },
            { title: "Suggested Reorder", value: item.reorder_quantity.to_s, short: true }
          ]
        }
      ]
    }

    HTTParty.post(
      ENV['SLACK_INVENTORY_WEBHOOK'],
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def create_reorder_suggestion(item)
    # Create a purchase order suggestion if auto-reorder is enabled
    return unless item.reorder_quantity.present? && item.reorder_quantity > 0

    variant = item.product_variant

    # Check if there's already a pending PO for this item
    existing_po = PurchaseOrder.pending.joins(:line_items)
                               .where(purchase_order_line_items: { product_variant_id: variant.id })
                               .exists?

    return if existing_po

    # Log the suggestion (actual PO creation would require more business logic)
    Rails.logger.info(
      "Reorder suggestion: #{variant.sku} - " \
      "Quantity: #{item.reorder_quantity}, " \
      "Estimated Cost: #{(variant.cost_price || 0) * item.reorder_quantity}"
    )
  end
end
