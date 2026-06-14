# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.cache_classes = true
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Log to STDOUT (handled in application.rb when RAILS_LOG_TO_STDOUT is set).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags = [:request_id]

  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.active_job.queue_adapter = :sidekiq

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :smtp

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false

  # Master key is not used; secrets come from the environment.
  config.require_master_key = false

  # Force all access over SSL when behind a proper proxy. Disabled by default
  # so the container works behind whatever ingress the deployer chooses.
  config.assume_ssl = ENV["RAILS_ASSUME_SSL"].present?
  config.force_ssl = ENV["RAILS_FORCE_SSL"].present?
end
