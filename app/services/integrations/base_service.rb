# frozen_string_literal: true

module Integrations
  class BaseService
    attr_reader :integration

    def initialize(integration = nil)
      @integration = integration || default_integration
    end

    def test_connection
      raise NotImplementedError, "#{self.class} must implement #test_connection"
    end

    def full_sync
      raise NotImplementedError, "#{self.class} must implement #full_sync"
    end

    protected

    def log_info(message)
      Rails.logger.info("[#{provider_name}] #{message}")
    end

    def log_error(message, exception = nil)
      Rails.logger.error("[#{provider_name}] #{message}")
      Rails.logger.error(exception.backtrace.first(10).join("\n")) if exception
    end

    def with_retry(max_attempts: 3, backoff: :exponential)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue StandardError => e
        if attempts < max_attempts && retryable_error?(e)
          sleep_time = case backoff
                       when :exponential then 2**attempts
                       when :linear then attempts * 2
                       else 1
                       end
          log_info("Retry attempt #{attempts}/#{max_attempts} after #{sleep_time}s")
          sleep(sleep_time)
          retry
        end
        raise
      end
    end

    def retryable_error?(error)
      case error
      when Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNRESET
        true
      when StandardError
        error.message.include?('rate limit') || error.message.include?('429')
      else
        false
      end
    end

    def provider_name
      self.class.name.demodulize.gsub('Service', '')
    end

    def default_integration
      Integration.for_provider(provider_name.underscore)
    end

    def credentials
      integration&.api_credentials || {}
    end
  end
end
