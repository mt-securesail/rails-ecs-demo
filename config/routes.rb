Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
  get "download" => "home#download" # DELIBERATELY VULNERABLE, never merge

  # Must stay last. Unknown paths get a normal 404 page from a controller, so
  # they carry the same security headers as every other page. (Rails' built-in
  # 404 handling skips them; ZAP flagged that on /robots.txt.)
  match "*unmatched", to: "errors#not_found", via: :all, format: false
end
