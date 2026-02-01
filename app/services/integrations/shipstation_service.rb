# frozen_string_literal: true

module Integrations
  class ShipstationService < BaseService
    BASE_URL = "https://ssapi.shipstation.com"

    def initialize(integration = nil)
      super
      setup_client if integration&.configured?
    end

    def test_connection
      response = get("stores")
      response.is_a?(Array) || response['stores'].present?
    rescue StandardError => e
      log_error("Connection test failed", e)
      false
    end

    # Order Operations
    def create_order(order)
      payload = build_order_payload(order)
      response = post("orders/createorder", payload)

      order.update!(metadata: order.metadata.merge('shipstation_order_id' => response['orderId']))
      log_info("Created ShipStation order: #{response['orderId']}")

      response
    end

    def update_order(order)
      payload = build_order_payload(order)
      payload['orderId'] = order.metadata['shipstation_order_id']

      post("orders/createorder", payload)
    end

    def cancel_order(order)
      return unless order.metadata['shipstation_order_id'].present?

      post("orders/markasshipped", {
        'orderId' => order.metadata['shipstation_order_id'],
        'carrierCode' => 'cancelled',
        'notifyCustomer' => false
      })
    end

    def get_order(order_id)
      get("orders/#{order_id}")
    end

    # Shipment Operations
    def create_label(order, carrier:, service:, package:, weight:)
      payload = {
        'orderId' => order.metadata['shipstation_order_id'],
        'carrierCode' => carrier,
        'serviceCode' => service,
        'packageCode' => package,
        'weight' => {
          'value' => weight,
          'units' => 'ounces'
        },
        'testLabel' => Rails.env.development?
      }

      response = post("orders/createlabelfororder", payload)

      if response['shipmentId'].present?
        order.shipments.create!(
          tracking_number: response['trackingNumber'],
          carrier: carrier,
          label_url: response['labelData'],
          cost: response['shipmentCost'],
          status: 'label_created'
        )
      end

      response
    end

    def void_label(shipment_id)
      post("shipments/voidlabel", { 'shipmentId' => shipment_id })
    end

    def get_tracking(tracking_number)
      # ShipStation doesn't have direct tracking API
      # Usually you'd use the carrier's API directly
      get("shipments?trackingNumber=#{tracking_number}")
    end

    # Rate Shopping
    def get_rates(order, package_dimensions: nil)
      payload = {
        'carrierCode' => nil, # Get rates from all carriers
        'fromPostalCode' => fulfillment_location_zip,
        'toState' => order.shipping_address.state,
        'toCountry' => order.shipping_address.country || 'US',
        'toPostalCode' => order.shipping_address.postal_code,
        'toCity' => order.shipping_address.city,
        'weight' => {
          'value' => calculate_order_weight(order),
          'units' => 'ounces'
        },
        'dimensions' => package_dimensions || default_dimensions,
        'residential' => !order.customer.wholesale?
      }

      response = post("shipments/getrates", payload)

      response.map do |rate|
        {
          carrier: rate['carrierCode'],
          service: rate['serviceCode'],
          service_name: rate['serviceName'],
          cost: rate['shipmentCost'],
          other_cost: rate['otherCost'],
          total_cost: rate['shipmentCost'] + rate['otherCost'],
          delivery_days: rate['deliveryDays'],
          carrier_delivery_days: rate['carrierDeliveryDays']
        }
      end.sort_by { |r| r[:total_cost] }
    end

    # Webhook Handling
    def process_shipment_notification(resource_url)
      # ShipStation sends a URL to fetch shipment details
      response = HTTParty.get(resource_url, headers: auth_headers)
      shipment_data = response.parsed_response

      shipment_data['shipments'].each do |shipment|
        process_shipment(shipment)
      end
    end

    # Carrier & Service Management
    def list_carriers
      get("carriers")
    end

    def list_services(carrier_code)
      get("carriers/listservices?carrierCode=#{carrier_code}")
    end

    def list_packages(carrier_code)
      get("carriers/listpackages?carrierCode=#{carrier_code}")
    end

    # Warehouse/Fulfillment Locations
    def list_warehouses
      get("warehouses")
    end

    private

    def setup_client
      @api_key = credentials[:api_key]
      @api_secret = credentials[:api_secret]
    end

    def auth_headers
      {
        'Authorization' => "Basic #{Base64.strict_encode64("#{@api_key}:#{@api_secret}")}",
        'Content-Type' => 'application/json'
      }
    end

    def get(endpoint)
      with_retry do
        response = HTTParty.get(
          "#{BASE_URL}/#{endpoint}",
          headers: auth_headers
        )
        handle_response(response)
      end
    end

    def post(endpoint, body)
      with_retry do
        response = HTTParty.post(
          "#{BASE_URL}/#{endpoint}",
          headers: auth_headers,
          body: body.to_json
        )
        handle_response(response)
      end
    end

    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 429
        retry_after = response.headers['X-Rate-Limit-Reset']&.to_i || 60
        raise RateLimitError, "Rate limited. Retry after #{retry_after} seconds"
      when 401
        raise AuthenticationError, "Invalid ShipStation credentials"
      else
        raise ApiError, "ShipStation API error: #{response.code} - #{response.body}"
      end
    end

    def build_order_payload(order)
      {
        'orderNumber' => order.order_number,
        'orderKey' => order.id.to_s,
        'orderDate' => order.created_at.iso8601,
        'orderStatus' => map_order_status(order.status),
        'customerUsername' => order.customer.email,
        'customerEmail' => order.customer.email,
        'billTo' => build_address_payload(order.billing_address || order.shipping_address, order.customer),
        'shipTo' => build_address_payload(order.shipping_address, order.customer),
        'items' => order.line_items.map { |li| build_item_payload(li) },
        'amountPaid' => order.total.to_f,
        'taxAmount' => order.tax_amount.to_f,
        'shippingAmount' => order.shipping_amount.to_f,
        'customerNotes' => order.notes,
        'internalNotes' => "Imported from HRMS ERP",
        'gift' => false,
        'requestedShippingService' => order.metadata['requested_shipping_service'],
        'weight' => {
          'value' => calculate_order_weight(order),
          'units' => 'ounces'
        }
      }
    end

    def build_address_payload(address, customer)
      return nil unless address

      {
        'name' => customer.display_name,
        'company' => customer.company_name,
        'street1' => address.address_line_1,
        'street2' => address.address_line_2,
        'city' => address.city,
        'state' => address.state,
        'postalCode' => address.postal_code,
        'country' => address.country || 'US',
        'phone' => customer.phone,
        'residential' => !customer.wholesale?
      }.compact
    end

    def build_item_payload(line_item)
      variant = line_item.product_variant

      {
        'lineItemKey' => line_item.id.to_s,
        'sku' => variant.sku,
        'name' => variant.display_name,
        'quantity' => line_item.quantity,
        'unitPrice' => line_item.unit_price.to_f,
        'weight' => {
          'value' => (variant.weight || 8).to_f, # Default 8 oz
          'units' => 'ounces'
        }
      }
    end

    def map_order_status(status)
      case status
      when 'draft', 'pending'
        'awaiting_payment'
      when 'confirmed'
        'awaiting_shipment'
      when 'processing'
        'awaiting_shipment'
      when 'shipped'
        'shipped'
      when 'delivered'
        'shipped'
      when 'cancelled'
        'cancelled'
      else
        'awaiting_shipment'
      end
    end

    def calculate_order_weight(order)
      order.line_items.sum do |li|
        (li.product_variant.weight || 8) * li.quantity
      end
    end

    def default_dimensions
      {
        'units' => 'inches',
        'length' => 12,
        'width' => 12,
        'height' => 6
      }
    end

    def fulfillment_location_zip
      integration.settings['fulfillment_zip'] || '90210'
    end

    def process_shipment(shipment_data)
      order = Order.find_by(
        "metadata->>'shipstation_order_id' = ?",
        shipment_data['orderId'].to_s
      )
      return unless order

      order.shipments.find_or_create_by(tracking_number: shipment_data['trackingNumber']) do |s|
        s.carrier = shipment_data['carrierCode']
        s.status = 'in_transit'
        s.shipped_at = Time.parse(shipment_data['shipDate'])
        s.cost = shipment_data['shipmentCost']
      end

      order.ship! if order.may_ship?
    end
  end
end
