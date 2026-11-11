# Permissions Policy: turns off browser features this app doesn't use, so
# injected or embedded content can't use them either.
# Added for ZAP finding "Permissions Policy Header Not Set" [10063]; enforced by
# test/security/security_headers_test.rb and .zap/rules.tsv.
#
# Set as a plain header because Rails' built-in permissions_policy DSL sends the
# older, deprecated Feature-Policy header instead.
Rails.application.config.action_dispatch.default_headers.merge!(
  "Permissions-Policy" =>
    "camera=(), microphone=(), geolocation=(), payment=(), usb=(), gyroscope=(), fullscreen=(self)"
)
