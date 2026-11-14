require "test_helper"

# Regression guard for finding #24: checks behavior, not code patterns. Puts a
# fake secret in the environment, requests every page that takes no
# parameters, and fails if the fake secret or the app's secret_key_base
# appears in any response.
class SecretCanaryTest < ActionDispatch::IntegrationTest
  CANARY_NAME = "SECURITY_TEST_CANARY".freeze

  setup do
    @canary = "canary-#{SecureRandom.hex(16)}"
    ENV[CANARY_NAME] = @canary
  end

  teardown { ENV.delete(CANARY_NAME) }

  def plain_get_paths
    Rails.application.routes.routes.filter_map do |route|
      next unless route.verb.to_s.include?("GET")
      path = route.path.spec.to_s.sub("(.:format)", "")
      next if path.match?(/[:*(]/) # needs parameters
      path
    end.uniq
  end

  test "no page reveals secrets" do
    paths = plain_get_paths
    assert_includes paths, "/", "expected the home page in the list of pages"

    leaks = paths.filter_map do |path|
      get path
      found = []
      found << CANARY_NAME if response.body.include?(@canary)
      found << "secret_key_base" if response.body.include?(Rails.application.secret_key_base)
      "#{path}: #{found.join(', ')}" if found.any?
    end

    assert_empty leaks, "secrets in responses:\n#{leaks.join("\n")}"
  end
end
