# frozen_string_literal: true

module Api
  module V1
    class OrdersController < BaseController
      before_action :set_order, only: [:show, :update, :destroy, :confirm, :ship, :cancel]

      # GET /api/v1/orders
      def index
        @orders = Order.includes(:customer, :line_items)
        @orders = apply_filters(@orders)
        @orders = paginate(@orders.order(created_at: :desc))

        render json: {
          orders: @orders.map { |o| serialize_order(o) },
          meta: pagination_meta(@orders)
        }
      end

      # GET /api/v1/orders/:id
      def show
        render json: {
          order: serialize_order(@order, include_items: true)
        }
      end

      # POST /api/v1/orders
      def create
        @order = Order.new(order_params)
        @order.channel = 'api'

        Order.transaction do
          if @order.save
            @order.submit! if params[:submit] == true

            render json: {
              order: serialize_order(@order, include_items: true)
            }, status: :created
          else
            render json: {
              error: 'Validation Failed',
              details: @order.errors.full_messages
            }, status: :unprocessable_entity
          end
        end
      end

      # PATCH/PUT /api/v1/orders/:id
      def update
        if @order.update(order_params)
          render json: {
            order: serialize_order(@order, include_items: true)
          }
        else
          render json: {
            error: 'Validation Failed',
            details: @order.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/confirm
      def confirm
        if @order.may_confirm?
          @order.confirm!
          render json: {
            message: 'Order confirmed',
            order: serialize_order(@order)
          }
        else
          render json: {
            error: 'Invalid Transition',
            message: "Cannot confirm order in #{@order.status} status"
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/ship
      def ship
        unless params[:tracking_number].present?
          return render json: {
            error: 'Missing Parameter',
            message: 'tracking_number is required'
          }, status: :bad_request
        end

        if @order.may_ship?
          @order.create_shipment!(
            tracking_number: params[:tracking_number],
            carrier: params[:carrier] || 'unknown'
          )

          render json: {
            message: 'Order shipped',
            order: serialize_order(@order)
          }
        else
          render json: {
            error: 'Invalid Transition',
            message: "Cannot ship order in #{@order.status} status"
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/orders/:id/cancel
      def cancel
        if @order.may_cancel?
          @order.cancel!
          render json: {
            message: 'Order cancelled',
            order: serialize_order(@order)
          }
        else
          render json: {
            error: 'Invalid Transition',
            message: "Cannot cancel order in #{@order.status} status"
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/orders/:id
      def destroy
        if @order.draft?
          @order.destroy!
          head :no_content
        else
          render json: {
            error: 'Cannot Delete',
            message: 'Only draft orders can be deleted'
          }, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = Order.find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :customer_id, :notes, :shipping_amount, :discount_amount,
          line_items_attributes: [
            :id, :product_variant_id, :quantity, :unit_price, :_destroy
          ],
          shipping_address_attributes: [
            :address_line_1, :address_line_2, :city, :state, :postal_code, :country
          ]
        )
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(channel: params[:channel]) if params[:channel].present?
        scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        scope = scope.created_between(params[:from], params[:to]) if params[:from].present? && params[:to].present?
        scope = scope.where('order_number ILIKE ?', "%#{params[:search]}%") if params[:search].present?
        scope
      end

      def serialize_order(order, include_items: false)
        data = {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          channel: order.channel,
          customer: {
            id: order.customer.id,
            name: order.customer.display_name,
            email: order.customer.email
          },
          subtotal: order.subtotal.to_f,
          tax_amount: order.tax_amount.to_f,
          shipping_amount: order.shipping_amount.to_f,
          discount_amount: order.discount_amount.to_f,
          total: order.total.to_f,
          currency: order.currency,
          item_count: order.line_items.sum(:quantity),
          created_at: order.created_at.iso8601,
          updated_at: order.updated_at.iso8601
        }

        if include_items
          data[:line_items] = order.line_items.map do |li|
            {
              id: li.id,
              product_variant_id: li.product_variant_id,
              sku: li.product_variant.sku,
              name: li.product_variant.display_name,
              quantity: li.quantity,
              unit_price: li.unit_price.to_f,
              total: (li.quantity * li.unit_price).to_f
            }
          end

          data[:shipping_address] = serialize_address(order.shipping_address) if order.shipping_address
          data[:shipments] = order.shipments.map do |s|
            {
              id: s.id,
              tracking_number: s.tracking_number,
              carrier: s.carrier,
              status: s.status,
              shipped_at: s.shipped_at&.iso8601
            }
          end
        end

        data
      end

      def serialize_address(address)
        return nil unless address

        {
          address_line_1: address.address_line_1,
          address_line_2: address.address_line_2,
          city: address.city,
          state: address.state,
          postal_code: address.postal_code,
          country: address.country
        }
      end
    end
  end
end
