# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks this API app actually uses (no assets / cable / mailbox).
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ApparelInventory
  class Application < Rails::Application
    # Initialize configuration defaults for the originally generated Rails version.
    config.load_defaults 7.1

    # This is an API-only application (no cookies, sessions, or views by default).
    config.api_only = true

    # Run background jobs through Sidekiq.
    config.active_job.queue_adapter = :sidekiq

    # Log to STDOUT in containers so `docker compose logs` shows everything.
    if ENV["RAILS_LOG_TO_STDOUT"].present?
      logger           = ActiveSupport::Logger.new($stdout)
      logger.formatter = config.log_formatter
      config.logger    = ActiveSupport::TaggedLogging.new(logger)
    end

    # Active Record encryption keys (used by Integration#credentials).
    # In development/test these fall back to demo keys; ALWAYS override in
    # production via environment variables.
    config.active_record.encryption.primary_key =
      ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "demo_primary_key_change_me_0000000000000")
    config.active_record.encryption.deterministic_key =
      ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "demo_deterministic_key_change_me_00000000")
    config.active_record.encryption.key_derivation_salt =
      ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "demo_salt_change_me_000000000000000000000")
  end
end
