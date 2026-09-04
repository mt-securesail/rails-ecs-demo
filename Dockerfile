# syntax=docker/dockerfile:1
FROM ruby:3.2-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libyaml-dev pkg-config curl && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1"

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

COPY . .

ARG APP_VERSION=unknown
ENV APP_VERSION=${APP_VERSION}

RUN useradd --create-home --shell /bin/bash appuser && \
    mkdir -p tmp/pids log && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
