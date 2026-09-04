require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # The ALB terminates the connection over plain HTTP for this demo.
  config.assume_ssl = false
  config.force_ssl = false

  config.log_tags = [:request_id]
  logger           = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = ::Logger::Formatter.new
  config.logger    = ActiveSupport::TaggedLogging.new(logger)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.action_controller.perform_caching = true

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
end
