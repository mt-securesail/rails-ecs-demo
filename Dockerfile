# syntax=docker/dockerfile:1
# Pinned to an exact digest so the image scanned on a PR is built from the same
# base as the one deployed. Dependabot (.github/dependabot.yml) opens a PR when
# ruby:3.4-slim gets a new digest; that PR goes through the same scans.
FROM ruby:3.4-slim@sha256:65680693964528b522a38d85ec5065538c7ab9e75268802aab9770f39ee56de0

WORKDIR /app

# apt-get upgrade applies Debian security fixes that the base image doesn't
# have yet (for example zlib CVE-2026-85091, found by Trivy).
RUN apt-get update -qq && \
    apt-get upgrade -y && \
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
