class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
  end

  # DELIBERATELY VULNERABLE (section 13, vuln catalog): path traversal, CWE-22.
  # ?file=../../../etc/passwd reads any file the app can read. Never merge.
  def download
    send_file Rails.root.join("public", params[:file])
  end
end
