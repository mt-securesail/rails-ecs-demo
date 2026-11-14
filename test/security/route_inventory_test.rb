require "test_helper"

# Regression guard for finding #24: an unlinked /diagnostics page shipped
# because nothing knew which routes the app should have. Every route must be
# listed here with its purpose. Adding an endpoint fails CI until someone
# adds it to this list on purpose, which makes new endpoints visible in review.
class RouteInventoryTest < ActiveSupport::TestCase
  APPROVED = {
    "GET /up(.:format)" => "rails/health#show: health check for the ALB and deploys",
    "GET /" => "home#index: home page",
    "* /*unmatched" => "errors#not_found: 404 page with security headers (must stay last)"
  }.freeze

  def current_routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next if path.start_with?("/rails/") && !path.start_with?("/rails/health") # framework internals
      verb = route.verb.presence || "*"
      "#{verb} #{path}"
    end.uniq
  end

  test "every route is in the approved inventory" do
    unlisted = current_routes - APPROVED.keys

    assert_empty unlisted,
      "New route(s) not in the inventory. Check they are meant to be public, then add them " \
      "to APPROVED in test/security/route_inventory_test.rb with their purpose:\n#{unlisted.join("\n")}"
  end

  test "every approved route still exists" do
    missing = APPROVED.keys - current_routes

    assert_empty missing, "Remove these from APPROVED; they no longer exist:\n#{missing.join("\n")}"
  end
end
