# Vulnerability catalog

Deliberately injected vulnerabilities (each on its own unmerged branch), and which tool detected them.
Fill in "Missed by" whenever a tool stays silent. The misses are the most valuable output.

| # | Vulnerability | Where | Branch | Detected by (rule name) | Missed by | Fix / regression check |
|---|---|---|---|---|---|---|
| 1 | Code injection: `eval(params[:expr])` | `app/controllers/home_controller.rb` | `vuln/eval-test` (deleted) | Brakeman ("Parameter value evaluated as code"); CodeQL ("Code injection") | none | Autofix suggestion; tests in `home_controller_test.rb` and `test/security/no_dynamic_eval_test.rb` |
| 2 | Outdated gem with known CVEs: `rubyzip` 1.2.1 (GHSA-vqcq-mrmw-mcmg critical, GHSA-47m2-wp7j-p9vc high, GHSA-5m2v-hc64-56h6 moderate) | `Gemfile` / `Gemfile.lock` | `vuln/outdated-gem` (deleted), PR #10 closed unmerged | Dependency Review (`dependency-review` job failed and posted a PR comment listing all 3 advisories; the `protect-main` ruleset blocked the merge) | Brakeman, CodeQL (they analyze code, not dependency versions). Dependabot didn't react: it only watches `main`, which the gem never reached | `dependency-review` is a required check in `protect-main` (`fail-on-severity: low`) |
| 3 | Reflected XSS, CWE-79 (2025 CWE Top 25 #1; OWASP Top 10:2025 A05 Injection; CISA Secure by Design alert): `params[:name].html_safe` | `app/views/home/index.html.erb` | `vuln/xss`, PR #27 closed unmerged | Brakeman (`BRAKE0002` Cross-Site Scripting, "Unescaped parameter value", High confidence); CodeQL (`rb/reflected-xss`, high) | ZAP baseline (passive: never sends `?name=<script>`); test suite (no test exercised it); Trivy, Grype, Dependency Review (not code analyzers) | Blocked by the required `brakeman` check. In the browser, the strict CSP (`script-src 'self'`) would also have stopped an injected inline script: a second layer, not a fix |
| 4 | Path traversal, CWE-22 (2025 CWE Top 25 #6; OWASP Top 10:2025 A01 Broken Access Control; CISA Secure by Design alert): `send_file Rails.root.join("public", params[:file])` at `/download` | `app/controllers/home_controller.rb` | `vuln/path-traversal`, PR #28 closed unmerged | Brakeman only: `BRAKE0125` Path Traversal ("Absolute paths in `Pathname#join`…", High) and `BRAKE0016` File Access ("Parameter value used in file name", Weak) | **CodeQL** (no alert; predicted to catch it with `rb/path-injection`); ZAP baseline; test suite; Trivy, Grype | Blocked by the required `brakeman` check (the job fails on any warning, even Weak). Brakeman is the only detector here, so this class depends on one tool |
| 5 | OS command injection, CWE-78 (2025 CWE Top 25 #9; OWASP Top 10:2025 A05 Injection; CISA Secure by Design alert): `` `nslookup #{params[:host]}` `` at `/lookup` | `app/controllers/home_controller.rb` | `vuln/command-injection`, PR #29 closed unmerged | Brakeman (`BRAKE0014` Command Injection, "Possible command injection", High); CodeQL (`rb/command-line-injection`, critical) | ZAP baseline; test suite; Trivy, Grype | Blocked by the required `brakeman` check |

**Rows 3-5 summary (2026-11-14):** chosen because each class is in the 2025 CWE Top 25 and the OWASP Top 10:2025, and has its own CISA Secure by Design alert.
Predictions were written down before the scans ran: Brakeman and CodeQL would catch all three, and ZAP baseline would miss all three.
Brakeman caught 3 of 3, CodeQL 2 of 3 (it missed path traversal), and ZAP baseline 0 of 3, as expected for a passive scan.
No existing test failed, as expected: tests only guard what has already been found (section 12).

## Scanner comparison: Trivy vs Grype (real findings, not planted)

How the two container scanners handled actual findings in the production image (base `ruby:3.4-slim`, Debian 13.7).
Both gates use the same rule: fail on critical or high findings that have a published fix.

| Finding | Severity | Trivy v0.76.1 | Grype v0.121.0 | Notes |
|---|---|---|---|---|
| `zlib1g` CVE-2026-85091 (heap overflow in `gz_vacate()`) | High, fix available | Detected; gate failed (PR #14) | Not tested: fixed before Grype was added | Fixed by `apt-get upgrade` in the Dockerfile |
| `zlib1g` CVE-2026-76844 | High, fix available | Detected, but with the wrong title (describes webpack-dev-middleware) | Not tested | Likely an error in Trivy's database; same fix |
| `json` gem 2.9.1, CVE-2026-54696 / GHSA-x2f5-4prf-w687 (heap overflow when streaming to an IO) | Low, fixed in 2.19.9 | Detected in the unfiltered scan; below the gate and report threshold | Detected (listed in the log as fixable Low); below the gate | Probably the copy bundled with Ruby in the base image, not from `Gemfile.lock`. Neither gate blocks it, by design |
| Rest of the image | Mostly low/medium, no fix | ~1,350 alerts in the unfiltered scan (77 high, 437 medium, 844 low) | Only fixable findings reported (`--only-fixed`) | Why both now report only critical/high with a fix |

**So far:** no disagreement on what exists. The differences are in labeling (Trivy's wrong title) and in default output.
**To test next:** plant a known-vulnerable OS package or an old base image on a `vuln/` branch, and see whether both catch it.
