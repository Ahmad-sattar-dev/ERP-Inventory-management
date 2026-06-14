# frozen_string_literal: true

# Stub mailer. Renders inline bodies (no view templates) so background jobs that
# trigger notifications don't fail. Replace with real templated emails as needed.
class OrderMailer < ApplicationMailer
  def order_confirmed(order)
    @order = order
    mail(
      to: order.customer.email,
      subject: "Order #{order.order_number} confirmed",
      body: "Your order #{order.order_number} has been confirmed.",
      content_type: "text/plain"
    )
  end

  def order_shipped(order)
    @order = order
    mail(
      to: order.customer.email,
      subject: "Order #{order.order_number} shipped",
      body: "Your order #{order.order_number} has shipped.",
      content_type: "text/plain"
    )
  end
end
