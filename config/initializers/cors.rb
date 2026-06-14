# frozen_string_literal: true

# Allow cross-origin requests so browser-based clients can hit the API.
# Lock `origins` down to your real front-end host(s) in production.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "*").split(",").map(&:strip)

    resource "*",
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             expose: ["Authorization"]
  end
end
