# frozen_string_literal: true

module Integrations
  class ShopifyService < BaseService
    def initialize(integration = nil)
      super
      setup_client if integration&.configured?
    end

    def test_connection
      response = client.get("shop.json")
      response.code == 200
    rescue StandardError => e
      log_error("Connection test failed", e)
      false
    end

    def full_sync
      sync_products if integration.sync_products?
      sync_orders if integration.sync_orders?
      sync_customers if integration.sync_customers?
      sync_inventory if integration.sync_inventory?
    end

    # Product Sync
    def sync_products
      log_info("Starting product sync")

      products = fetch_all_products
      products.each do |shopify_product|
        sync_product_from_shopify(shopify_product)
      end

      log_info("Product sync completed: #{products.count} products")
    end

    def sync_product(product)
      if product.shopify_product_id.present?
        update_shopify_product(product)
      else
        create_shopify_product(product)
      end
    end

    def sync_product_from_shopify(shopify_data)
      product = Product.find_or_initialize_by(shopify_product_id: shopify_data['id'].to_s)

      product.assign_attributes(
        name: shopify_data['title'],
        description: shopify_data['body_html'],
        sku: shopify_data['variants'].first&.dig('sku') || "SHOP-#{shopify_data['id']}",
        status: shopify_data['status'] == 'active' ? 'active' : 'draft'
      )

      product.save!

      # Sync variants
      shopify_data['variants'].each do |variant_data|
        sync_variant_from_shopify(product, variant_data)
      end

      product
    end

    # Order Sync
    def sync_orders(since: nil)
      log_info("Starting order sync")

      params = { status: 'any', limit: 250 }
      params[:updated_at_min] = since.iso8601 if since

      orders = fetch_all_orders(params)
      orders.each do |shopify_order|
        sync_order_from_shopify(shopify_order)
      end

      log_info("Order sync completed: #{orders.count} orders")
    end

    def sync_order_from_shopify(shopify_data)
      order = Order.find_or_initialize_by(shopify_order_id: shopify_data['id'].to_s)

      customer = sync_customer_from_shopify(shopify_data['customer']) if shopify_data['customer']

      order.assign_attributes(
        customer: customer,
        order_number: shopify_data['name'],
        status: map_shopify_status(shopify_data),
        channel: 'shopify',
        subtotal: shopify_data['subtotal_price'].to_d,
        tax_amount: shopify_data['total_tax'].to_d,
        shipping_amount: shopify_data['shipping_lines'].sum { |s| s['price'].to_d },
        discount_amount: shopify_data['total_discounts'].to_d,
        total: shopify_data['total_price'].to_d,
        currency: shopify_data['currency']
      )

      order.save!

      # Sync line items
      shopify_data['line_items'].each do |item_data|
        sync_line_item_from_shopify(order, item_data)
      end

      order
    end

    # Customer Sync
    def sync_customer(customer)
      if customer.shopify_customer_id.present?
        update_shopify_customer(customer)
      else
        create_shopify_customer(customer)
      end
    end

    def sync_customer_from_shopify(shopify_data)
      return nil unless shopify_data

      customer = Customer.find_or_initialize_by(shopify_customer_id: shopify_data['id'].to_s)

      customer.assign_attributes(
        email: shopify_data['email'],
        first_name: shopify_data['first_name'],
        last_name: shopify_data['last_name'],
        phone: shopify_data['phone'],
        customer_type: shopify_data['tags']&.include?('wholesale') ? 'wholesale' : 'retail'
      )

      customer.save!
      customer
    end

    # Inventory Sync
    def sync_inventory
      log_info("Starting inventory sync")

      locations = fetch_locations
      locations.each do |location|
        sync_inventory_levels(location['id'])
      end
    end

    def update_inventory_level(variant, location_id, quantity)
      inventory_item_id = get_inventory_item_id(variant.shopify_variant_id)
      return unless inventory_item_id

      with_retry do
        client.post("inventory_levels/set.json", {
          inventory_level: {
            inventory_item_id: inventory_item_id,
            location_id: location_id,
            available: quantity
          }
        })
      end
    end

    private

    def setup_client
      @client = HTTParty
      @base_url = "https://#{credentials[:shop_domain]}/admin/api/2024-01"
      @headers = {
        'Content-Type' => 'application/json',
        'X-Shopify-Access-Token' => credentials[:access_token]
      }
    end

    def client
      @client
    end

    def get(endpoint, params = {})
      with_retry do
        response = HTTParty.get(
          "#{@base_url}/#{endpoint}",
          headers: @headers,
          query: params
        )
        handle_response(response)
      end
    end

    def post(endpoint, body)
      with_retry do
        response = HTTParty.post(
          "#{@base_url}/#{endpoint}",
          headers: @headers,
          body: body.to_json
        )
        handle_response(response)
      end
    end

    def put(endpoint, body)
      with_retry do
        response = HTTParty.put(
          "#{@base_url}/#{endpoint}",
          headers: @headers,
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
        raise RateLimitError, "Rate limited by Shopify"
      when 401
        raise AuthenticationError, "Invalid Shopify credentials"
      else
        raise ApiError, "Shopify API error: #{response.code} - #{response.body}"
      end
    end

    def fetch_all_products
      products = []
      params = { limit: 250 }

      loop do
        response = get("products.json", params)
        products.concat(response['products'])

        break if response['products'].length < 250
        params[:since_id] = response['products'].last['id']
      end

      products
    end

    def fetch_all_orders(params)
      orders = []

      loop do
        response = get("orders.json", params)
        orders.concat(response['orders'])

        break if response['orders'].length < params[:limit]
        params[:since_id] = response['orders'].last['id']
      end

      orders
    end

    def fetch_locations
      response = get("locations.json")
      response['locations']
    end

    def create_shopify_product(product)
      payload = build_product_payload(product)
      response = post("products.json", { product: payload })

      product.update!(shopify_product_id: response['product']['id'].to_s)

      # Update variant IDs
      response['product']['variants'].each_with_index do |variant_data, index|
        product.product_variants[index]&.update!(shopify_variant_id: variant_data['id'].to_s)
      end
    end

    def update_shopify_product(product)
      payload = build_product_payload(product)
      put("products/#{product.shopify_product_id}.json", { product: payload })
    end

    def build_product_payload(product)
      {
        title: product.name,
        body_html: product.description,
        vendor: product.brand,
        variants: product.product_variants.map do |v|
          {
            id: v.shopify_variant_id,
            sku: v.sku,
            price: v.price.to_s,
            option1: v.size,
            option2: v.color,
            barcode: v.barcode
          }.compact
        end
      }
    end

    def sync_variant_from_shopify(product, variant_data)
      variant = product.product_variants.find_or_initialize_by(
        shopify_variant_id: variant_data['id'].to_s
      )

      variant.assign_attributes(
        sku: variant_data['sku'].presence || "#{product.sku}-#{variant_data['id']}",
        price: variant_data['price'].to_d,
        compare_at_price: variant_data['compare_at_price']&.to_d,
        barcode: variant_data['barcode'],
        size: variant_data['option1'],
        color: variant_data['option2']
      )

      variant.save!
      variant
    end

    def sync_line_item_from_shopify(order, item_data)
      variant = ProductVariant.find_by(shopify_variant_id: item_data['variant_id'].to_s)
      return unless variant

      line_item = order.line_items.find_or_initialize_by(
        product_variant: variant
      )

      line_item.assign_attributes(
        quantity: item_data['quantity'],
        unit_price: item_data['price'].to_d
      )

      line_item.save!
    end

    def map_shopify_status(shopify_order)
      if shopify_order['cancelled_at'].present?
        'cancelled'
      elsif shopify_order['fulfillment_status'] == 'fulfilled'
        'delivered'
      elsif shopify_order['fulfillment_status'] == 'partial'
        'processing'
      elsif shopify_order['financial_status'] == 'paid'
        'confirmed'
      else
        'pending'
      end
    end

    def get_inventory_item_id(variant_id)
      response = get("variants/#{variant_id}.json")
      response['variant']['inventory_item_id']
    rescue StandardError
      nil
    end
  end

  class RateLimitError < StandardError; end
  class AuthenticationError < StandardError; end
  class ApiError < StandardError; end
end
