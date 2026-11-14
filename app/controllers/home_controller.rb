class HomeController < ApplicationController
  def index
    @app_version = ENV.fetch("APP_VERSION", "dev")
  end

  # DELIBERATELY VULNERABLE (section 13, vuln catalog): path traversal, CWE-22.
  # ?file=../../../etc/passwd reads any file the app can read. Never merge.
  def download
    send_file Rails.root.join("public", params[:file])
  end

  # Variants to find out which part CodeQL misses (sink x path building).
  # B: same sink (send_file), path from plain string interpolation.
  def download_b
    send_file "public/#{params[:file]}"
  end

  # C: different sink (File.read), path from Rails.root.join, like the original.
  def download_c
    render plain: File.read(Rails.root.join("public", params[:file]))
  end

  # D: different sink (File.read), path from plain string interpolation.
  def download_d
    render plain: File.read("public/#{params[:file]}")
  end
end
