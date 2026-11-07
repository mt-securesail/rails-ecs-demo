# Vulnerability catalog

Deliberately injected vulnerabilities (each on its own unmerged branch), and which tool detected them.
Fill in "Missed by" whenever a tool stays silent. The misses are the most valuable output.

| # | Vulnerability | Where | Branch | Detected by (rule name) | Missed by | Fix / regression check |
|---|---|---|---|---|---|---|
| 1 | Code injection: `eval(params[:expr])` | `app/controllers/home_controller.rb` | `vuln/eval-test` (deleted) | Brakeman ("Parameter value evaluated as code"); CodeQL ("Code injection") | none | Autofix suggestion; tests in `home_controller_test.rb` and `test/security/no_dynamic_eval_test.rb` |
