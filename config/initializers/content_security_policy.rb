# Content Security Policy (CSP): tells the browser which sources this app's
# pages may load content from. Anything not allowed here is blocked, which is
# the main browser-side defense against cross-site scripting (XSS).
# Added for ZAP finding "CSP Header Not Set" [10038]; enforced by
# test/security/security_headers_test.rb and .zap/rules.tsv.
#
# Strict by default: nothing is allowed unless listed. The page's <style> block
# is allowed by a per-request random nonce, so inline style= attributes and
# injected <style>/<script> tags are still blocked.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :none
    policy.script_src      :self
    policy.style_src       :self
    policy.img_src         :self
    policy.font_src        :self
    policy.connect_src     :self
    policy.manifest_src    :self
    policy.object_src      :none
    policy.base_uri        :none
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[style-src]
end
