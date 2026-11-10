# Vulnerability catalog

Deliberately injected vulnerabilities (each on its own unmerged branch), and which tool detected them.
Fill in "Missed by" whenever a tool stays silent. The misses are the most valuable output.

| # | Vulnerability | Where | Branch | Detected by (rule name) | Missed by | Fix / regression check |
|---|---|---|---|---|---|---|
| 1 | Code injection: `eval(params[:expr])` | `app/controllers/home_controller.rb` | `vuln/eval-test` (deleted) | Brakeman ("Parameter value evaluated as code"); CodeQL ("Code injection") | none | Autofix suggestion; tests in `home_controller_test.rb` and `test/security/no_dynamic_eval_test.rb` |
| 2 | Outdated gem with known CVEs: `rubyzip` 1.2.1 (GHSA-vqcq-mrmw-mcmg critical, GHSA-47m2-wp7j-p9vc high, GHSA-5m2v-hc64-56h6 moderate) | `Gemfile` / `Gemfile.lock` | `vuln/outdated-gem` (deleted), PR #10 closed unmerged | Dependency Review (`dependency-review` job failed and posted a PR comment listing all 3 advisories; the `protect-main` ruleset blocked the merge) | Brakeman, CodeQL (they analyze code, not dependency versions). Dependabot didn't react: it only watches `main`, which the gem never reached | `dependency-review` is a required check in `protect-main` (`fail-on-severity: low`) |

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
