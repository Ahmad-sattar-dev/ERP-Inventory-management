# frozen_string_literal: true

module Api
  module V1
    class InventoryController < BaseController
      before_action :set_inventory_item, only: [:show, :update, :adjust]

      # GET /api/v1/inventory
      def index
        @items = InventoryItem.includes(:product_variant, :location)
        @items = apply_filters(@items)
        @items = paginate(@items.order(:id))

        render json: {
          inventory: @items.map { |item| serialize_inventory(item) },
          meta: pagination_meta(@items)
        }
      end

      # GET /api/v1/inventory/:id
      def show
        render json: {
          inventory: serialize_inventory(@item, include_movements: true)
        }
      end

      # PATCH /api/v1/inventory/:id
      def update
        if @item.update(inventory_params)
          render json: { inventory: serialize_inventory(@item) }
        else
          render json: {
            error: 'Validation Failed',
            details: @item.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/inventory/:id/adjust
      def adjust
        quantity_change = params[:quantity].to_i
        reason = params[:reason] || 'manual_adjustment'

        if quantity_change.zero?
          return render json: {
            error: 'Invalid Quantity',
            message: 'Quantity change cannot be zero'
          }, status: :bad_request
        end

        begin
          InventoryItem.adjust_stock(
            variant_id: @item.product_variant_id,
            location_id: @item.location_id,
            quantity: quantity_change,
            reason: reason,
            reference: nil
          )

          @item.reload
          render json: {
            message: 'Inventory adjusted',
            inventory: serialize_inventory(@item)
          }
        rescue NegativeStockError => e
          render json: {
            error: 'Insufficient Stock',
            message: e.message
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/inventory/bulk_adjust
      def bulk_adjust
        results = { success: [], errors: [] }

        params[:adjustments].each do |adjustment|
          begin
            item = InventoryItem.adjust_stock(
              variant_id: adjustment[:product_variant_id],
              location_id: adjustment[:location_id],
              quantity: adjustment[:quantity].to_i,
              reason: adjustment[:reason] || 'bulk_adjustment'
            )
            results[:success] << { variant_id: adjustment[:product_variant_id], new_quantity: item.quantity }
          rescue StandardError => e
            results[:errors] << { variant_id: adjustment[:product_variant_id], error: e.message }
          end
        end

        status = results[:errors].empty? ? :ok : :multi_status
        render json: results, status: status
      end

      # GET /api/v1/inventory/low_stock
      def low_stock
        @items = InventoryItem.low_stock.includes(:product_variant, :location)
        @items = paginate(@items.order(:quantity))

        render json: {
          low_stock_items: @items.map { |item| serialize_inventory(item) },
          meta: pagination_meta(@items)
        }
      end

      # GET /api/v1/inventory/summary
      def summary
        render json: {
          summary: {
            total_items: InventoryItem.count,
            total_quantity: InventoryItem.sum(:quantity),
            total_reserved: InventoryItem.sum(:reserved_quantity),
            low_stock_count: InventoryItem.low_stock.count,
            out_of_stock_count: InventoryItem.out_of_stock.count,
            by_location: InventoryItem.group(:location_id).sum(:quantity),
            by_status: InventoryItem.group(:status).count
          }
        }
      end

      # POST /api/v1/inventory/transfer
      def transfer
        from_location = params[:from_location_id]
        to_location = params[:to_location_id]
        variant_id = params[:product_variant_id]
        quantity = params[:quantity].to_i

        if quantity <= 0
          return render json: {
            error: 'Invalid Quantity',
            message: 'Quantity must be positive'
          }, status: :bad_request
        end

        InventoryItem.transaction do
          # Remove from source location
          InventoryItem.adjust_stock(
            variant_id: variant_id,
            location_id: from_location,
            quantity: -quantity,
            reason: 'transfer_out'
          )

          # Add to destination location
          InventoryItem.adjust_stock(
            variant_id: variant_id,
            location_id: to_location,
            quantity: quantity,
            reason: 'transfer_in'
          )
        end

        render json: {
          message: 'Transfer completed',
          quantity: quantity,
          from_location: from_location,
          to_location: to_location
        }
      rescue NegativeStockError => e
        render json: {
          error: 'Insufficient Stock',
          message: e.message
        }, status: :unprocessable_entity
      end

      private

      def set_inventory_item
        @item = InventoryItem.find(params[:id])
      end

      def inventory_params
        params.require(:inventory).permit(:reorder_point, :reorder_quantity, :bin_location, :status)
      end

      def apply_filters(scope)
        scope = scope.at_location(params[:location_id]) if params[:location_id].present?
        scope = scope.where(product_variant_id: params[:variant_id]) if params[:variant_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.low_stock if params[:low_stock] == 'true'
        scope = scope.out_of_stock if params[:out_of_stock] == 'true'
        scope
      end

      def serialize_inventory(item, include_movements: false)
        data = {
          id: item.id,
          product_variant: {
            id: item.product_variant.id,
            sku: item.product_variant.sku,
            name: item.product_variant.display_name
          },
          location: {
            id: item.location.id,
            name: item.location.name
          },
          quantity: item.quantity,
          reserved_quantity: item.reserved_quantity,
          available_quantity: item.quantity - item.reserved_quantity,
          reorder_point: item.reorder_point,
          reorder_quantity: item.reorder_quantity,
          bin_location: item.bin_location,
          status: item.status,
          low_stock: item.low_stock?,
          last_counted_at: item.last_counted_at&.iso8601,
          updated_at: item.updated_at.iso8601
        }

        if include_movements
          data[:recent_movements] = item.inventory_movements.order(created_at: :desc).limit(10).map do |m|
            {
              quantity_change: m.quantity_change,
              reason: m.reason,
              resulting_quantity: m.resulting_quantity,
              created_at: m.created_at.iso8601
            }
          end
        end

        data
      end
    end
  end
end
