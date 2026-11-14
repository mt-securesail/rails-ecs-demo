class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
  end

  # DELIBERATELY VULNERABLE (section 13a exercise): introduced on purpose to
  # test a bug that current security tools won't catch. Merged and deployed
  # briefly on purpose, then removed in the follow-up PR. Do not copy.
  # Information exposure (CWE-200): an unlinked page that returns every
  # environment variable, including SECRET_KEY_BASE.
  def diagnostics
    render json: ENV.to_h
  end
end
