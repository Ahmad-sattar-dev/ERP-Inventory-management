# frozen_string_literal: true

# Stub mailer for low-stock alerts. Renders an inline body (no view template).
class InventoryMailer < ApplicationMailer
  def low_stock_alert(item:, product:, variant:)
    @item = item
    @product = product
    @variant = variant

    mail(
      to: ENV.fetch("INVENTORY_ALERT_EMAIL", "inventory@example.com"),
      subject: "Low stock: #{product.name} (#{variant.sku})",
      body: "#{product.name} (#{variant.sku}) is low: #{item.quantity} on hand, " \
            "reorder point #{item.reorder_point}.",
      content_type: "text/plain"
    )
  end
end
