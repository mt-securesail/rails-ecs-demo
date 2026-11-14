class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
  end
end
