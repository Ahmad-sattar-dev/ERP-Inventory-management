# frozen_string_literal: true

# Stub webhook job. Logs the payload so webhook delivery succeeds; replace the
# body with real sync logic when the corresponding integration is implemented.
class ShipstationOrderSyncJob < ApplicationJob
  queue_as :webhooks

  def perform(resource_url = nil)
    Rails.logger.info("ShipstationOrderSyncJob received: #{resource_url.inspect}")
  end
end
