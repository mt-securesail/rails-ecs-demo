require "test_helper"

# Regression guard for finding #15: CSRF protection must stay on for every
# controller. CodeQL also checks this on PRs, but Brakeman missed it, and this
# fails fast in the normal test run (the required `test` check).
class CsrfProtectionTest < ActiveSupport::TestCase
  # Ways to switch CSRF protection off or weaken it in code or config.
  FORBIDDEN = [
    /\bskip_forgery_protection\b/,
    /skip_(before_)?action\s*\(?\s*:verify_authenticity_token/,
    /protect_from_forgery[^\n]*with:\s*:(null_session|reset_session)/,
    /allow_forgery_protection\s*=\s*false/,
    /default_protect_from_forgery\s*=\s*false/
  ].freeze

  # The test environment turns CSRF checks off on purpose (Rails default);
  # tests that need them turn them back on.
  ALLOWED_FILES = %w[config/environments/test.rb].freeze

  test "no code or config disables or weakens CSRF protection" do
    files = Dir[Rails.root.join("{app,config,lib}/**/*.rb")]
    offenders = files.flat_map do |path|
      relative = path.sub(Rails.root.to_s + "/", "")
      next [] if ALLOWED_FILES.include?(relative)

      File.readlines(path).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?("#")
        "#{relative}:#{index + 1}: #{line.strip}" if FORBIDDEN.any? { |re| line.match?(re) }
      end
    end

    assert_empty offenders, "CSRF protection disabled or weakened:\n#{offenders.join("\n")}"
  end

  # Checks the loaded app, not just the text: every controller runs the CSRF
  # check on every action, and a bad token raises an error (not a silent
  # fallback). Catches skips written in ways the pattern check above misses.
  test "every controller verifies the CSRF token on every action" do
    Rails.application.eager_load!
    controllers = [ApplicationController, *ApplicationController.descendants]

    controllers.each do |controller|
      check = controller._process_action_callbacks.find { |cb| cb.filter == :verify_authenticity_token }
      assert check, "#{controller} does not verify CSRF tokens"

      conditions = Array(check.instance_variable_get(:@if)) + Array(check.instance_variable_get(:@unless))
      assert_empty conditions, "#{controller} skips the CSRF check for some actions"

      assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
        controller.forgery_protection_strategy,
        "#{controller} should reject bad CSRF tokens with an error"
    end
  end
end
