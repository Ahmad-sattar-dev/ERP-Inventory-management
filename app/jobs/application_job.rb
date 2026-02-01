# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Retry on common transient errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :exponentially_longer, attempts: 5

  # Custom retry configuration for rate limiting
  retry_on Integrations::RateLimitError, wait: 60.seconds, attempts: 10

  # Log job execution
  around_perform do |job, block|
    Rails.logger.info("Starting #{job.class.name} with args: #{job.arguments.inspect}")
    start_time = Time.current

    begin
      block.call
      duration = Time.current - start_time
      Rails.logger.info("Completed #{job.class.name} in #{duration.round(2)}s")
    rescue StandardError => e
      duration = Time.current - start_time
      Rails.logger.error("Failed #{job.class.name} after #{duration.round(2)}s: #{e.message}")
      raise
    end
  end
end
