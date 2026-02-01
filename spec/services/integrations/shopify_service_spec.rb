# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::ShopifyService do
  let(:integration) do
    create(:integration,
           provider: 'shopify',
           credentials: {
             'shop_domain' => 'test-store.myshopify.com',
             'access_token' => 'shpat_test_token',
             'webhook_secret' => 'webhook_secret_123'
           })
  end

  let(:service) { described_class.new(integration) }

  describe '#test_connection' do
    it 'returns true when connection is successful' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/shop.json")
        .to_return(status: 200, body: { shop: { name: 'Test Store' } }.to_json)

      expect(service.test_connection).to be true
    end

    it 'returns false when connection fails' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/shop.json")
        .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

      expect(service.test_connection).to be false
    end
  end

  describe '#sync_product_from_shopify' do
    let(:shopify_product) do
      {
        'id' => 123456,
        'title' => 'Test T-Shirt',
        'body_html' => '<p>A great t-shirt</p>',
        'status' => 'active',
        'variants' => [
          {
            'id' => 111,
            'sku' => 'TSHIRT-S-BLK',
            'price' => '29.99',
            'option1' => 'Small',
            'option2' => 'Black'
          },
          {
            'id' => 112,
            'sku' => 'TSHIRT-M-BLK',
            'price' => '29.99',
            'option1' => 'Medium',
            'option2' => 'Black'
          }
        ]
      }
    end

    it 'creates a new product' do
      expect {
        service.sync_product_from_shopify(shopify_product)
      }.to change(Product, :count).by(1)
    end

    it 'creates product variants' do
      expect {
        service.sync_product_from_shopify(shopify_product)
      }.to change(ProductVariant, :count).by(2)
    end

    it 'sets correct attributes' do
      product = service.sync_product_from_shopify(shopify_product)

      expect(product.name).to eq('Test T-Shirt')
      expect(product.shopify_product_id).to eq('123456')
      expect(product.status).to eq('active')
    end

    it 'updates existing product' do
      existing = create(:product, shopify_product_id: '123456', name: 'Old Name')

      service.sync_product_from_shopify(shopify_product)

      expect(existing.reload.name).to eq('Test T-Shirt')
    end
  end

  describe '#sync_order_from_shopify' do
    let(:shopify_order) do
      {
        'id' => 789,
        'name' => '#1001',
        'financial_status' => 'paid',
        'fulfillment_status' => nil,
        'subtotal_price' => '59.98',
        'total_tax' => '5.00',
        'total_discounts' => '0.00',
        'total_price' => '69.98',
        'shipping_lines' => [{ 'price' => '5.00' }],
        'currency' => 'USD',
        'customer' => {
          'id' => 456,
          'email' => 'customer@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe'
        },
        'line_items' => [
          {
            'variant_id' => 111,
            'quantity' => 2,
            'price' => '29.99'
          }
        ]
      }
    end

    before do
      create(:product_variant, shopify_variant_id: '111')
    end

    it 'creates a new order' do
      expect {
        service.sync_order_from_shopify(shopify_order)
      }.to change(Order, :count).by(1)
    end

    it 'creates customer if not exists' do
      expect {
        service.sync_order_from_shopify(shopify_order)
      }.to change(Customer, :count).by(1)
    end

    it 'sets correct order attributes' do
      order = service.sync_order_from_shopify(shopify_order)

      expect(order.order_number).to eq('#1001')
      expect(order.shopify_order_id).to eq('789')
      expect(order.channel).to eq('shopify')
      expect(order.total).to eq(69.98)
    end

    it 'maps confirmed status for paid orders' do
      order = service.sync_order_from_shopify(shopify_order)
      expect(order.status).to eq('confirmed')
    end

    it 'maps cancelled status' do
      shopify_order['cancelled_at'] = '2024-01-15T10:00:00Z'
      order = service.sync_order_from_shopify(shopify_order)
      expect(order.status).to eq('cancelled')
    end
  end

  describe '#sync_customer' do
    let(:customer) { create(:customer, shopify_customer_id: nil) }

    it 'creates customer in Shopify' do
      stub_request(:post, "https://test-store.myshopify.com/admin/api/2024-01/customers.json")
        .to_return(status: 201, body: { customer: { id: 999 } }.to_json)

      service.sync_customer(customer)

      expect(customer.reload.shopify_customer_id).to eq('999')
    end
  end

  describe '#update_inventory_level' do
    let(:variant) { create(:product_variant, shopify_variant_id: '111') }

    it 'updates inventory in Shopify' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/variants/111.json")
        .to_return(status: 200, body: { variant: { inventory_item_id: 222 } }.to_json)

      stub_request(:post, "https://test-store.myshopify.com/admin/api/2024-01/inventory_levels/set.json")
        .to_return(status: 200, body: { inventory_level: {} }.to_json)

      expect {
        service.update_inventory_level(variant, 'loc_123', 50)
      }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'raises RateLimitError on 429 response' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/products.json")
        .to_return(status: 429, body: { error: 'Too Many Requests' }.to_json)

      expect {
        service.send(:get, 'products.json')
      }.to raise_error(Integrations::RateLimitError)
    end

    it 'raises AuthenticationError on 401 response' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/products.json")
        .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)

      expect {
        service.send(:get, 'products.json')
      }.to raise_error(Integrations::AuthenticationError)
    end

    it 'retries on timeout errors' do
      stub_request(:get, "https://test-store.myshopify.com/admin/api/2024-01/products.json")
        .to_timeout
        .then.to_return(status: 200, body: { products: [] }.to_json)

      expect {
        service.send(:get, 'products.json')
      }.not_to raise_error
    end
  end
end
