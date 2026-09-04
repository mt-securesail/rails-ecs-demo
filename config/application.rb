require_relative "boot"

require "rails"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module RailsEcsDemo
  class Application < Rails::Application
    config.load_defaults 7.1

    config.autoload_lib(ignore: %w[assets tasks])

    # No database, no asset pipeline — this app is intentionally minimal.
    config.api_only = false
  end
end
