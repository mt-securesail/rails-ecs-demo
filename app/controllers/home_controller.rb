class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
    @result = params[:expr] if params[:expr]
  end
end
