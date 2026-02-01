# frozen_string_literal: true

module Api
  module V1
    class ProductsController < BaseController
      before_action :set_product, only: [:show, :update, :destroy]

      # GET /api/v1/products
      def index
        @products = Product.includes(:product_variants, :category)
        @products = apply_filters(@products)
        @products = paginate(@products.order(created_at: :desc))

        render json: {
          products: @products.map { |p| serialize_product(p) },
          meta: pagination_meta(@products)
        }
      end

      # GET /api/v1/products/:id
      def show
        render json: {
          product: serialize_product(@product, include_variants: true)
        }
      end

      # POST /api/v1/products
      def create
        @product = Product.new(product_params)

        if @product.save
          render json: {
            product: serialize_product(@product, include_variants: true)
          }, status: :created
        else
          render json: {
            error: 'Validation Failed',
            details: @product.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/products/:id
      def update
        if @product.update(product_params)
          render json: {
            product: serialize_product(@product, include_variants: true)
          }
        else
          render json: {
            error: 'Validation Failed',
            details: @product.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/products/:id
      def destroy
        @product.update!(status: 'archived')
        head :no_content
      end

      # GET /api/v1/products/:id/inventory
      def inventory
        set_product
        inventory_items = @product.inventory_items.includes(:location, :product_variant)

        render json: {
          product_id: @product.id,
          total_stock: @product.total_stock,
          inventory: inventory_items.map do |item|
            {
              variant_sku: item.product_variant.sku,
              location: item.location.name,
              quantity: item.quantity,
              reserved: item.reserved_quantity,
              available: item.quantity - item.reserved_quantity,
              status: item.status
            }
          end
        }
      end

      # POST /api/v1/products/:id/sync
      def sync
        set_product
        @product.sync_to_shopify!

        render json: { message: 'Sync initiated', product_id: @product.id }
      end

      private

      def set_product
        @product = Product.find(params[:id])
      end

      def product_params
        params.require(:product).permit(
          :name, :sku, :description, :status, :category_id,
          :brand, :material, :weight,
          product_variants_attributes: [
            :id, :sku, :size, :color, :price, :cost_price,
            :compare_at_price, :barcode, :weight, :active, :_destroy
          ]
        )
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
        scope = scope.with_low_stock if params[:low_stock] == 'true'
        scope
      end

      def serialize_product(product, include_variants: false)
        data = {
          id: product.id,
          name: product.name,
          sku: product.sku,
          description: product.description,
          status: product.status,
          brand: product.brand,
          category: product.category&.name,
          total_stock: product.total_stock,
          low_stock: product.low_stock?,
          created_at: product.created_at.iso8601,
          updated_at: product.updated_at.iso8601
        }

        if include_variants
          data[:variants] = product.product_variants.map do |v|
            {
              id: v.id,
              sku: v.sku,
              size: v.size,
              color: v.color,
              price: v.price.to_f,
              cost_price: v.cost_price&.to_f,
              quantity: v.total_quantity,
              active: v.active
            }
          end
        end

        data
      end
    end
  end
end
