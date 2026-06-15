# frozen_string_literal: true

module Api
  module V1
    class CustomersController < BaseController
      before_action :set_customer, only: [:show, :update, :destroy]

      # GET /api/v1/customers
      def index
        @customers = Customer.all
        @customers = apply_filters(@customers)
        @customers = paginate(@customers.order(created_at: :desc))

        render json: {
          customers: @customers.map { |c| serialize_customer(c) },
          meta: pagination_meta(@customers)
        }
      end

      # GET /api/v1/customers/:id
      def show
        render json: { customer: serialize_customer(@customer, detailed: true) }
      end

      # POST /api/v1/customers
      def create
        @customer = Customer.new(customer_params)

        if @customer.save
          render json: { customer: serialize_customer(@customer, detailed: true) }, status: :created
        else
          render json: {
            error: 'Validation Failed',
            details: @customer.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/customers/:id
      def update
        if @customer.update(customer_params)
          render json: { customer: serialize_customer(@customer, detailed: true) }
        else
          render json: {
            error: 'Validation Failed',
            details: @customer.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/customers/:id
      def destroy
        if @customer.destroy
          head :no_content
        else
          render json: {
            error: 'Cannot Delete',
            message: @customer.errors.full_messages.join(', ').presence || 'Customer has associated records'
          }, status: :unprocessable_entity
        end
      end

      private

      def set_customer
        @customer = Customer.find(params[:id])
      end

      def customer_params
        params.require(:customer).permit(
          :email, :first_name, :last_name, :company_name, :phone,
          :customer_type, :tax_exempt, :tax_id, :credit_limit,
          :payment_terms, :active, :notes
        )
      end

      def apply_filters(scope)
        scope = scope.where(customer_type: params[:customer_type]) if params[:customer_type].present?
        scope = scope.where(active: params[:active] == 'true') if params[:active].present?
        if params[:search].present?
          term = "%#{params[:search]}%"
          scope = scope.where('email ILIKE :t OR first_name ILIKE :t OR last_name ILIKE :t OR company_name ILIKE :t', t: term)
        end
        scope
      end

      def serialize_customer(customer, detailed: false)
        data = {
          id: customer.id,
          email: customer.email,
          name: customer.display_name,
          first_name: customer.first_name,
          last_name: customer.last_name,
          company_name: customer.company_name,
          phone: customer.phone,
          customer_type: customer.customer_type,
          active: customer.active,
          total_orders: customer.total_orders,
          total_spent: customer.total_spent.to_f,
          created_at: customer.created_at.iso8601
        }

        if detailed
          data[:credit_limit] = customer.credit_limit.to_f
          data[:payment_terms] = customer.payment_terms
          data[:tax_exempt] = customer.tax_exempt
          data[:average_order_value] = customer.average_order_value.to_f
          data[:last_order_date] = customer.last_order_date&.iso8601
        end

        data
      end
    end
  end
end
