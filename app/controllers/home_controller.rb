class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
    @result = eval(params[:expr]) if params[:expr]
  end
end
