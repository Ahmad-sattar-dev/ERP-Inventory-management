# frozen_string_literal: true

# Stub webhook job. Logs the payload so webhook delivery succeeds; replace the
# body with real sync logic when the corresponding integration is implemented.
class ShopifyProductSyncJob < ApplicationJob
  queue_as :webhooks

  def perform(webhook_data = nil)
    Rails.logger.info("ShopifyProductSyncJob received: #{webhook_data.inspect}")
  end
end
