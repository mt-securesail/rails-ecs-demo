require "test_helper"

# Regression tests for the ZAP baseline findings (docs/findings-log.md).
# Every page, including 404s, must send these headers. These run in the `test`
# job, a required check, so a change that drops or weakens a header can't merge.
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  PAGES = {
    "home page" => ["/", 200],
    "health check" => ["/up", 200],
    "unknown page (404)" => ["/robots.txt", 404]
  }.freeze

  PAGES.each do |name, (path, status)|
    # ZAP [10038] CSP Header Not Set
    test "#{name} sends a strict Content-Security-Policy" do
      get path
      assert_response status
      csp = response.headers["Content-Security-Policy"]
      assert csp.present?, "Content-Security-Policy header is missing"
      assert_includes csp, "default-src 'none'"
      assert_includes csp, "script-src 'self'"
      assert_includes csp, "object-src 'none'"
      assert_includes csp, "base-uri 'none'"
      assert_includes csp, "frame-ancestors 'none'"
      refute_includes csp, "unsafe-inline", "CSP must not allow inline scripts or styles"
      refute_includes csp, "unsafe-eval", "CSP must not allow eval"
      refute_match(/(?:^|\s)\*(?:\s|;|$)/, csp, "CSP must not allow any source (*)")
    end

    # ZAP [10063] Permissions Policy Header Not Set
    test "#{name} sends a Permissions-Policy that disables unused features" do
      get path
      policy = response.headers["Permissions-Policy"]
      assert policy.present?, "Permissions-Policy header is missing"
      %w[camera microphone geolocation payment usb].each do |feature|
        assert_includes policy, "#{feature}=()", "#{feature} should be disabled"
      end
      assert_nil response.headers["Feature-Policy"], "use Permissions-Policy, not the deprecated Feature-Policy"
    end

    # ZAP [90004] Insufficient Site Isolation Against Spectre Vulnerability
    test "#{name} sends cross-origin isolation headers" do
      get path
      assert_equal "require-corp", response.headers["Cross-Origin-Embedder-Policy"]
      assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"]
      assert_equal "same-origin", response.headers["Cross-Origin-Resource-Policy"]
    end

    # ZAP [10049] Non-Storable Content: accepted (see .zap/rules.tsv). This
    # locks in the intended behavior: pages are never stored by shared caches.
    test "#{name} is not cacheable by shared caches" do
      get path
      cache = response.headers["Cache-Control"].to_s
      assert cache.include?("private") || cache.include?("no-store"),
        "Cache-Control should be private or no-store, got: #{cache.inspect}"
    end
  end

  test "home page styles are allowed by the CSP nonce, with no inline style attributes" do
    get "/"
    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    assert nonce.present?, "style-src should include a per-request nonce"
    assert_includes response.body, %(<style nonce="#{nonce}">)
    refute_match(/\sstyle="/, response.body, "inline style= attributes are blocked by the CSP")
  end
end
