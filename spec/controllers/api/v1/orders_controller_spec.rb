# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:api_key) { create(:api_key) }
  let(:headers) { { 'Authorization' => "Token #{api_key.token}" } }
  let(:customer) { create(:customer) }

  describe 'GET /api/v1/orders' do
    let!(:orders) { create_list(:order, 3, customer: customer) }

    it 'returns a list of orders' do
      get '/api/v1/orders', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['orders'].length).to eq(3)
    end

    it 'supports filtering by status' do
      create(:order, customer: customer, status: 'shipped')

      get '/api/v1/orders', params: { status: 'shipped' }, headers: headers

      expect(json_response['orders'].length).to eq(1)
      expect(json_response['orders'].first['status']).to eq('shipped')
    end

    it 'includes pagination metadata' do
      get '/api/v1/orders', headers: headers

      expect(json_response['meta']).to include(
        'current_page',
        'total_pages',
        'total_count',
        'per_page'
      )
    end
  end

  describe 'GET /api/v1/orders/:id' do
    let(:order) { create(:order, :with_line_items, customer: customer) }

    it 'returns the order with line items' do
      get "/api/v1/orders/#{order.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['order']['order_number']).to eq(order.order_number)
      expect(json_response['order']['line_items']).to be_present
    end

    it 'returns 404 for non-existent order' do
      get '/api/v1/orders/99999', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/orders' do
    let(:variant) { create(:product_variant, :with_stock) }
    let(:order_params) do
      {
        order: {
          customer_id: customer.id,
          line_items_attributes: [
            { product_variant_id: variant.id, quantity: 2, unit_price: variant.price }
          ]
        }
      }
    end

    it 'creates a new order' do
      expect {
        post '/api/v1/orders', params: order_params, headers: headers
      }.to change(Order, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'returns the created order' do
      post '/api/v1/orders', params: order_params, headers: headers

      expect(json_response['order']['customer']['id']).to eq(customer.id)
      expect(json_response['order']['line_items'].length).to eq(1)
    end

    it 'sets channel to api' do
      post '/api/v1/orders', params: order_params, headers: headers

      expect(json_response['order']['channel']).to eq('api')
    end

    it 'returns validation errors for invalid data' do
      post '/api/v1/orders', params: { order: { customer_id: nil } }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('Validation Failed')
    end
  end

  describe 'POST /api/v1/orders/:id/confirm' do
    let(:order) { create(:order, customer: customer, status: 'pending') }

    it 'confirms the order' do
      post "/api/v1/orders/#{order.id}/confirm", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['order']['status']).to eq('confirmed')
    end

    it 'returns error for invalid transition' do
      order.update!(status: 'shipped')

      post "/api/v1/orders/#{order.id}/confirm", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('Invalid Transition')
    end
  end

  describe 'POST /api/v1/orders/:id/ship' do
    let(:order) { create(:order, customer: customer, status: 'processing') }

    it 'ships the order with tracking info' do
      post "/api/v1/orders/#{order.id}/ship",
           params: { tracking_number: '1Z999AA1', carrier: 'UPS' },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['order']['status']).to eq('shipped')
    end

    it 'requires tracking number' do
      post "/api/v1/orders/#{order.id}/ship", headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json_response['message']).to include('tracking_number')
    end
  end

  describe 'POST /api/v1/orders/:id/cancel' do
    let(:order) { create(:order, customer: customer, status: 'pending') }

    it 'cancels the order' do
      post "/api/v1/orders/#{order.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['order']['status']).to eq('cancelled')
    end
  end

  describe 'DELETE /api/v1/orders/:id' do
    context 'when order is draft' do
      let(:order) { create(:order, customer: customer, status: 'draft') }

      it 'deletes the order' do
        delete "/api/v1/orders/#{order.id}", headers: headers

        expect(response).to have_http_status(:no_content)
        expect(Order.exists?(order.id)).to be false
      end
    end

    context 'when order is not draft' do
      let(:order) { create(:order, customer: customer, status: 'confirmed') }

      it 'returns error' do
        delete "/api/v1/orders/#{order.id}", headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Cannot Delete')
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
