source 'https://rubygems.org'

ruby '3.2.0'

gem 'rails', '~> 7.1.0'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.0'
gem 'redis', '~> 5.0'
gem 'sidekiq', '~> 7.0'

# API
gem 'jbuilder', '~> 2.11'
gem 'rack-cors'
gem 'kaminari', '~> 1.2'   # pagination (page/per used in controllers)

# Domain
gem 'aasm', '~> 5.5'       # Order state machine

# Boot performance
gem 'bootsnap', require: false

# Authentication
gem 'devise', '~> 4.9'
gem 'jwt', '~> 2.7'

# Third-party integrations
gem 'shopify_api', '~> 13.0'
gem 'quickbooks-ruby', '~> 2.0'
gem 'easypost', '~> 5.0'
gem 'httparty', '~> 0.21'

# Background processing
gem 'sidekiq-scheduler', '~> 5.0'

# Monitoring
gem 'sentry-ruby'
gem 'sentry-rails'

group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.2'
  gem 'pry-rails'
  gem 'dotenv-rails'
end

group :test do
  gem 'shoulda-matchers', '~> 5.0'
  gem 'webmock', '~> 3.18'
  gem 'vcr', '~> 6.1'
  gem 'database_cleaner-active_record', '~> 2.1'
  gem 'simplecov', require: false
end
