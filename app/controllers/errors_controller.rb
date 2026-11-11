class ErrorsController < ApplicationController
  # CSRF protection stays on (CodeQL blocks turning it off). A POST/PUT/DELETE
  # to an unknown path without a valid token would otherwise raise an error, so
  # answer it with the same 404 page instead.
  rescue_from ActionController::InvalidAuthenticityToken, with: :not_found

  def not_found
    render :not_found, status: :not_found, formats: [:html]
  end
end
