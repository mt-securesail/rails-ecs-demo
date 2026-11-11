class ErrorsController < ApplicationController
  # Any method (a POST to an unknown path, too) should just get a 404.
  skip_forgery_protection

  def not_found
    no_store # Cache-Control: no-store (Rails would otherwise send "no-cache")
    render :not_found, status: :not_found, formats: [:html]
  end
end
