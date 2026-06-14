# frozen_string_literal: true

# Puma configuration. Tunables come from the environment so the same file
# works for local development and inside a container.

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)

environment ENV.fetch("RAILS_ENV", "development")

# Workers (separate processes) — set WEB_CONCURRENCY > 0 in production.
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 1

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
