# frozen_string_literal: true

# Stub refund service. Real implementation would call the payment gateway and
# create a refund Payment record. Kept minimal so Order#refund! doesn't crash.
class RefundService
  attr_reader :order

  def initialize(order)
    @order = order
  end

  def process!
    Rails.logger.info("Processing refund for order #{order.order_number} (total: #{order.total})")
    order.payments.completed.each do |payment|
      payment.update!(status: "refunded")
    end
    true
  end
end
