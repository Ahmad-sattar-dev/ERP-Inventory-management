# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_request!
      before_action :set_default_format

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from StandardError, with: :internal_error

      protected

      def authenticate_request!
        authenticate_or_request_with_http_token do |token, _options|
          @current_api_key = ApiKey.active.find_by(token: token)
          @current_api_key.present?
        end
      end

      def current_api_key
        @current_api_key
      end

      def paginate(collection)
        page = params[:page]&.to_i || 1
        per_page = [params[:per_page]&.to_i || 25, 100].min

        collection.page(page).per(per_page)
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end

      private

      def set_default_format
        request.format = :json
      end

      def not_found(exception)
        render json: {
          error: 'Not Found',
          message: exception.message
        }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: {
          error: 'Validation Failed',
          message: exception.message,
          details: exception.record&.errors&.full_messages
        }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: {
          error: 'Bad Request',
          message: exception.message
        }, status: :bad_request
      end

      def internal_error(exception)
        Rails.logger.error("API Error: #{exception.message}\n#{exception.backtrace.first(10).join("\n")}")

        Sentry.capture_exception(exception) if defined?(Sentry)

        render json: {
          error: 'Internal Server Error',
          message: Rails.env.production? ? 'An unexpected error occurred' : exception.message
        }, status: :internal_server_error
      end
    end
  end
end
