# Cross-origin isolation headers: keep other sites from embedding, opening, or
# reading this app's pages and responses (Spectre-style side-channel defense).
# Added for ZAP finding "Insufficient Site Isolation Against Spectre
# Vulnerability" [90004] (COEP/COOP/CORP missing); enforced by
# test/security/security_headers_test.rb and .zap/rules.tsv.
#
# Safe here because the app loads nothing from other sites. If it ever embeds
# third-party content (e.g. Stripe.js in section 21), revisit these.
Rails.application.config.action_dispatch.default_headers.merge!(
  "Cross-Origin-Embedder-Policy" => "require-corp",
  "Cross-Origin-Opener-Policy" => "same-origin",
  "Cross-Origin-Resource-Policy" => "same-origin"
)
