# syntax=docker/dockerfile:1

# ---- Base image -----------------------------------------------------------
# Pin to the Ruby version declared in the Gemfile (ruby '3.2.0').
ARG RUBY_VERSION=3.2.0
FROM ruby:${RUBY_VERSION}-slim AS base

# Rails app lives here
WORKDIR /app

# Common runtime + build dependencies:
#   - libpq-dev / postgresql-client : the `pg` gem and `pg_isready`
#   - build-essential / git         : compiling native gem extensions
#   - curl                          : health checks / debugging
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      curl \
      libpq-dev \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Default environment. Override RAILS_ENV at build/run time for production.
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=true

# ---- Dependencies layer ---------------------------------------------------
# Copy only the gem manifests first so `bundle install` is cached unless they
# change. (Gemfile.lock is optional here — it is generated on first install.)
COPY Gemfile Gemfile.lock* ./
RUN bundle install

# ---- Application ----------------------------------------------------------
COPY . .

# Entrypoint prepares the database before the server starts.
COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod +x /usr/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3000

# Default command: boot the Rails server bound to all interfaces.
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
