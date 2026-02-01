# frozen_string_literal: true

module Api
  module V1
    class WebhooksController < ActionController::API
      before_action :verify_webhook_signature

      # POST /api/v1/webhooks/shopify
      def shopify
        topic = request.headers['X-Shopify-Topic']
        shop_domain = request.headers['X-Shopify-Shop-Domain']

        Rails.logger.info("Shopify webhook received: #{topic} from #{shop_domain}")

        case topic
        when 'orders/create'
          ShopifyOrderSyncJob.perform_later(webhook_params.to_h, 'create')
        when 'orders/updated'
          ShopifyOrderSyncJob.perform_later(webhook_params.to_h, 'update')
        when 'orders/cancelled'
          ShopifyOrderSyncJob.perform_later(webhook_params.to_h, 'cancel')
        when 'products/create', 'products/update'
          ShopifyProductSyncJob.perform_later(webhook_params.to_h)
        when 'inventory_levels/update'
          ShopifyInventorySyncJob.perform_later(webhook_params.to_h)
        when 'customers/create', 'customers/update'
          ShopifyCustomerSyncJob.perform_later(webhook_params.to_h)
        else
          Rails.logger.warn("Unhandled Shopify webhook topic: #{topic}")
        end

        head :ok
      end

      # POST /api/v1/webhooks/quickbooks
      def quickbooks
        event_type = params[:eventNotifications]&.first&.dig(:dataChangeEvent, :entities)&.first&.dig(:name)

        Rails.logger.info("QuickBooks webhook received: #{event_type}")

        case event_type
        when 'Customer'
          QuickbooksCustomerSyncJob.perform_later(webhook_params.to_h)
        when 'Invoice'
          QuickbooksInvoiceSyncJob.perform_later(webhook_params.to_h)
        when 'Payment'
          QuickbooksPaymentSyncJob.perform_later(webhook_params.to_h)
        else
          Rails.logger.warn("Unhandled QuickBooks webhook: #{event_type}")
        end

        head :ok
      end

      # POST /api/v1/webhooks/shipstation
      def shipstation
        resource_type = params[:resource_type]
        resource_url = params[:resource_url]

        Rails.logger.info("ShipStation webhook received: #{resource_type}")

        case resource_type
        when 'SHIP_NOTIFY'
          ShipstationShipmentSyncJob.perform_later(resource_url)
        when 'ORDER_NOTIFY'
          ShipstationOrderSyncJob.perform_later(resource_url)
        else
          Rails.logger.warn("Unhandled ShipStation webhook: #{resource_type}")
        end

        head :ok
      end

      private

      def verify_webhook_signature
        case action_name
        when 'shopify'
          verify_shopify_signature
        when 'quickbooks'
          verify_quickbooks_signature
        when 'shipstation'
          verify_shipstation_signature
        end
      end

      def verify_shopify_signature
        hmac_header = request.headers['X-Shopify-Hmac-Sha256']
        return head :unauthorized if hmac_header.blank?

        integration = Integration.shopify.active.first
        return head :unauthorized unless integration

        calculated_hmac = Base64.strict_encode64(
          OpenSSL::HMAC.digest(
            'sha256',
            integration.webhook_secret,
            request.raw_post
          )
        )

        unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
          Rails.logger.warn('Invalid Shopify webhook signature')
          head :unauthorized
        end
      end

      def verify_quickbooks_signature
        signature = request.headers['intuit-signature']
        return head :unauthorized if signature.blank?

        integration = Integration.quickbooks.active.first
        return head :unauthorized unless integration

        calculated_signature = Base64.strict_encode64(
          OpenSSL::HMAC.digest(
            'sha256',
            integration.webhook_secret,
            request.raw_post
          )
        )

        unless ActiveSupport::SecurityUtils.secure_compare(calculated_signature, signature)
          Rails.logger.warn('Invalid QuickBooks webhook signature')
          head :unauthorized
        end
      end

      def verify_shipstation_signature
        # ShipStation uses basic auth or IP whitelisting
        # Implement based on your ShipStation configuration
        true
      end

      def webhook_params
        params.permit!
      end
    end
  end
end
