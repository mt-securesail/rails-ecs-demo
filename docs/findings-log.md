# Findings log

One row per finding: what was found, why, how it was fixed, and what now prevents it from coming back.
Fill in `TODO` items from the alert pages (GitHub website: Security tab).

| # | Date | Finding | Source / severity | Root cause | Fix | Regression check | Link |
|---|---|---|---|---|---|---|---|
| 1 | 2026-10 | AWS example keys containing `EXAMPLE` were not flagged | Secret scanning / push protection; n/a | Scanner ignores documented placeholder values | None needed (expected behavior); note as a detection gap | Test with random, same-shaped fake values instead | n/a |
| 2 | 2026-10 | Random AWS-shaped fake keys blocked at push; bypass created "Public leak" alerts | Push protection / secret scanning; high (if real) | Deliberate test (values not real) | Alerts closed as "used in tests"; test branch deleted | Push protection stays on | n/a |
| 3 | 2026-11 | puma 6.6.1: 2 High Dependabot alerts | Dependabot; High x2 | Outdated web server dependency | Merged PR #1 (puma 7.2.1); deployed and verified app and `/up` | Dependabot security updates stay on | PR #1 |
| 4 | 2026-11 | crass 1.0.7: 1 Moderate Dependabot alert | Dependabot; Moderate | Outdated transitive dependency | Merged PR #2 (crass 1.0.8); deployed and verified | Dependabot security updates stay on | PR #2 |
| 5 | 2026-11 | Overlapping deploys; one run failed ("deployment not found after stabilization") | Pipeline behavior; low | ECS replaces an in-progress deployment when a newer one arrives; no concurrency control | Added `concurrency` group to `.github/workflows/cd.yml` | Deploys now queue one at a time | cd.yml |
| 6 | 2026-11 | Ruby 3.2.4 and Rails 7.2.x end-of-life warnings | Brakeman (code scanning); TODO | Platform versions no longer supported (TODO: end-of-life dates from the alerts) | OPEN: plan a Ruby and Rails upgrade on its own branch | TODO | Security > Code scanning |
