class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
  end

  # DELIBERATELY VULNERABLE (section 13, vuln catalog): OS command injection,
  # CWE-78. ?host=example.com;id runs any shell command. Never merge.
  def lookup
    output = `nslookup #{params[:host]}`
    render plain: output
  end
end
