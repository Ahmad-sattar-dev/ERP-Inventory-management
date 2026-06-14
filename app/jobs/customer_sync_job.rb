# frozen_string_literal: true

# Syncs a customer to external systems (CRM/QuickBooks) after creation.
# Stubbed to a log line — wire up real sync logic as integrations come online.
class CustomerSyncJob < ApplicationJob
  queue_as :default

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer

    Rails.logger.info("CustomerSyncJob: syncing customer #{customer.id} (#{customer.email})")
  end
end
