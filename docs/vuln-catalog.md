# Vulnerability catalog

Deliberately injected vulnerabilities (each on its own unmerged branch), and which tool detected them.
Fill in "Missed by" whenever a tool stays silent. The misses are the most valuable output.

| # | Vulnerability | Where | Branch | Detected by (rule name) | Missed by | Fix / regression check |
|---|---|---|---|---|---|---|
| 1 | Code injection: `eval(params[:expr])` | `app/controllers/home_controller.rb` | `vuln/eval-test` (deleted) | Brakeman ("Parameter value evaluated as code"); CodeQL ("Code injection") | none | Autofix suggestion; tests in `home_controller_test.rb` and `test/security/no_dynamic_eval_test.rb` |
| 2 | Outdated gem with known CVEs: `rubyzip` 1.2.1 (GHSA-vqcq-mrmw-mcmg critical, GHSA-47m2-wp7j-p9vc high, GHSA-5m2v-hc64-56h6 moderate) | `Gemfile` / `Gemfile.lock` | `vuln/outdated-gem` (deleted), PR #10 closed unmerged | Dependency Review (`dependency-review` job failed and posted a PR comment listing all 3 advisories; the `protect-main` ruleset blocked the merge) | Brakeman, CodeQL (they analyze code, not dependency versions). Dependabot didn't react: it only watches `main`, which the gem never reached | `dependency-review` is a required check in `protect-main` (`fail-on-severity: low`) |
