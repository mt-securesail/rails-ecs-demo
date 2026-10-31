# Deploy this app to AWS, then break it on purpose (safely)

This guide takes you from an empty GitHub account to: a Rails app running on AWS ECS Fargate,
deployed automatically by GitHub Actions every time you push to `main`, with GitHub's security
scanners watching the code. Then it walks you through deliberately committing a fake secret so
you can watch Secret Scanning and Push Protection catch it, and shows you where to find CodeQL
and Brakeman findings.

Do the steps in order — later steps assume earlier ones are done.

## Roadmap

**Part A — Build the pipeline and meet the scanners (sections 1-9)**
Prerequisites, repo, Terraform/AWS, GitHub Actions OIDC, first deploy, secret scanning /
push protection / CodeQL / Brakeman, and one fake-secret experiment.

**Part B — Close the loop (sections 10-15)**
10. Limit exposure before adding vulnerabilities (lock the ALB to your IP, gate deploys on CI)
11. Widen detection: dependencies, container, Terraform, and a running-app (DAST) scan
12. The feedback loop: every finding becomes a regression test or rule that gates future deploys
13. Inject vulnerabilities on purpose and record which tool catches which class
14. Add an open-weight model as an extra reviewer (static code + running app)
15. Measure results and iterate

**Part C — User accounts and login (sections 16-21)**
16. Foundations: database, HTTPS and a domain, email, secrets
17. Email + password signup (name, email, password)
18. Passkey login
19. Okta single sign-on
20. Security testing for authentication
21. Opening signups to the public (or deciding not to)

**Part D — The weather-prep email product and billing (sections 22-27)**
22. Product definition and data model
23. Weather data and report logic
24. Scheduled email delivery
25. Subscription billing with Stripe (test mode first)
26. Security testing for email and billing
27. Going live (optional)

Section 28 is teardown.

---

## 0. What you'll end up with

- A GitHub repo containing a small Rails app, a Dockerfile, Terraform for the AWS infra, and
  two GitHub Actions workflows (CI: tests + Brakeman; CD: build/push/deploy to ECS).
- **The repo should be public.** GitHub's secret scanning, push protection, and CodeQL code
  scanning are all free on public repos. On private repos they require a paid GitHub Advanced
  Security / Secret Protection license. Since this is a throwaway learning project with no real
  business logic, public is the right (and free) choice — just never put a real credential in it.
- AWS: an ECR image repository, an ECS Fargate cluster/service running the app, and an
  Application Load Balancer giving you a public URL.
- GitHub Actions authenticates to AWS via OIDC (a short-lived, federated identity) — there is no
  AWS access key or secret key stored in GitHub at any point.

---

## 1. Prerequisites

Install locally (macOS example with Homebrew — adjust for your OS):

```bash
brew install git gh awscli terraform
brew install --cask docker   # Docker Desktop, for building images locally
```

Also install Ruby via a version manager (don't use the system Ruby for development):

```bash
brew install rbenv
rbenv install 3.2.4
rbenv local 3.2.4   # run this inside the project folder later
```

Accounts you need:

- A **GitHub account**. Run `gh auth login` once you have the CLI installed.
- An **AWS account**, plus an IAM user (or SSO profile) with enough permissions to create IAM
  roles, an OIDC provider, ECR/ECS/ALB resources. For a personal learning account, attaching the
  `AdministratorAccess` policy to your own IAM user is the path of least resistance. Run
  `aws configure` (or `aws sso login`) so the AWS CLI and Terraform can use those credentials
  **from your machine** — this is separate from, and unrelated to, the credentials GitHub Actions
  will use later.

You should already have this project folder (`rails-ecs-demo/`) that Claude created for you,
containing the app, `Dockerfile`, `infra/`, and `.github/workflows/`.

---

## 2. Create the GitHub repo and push the code

```bash
cd rails-ecs-demo
git init
git add .
git commit -m "Initial commit: minimal Rails app + ECS deploy pipeline"

# Create a PUBLIC repo under your account and push in one step:
gh repo create rails-ecs-demo --public --source=. --remote=origin --push
```

If you'd rather click through the UI instead of using `gh`: go to github.com → **New repository**
→ name it `rails-ecs-demo` → **Public** → create it without a README (you already have one) → then
follow the "push an existing repository" instructions it shows you.

Generate the missing `Gemfile.lock` locally (needs Ruby/Bundler from step 1) and commit it —
Docker and CI both expect it to exist:

```bash
gem install bundler
bundle install
git add Gemfile.lock
git commit -m "Add Gemfile.lock"
git push
```

---

## 3. Provision the AWS infrastructure with Terraform

This step uses **your local AWS credentials** (from `aws configure` in step 1), run from your
own machine — not GitHub Actions.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set github_org to your GitHub username,
# github_repo to "rails-ecs-demo" (or whatever you named it)

terraform init
terraform apply -var="secret_key_base=$(openssl rand -hex 64)"
```

Type `yes` when prompted. This creates: an ECR repo, an ECS cluster/service/task definition
(pointing at a placeholder image for now — that's expected and fine), an ALB, a CloudWatch log
group, an SSM parameter holding `SECRET_KEY_BASE` as a SecureString, and the IAM roles including
the GitHub OIDC deploy role.

When it finishes, capture the outputs:

```bash
terraform output
```

You'll need `alb_dns_name`, `ecr_repository_url`, `github_deploy_role_arn`, `ecs_cluster_name`,
`ecs_service_name`, and `ecs_task_family` in the next step. (If you visit the ALB DNS name right
now, you'll get an error — no real image has been deployed yet. That's expected until step 5.)

---

## 4. Wire GitHub Actions to AWS

In your repo on GitHub: **Settings → Secrets and variables → Actions → Variables tab** (use
*Variables*, not *Secrets* — none of these values are sensitive; the whole point of OIDC is that
there's no key to protect). Add:

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` (or whatever you set) |
| `AWS_DEPLOY_ROLE_ARN` | the `github_deploy_role_arn` output |
| `ECR_REPOSITORY` | the repo name portion of `ecr_repository_url` (e.g. `rails-ecs-demo`) |
| `ECS_CLUSTER` | the `ecs_cluster_name` output |
| `ECS_SERVICE` | the `ecs_service_name` output |
| `ECS_TASK_DEFINITION_FAMILY` | the `ecs_task_family` output |
| `CONTAINER_NAME` | `app` |

Nothing goes in the *Secrets* tab for this pipeline — that's a deliberate design choice worth
noticing: OIDC removed the need for a long-lived AWS key sitting in GitHub.

---

## 5. First deploy

Push anything to `main` (even a trivial change) to trigger `.github/workflows/cd.yml`:

```bash
cd ..   # back to repo root
echo "" >> README.md
git add README.md
git commit -m "Trigger first deploy"
git push
```

Watch it run under the **Actions** tab on GitHub. It builds the Docker image, pushes it to ECR,
registers a new ECS task definition revision with the real image, and updates the service. Once
it's green, visit `http://<alb_dns_name>` (the load balancer is HTTP-only in this demo, no TLS
cert configured) — you should see the Rails homepage with a version string matching your commit
SHA.

---

## 6. Turn on GitHub's security features

In your repo: **Settings → Code security**.

- **Secret scanning**: turn it on. **Push protection**: turn it on too — this is the one that
  blocks a `git push` server-side, before the secret ever lands in GitHub, if it matches a known
  pattern (AWS keys, Stripe keys, Slack tokens, etc.).
- **Dependabot alerts** and **Dependabot security updates**: turn both on — free on every repo,
  public or private, and will flag known-vulnerable versions of `rails`/`puma` if any come up.
- **Code scanning → CodeQL analysis**: click **Set up → Default**. GitHub will detect Ruby and
  configure a managed CodeQL workflow for you — you don't need to write or maintain the workflow
  YAML yourself. (Don't also add a hand-written `codeql.yml` — GitHub won't let default setup and
  an advanced/manual workflow run at the same time.)

This is the one part of this project that only exists as UI clicks, no file to hand you — that's
intentional, since you said you wanted the GitHub-native experience.

---

## 7. Commit a secret on purpose

**Use a fake value, not a real one.** GitHub's detectors are pattern-based for most providers, so
a syntactically valid-looking but made-up value triggers the same alert as a real leaked one,
with none of the risk. The AWS Access Key ID pattern is one of the most reliably detected:

```bash
git checkout -b test/secret-scanning

cat >> config/initializers/oops.rb <<'EOF'
# DELIBERATELY FAKE — for testing GitHub secret scanning. Not a real credential.
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
EOF

git add config/initializers/oops.rb
git commit -m "Testing secret scanning (fake credential, do not use)"
git push -u origin test/secret-scanning
```

(Those exact values are AWS's own long-published documentation example keys — recognizable as
fake, but they still match the real pattern, which is all detection needs.)

What to expect:

- **If push protection is on**, the `git push` itself gets rejected in your terminal with a
  message identifying the secret and a link to allow the push anyway (for cases where the finding
  is a false positive). You can follow that link and choose "allow" to see the alert land in
  GitHub afterward, or swap the value for something that doesn't match a known pattern if you'd
  rather see push protection *stop* it and leave it at that.
- **If it gets through** (or you allowed it), open a pull request from `test/secret-scanning` —
  you should see a check/annotation about the detected secret, and it'll also show up under
  **Security → Secret scanning alerts** in the repo.

Clean up afterward: close the PR without merging, delete the branch, and resolve the alert in the
Security tab (mark it "Revoked" or "False positive" — either is fine here since it's not real).

---

## 8. Review Brakeman and CodeQL findings

Both land in the same place: **Security → Code scanning**.

- Brakeman results show up tagged with the `brakeman` category (it runs in `ci.yml` on every PR
  and push to `main`, uploading SARIF).
- CodeQL results show up separately, produced by the default-setup workflow you enabled in step 6.

This minimal app won't have much for either to flag out of the box. To see them catch something
real, try adding an obviously unsafe pattern on a branch, e.g. in `app/controllers/home_controller.rb`:

```ruby
def index
  @app_version = ENV.fetch("APP_VERSION", "dev")
  @result = eval(params[:expr]) if params[:expr]   # intentionally unsafe, for demo only
end
```

Push that on a branch and open a PR — Brakeman should flag the `eval` call (remote code
execution risk) as a code scanning alert on the PR. Revert it afterward; don't merge it.

---

## 9. The normal dev loop, going forward

1. Branch, make a change, commit, push, open a PR.
2. CI runs tests + Brakeman on the PR; CodeQL's default-setup workflow runs too.
3. Merge to `main`.
4. CD workflow builds, pushes, and deploys automatically — no manual `terraform apply` needed for
   app changes. You only re-run Terraform when you change the *infrastructure* (`infra/*.tf`).

---

---

# Part B — Close the loop

## 10. Limit exposure before adding vulnerabilities

You're about to put deliberately flawed code near an internet-facing AWS endpoint. Two controls first:

1. **Lock the ALB to your own IP.** Add a variable (e.g. `allowed_cidr`, set to your public IP as
   `x.x.x.x/32`) and use it instead of `0.0.0.0/0` in the ALB security group in
   `infra/networking.tf`. Re-run `terraform apply`. Your home IP changes occasionally; update it when it does.
2. **Make CI a gate.** In the repo: **Settings → Rules → Rulesets** (or Branch protection) → protect
   `main`: require a pull request, require the `test` and `brakeman` checks (and later the other
   scanners) to pass, and block force-pushes. Vulnerable code should only ever reach `main` if you
   are deliberately testing that a gate *fails to stop it*, and in that case tear the ALB rule
   open to nobody but you.

Vulnerable variants live on branches/PRs and are never merged unless that is the specific experiment.

## 11. Widen detection

Add these one at a time, each in its own PR, so you can see exactly what each adds:

| Layer | Tool | Where it runs |
|---|---|---|
| Dependencies | Dependabot alerts + the Dependency Review action on PRs | GitHub |
| Code (SAST) | CodeQL (already on) + Brakeman (already on) | GitHub Actions |
| Container image | Trivy in CI, plus Amazon Inspector enhanced scanning on ECR | Actions / AWS |
| Terraform (IaC) | Checkov or Trivy config scan | Actions |
| Workflow files | CodeQL for GitHub Actions workflows, plus pinning actions to SHAs | GitHub |
| Running app (DAST) | OWASP ZAP baseline scan against the ALB URL, run after deploy | Actions |
| AWS runtime/posture | GuardDuty, Security Hub, IAM Access Analyzer (optional, small cost) | AWS |

Upload SARIF from each tool to code scanning where it supports it, so all findings land in
**Security → Code scanning** with a distinct `category`.

## 12. The feedback loop

GitHub doesn't turn a finding into a test automatically; you do that step, and the pipeline then
enforces it. For every finding (from any scanner or from the model in section 14):

1. **Root-cause it**: which class of mistake is this (unsanitized input into `eval`, missing auth
   check, unpinned dependency, over-broad IAM, ...)?
2. **Fix it** on a branch.
3. **Encode it as a regression check**, in order of preference:
   - a unit/integration test that asserts the safe behavior (e.g. request with a malicious param is rejected)
   - a custom rule (Semgrep rule or CodeQL query) that matches the pattern anywhere in the codebase
   - a Brakeman/Checkov/Trivy config tightening (fail on that check, remove it from ignore lists)
4. **Make it required**: add the check to the ruleset from section 10.
5. **Log it** in `docs/findings-log.md`: finding, root cause, fix, test/rule added, PR link.

Next iteration of the code cannot deploy unless that check passes. The CD workflow should also
`needs:` the CI jobs, or deploy only on `main` after the ruleset has enforced them.

Copilot Autofix can suggest fixes for code scanning alerts; check current availability for public repos.

## 13. Inject vulnerabilities on purpose

Keep a catalog in `docs/vuln-catalog.md` with one row per vulnerability, each on its own branch
(`vuln/<name>`) and PR that you never merge. Suggested starting set:

| Vulnerability | Where | Expected detector |
|---|---|---|
| `eval` / command injection on a param | Rails controller | Brakeman, CodeQL |
| XSS via `html_safe` / `raw` on user input | view | Brakeman, CodeQL |
| Unsafe redirect (`redirect_to params[:url]`) | controller | Brakeman |
| Hardcoded API key | any file | Secret scanning, push protection |
| Outdated gem with known CVE | Gemfile.lock | Dependabot, Dependency Review, Trivy |
| Container runs as root / `latest` base tag | Dockerfile | Trivy, Inspector |
| Security group open to `0.0.0.0/0` on the task port, IAM `*:*` | Terraform | Checkov |
| Script injection (`${{ github.event.pull_request.title }}` in a `run:` step) | workflow | CodeQL for Actions |
| Missing security headers / info disclosure | running app | ZAP baseline |

Add a "Detected by" and "Missed by" column, filled in after each run. The misses are the most
valuable output of the whole project: they show which class of flaw each tool cannot see.

## 14. Open-weight model as an extra reviewer

Goal: a model you run yourself reviews (a) the source and (b) the running app, and its findings
feed the same loop as section 12.

- **Run it locally** (e.g. Ollama or llama.cpp on your Mac) so the code never goes to a third party.
  A MacBook Air limits you to smaller code-capable models (roughly 7B-14B parameters); check which
  current open-weight coder models fit your RAM.
- **Static review**: a script (`scripts/llm_review.py`) walks `app/`, `config/`, `Dockerfile`, `infra/`,
  `.github/workflows/`, sends each file with a fixed review prompt, and writes structured output
  (file, line, class of issue, rationale) as JSON, optionally converted to SARIF to upload to code scanning.
- **Running-app review**: give the model the ZAP report and raw HTTP responses (headers, error pages)
  from the deployed app, and ask it to identify weaknesses and suggest requests to probe them.
  Only probe your own ALB, locked to your IP.
- **Treat output as advisory**: expect false positives and misses. Never auto-merge or auto-gate on model
  output; a human triages, and confirmed findings go through the section 12 loop to become deterministic tests.
- **Prompt-injection caution**: code under review can contain text aimed at the model ("ignore previous
  instructions"). Run the reviewer with no tools, no network, and no write access.
- **Score it** against the section 13 catalog: what it caught that scanners missed, what it missed,
  and its false-positive rate.

## 15. Measure and iterate

Once the catalog has been run end to end, summarize: detection rate per tool, per vulnerability
class; time from commit to detection; which findings became permanent tests. Pick the biggest
gaps, add or tune a control, then re-run the catalog to confirm the gap closed.

---

# Part C — User accounts and login

Do this after Part B is working, because it adds a lot of attack surface (and a lot of
material for the vulnerability catalog). Every item here should go through the same loop:
build on a branch, PR, CI gates, deploy, then test it with the scanners and the model.

## 16. Foundations

Authentication needs things the app doesn't have yet:

- **A database.** Today the app has none. Add Active Record and a managed Postgres database
  (Amazon RDS) in private subnets, reachable only from the app's security group. Terraform
  creates it; credentials live in AWS Secrets Manager, injected into the task like
  `SECRET_KEY_BASE` is now. Add a migration step to the deploy workflow (a one-off ECS task
  that runs `db:migrate` before the service update). RDS adds a monthly cost.
- **HTTPS and a domain.** Passkeys (WebAuthn) require HTTPS and are bound to your domain name,
  and Okta requires HTTPS callback URLs. Register or use a domain, add a Route 53 hosted zone,
  an ACM certificate, an HTTPS listener on the ALB, and redirect HTTP to HTTPS. Set
  `force_ssl` in production and use secure cookies.
- **Email.** Signup verification and password reset need outbound email (Amazon SES, with your
  domain verified; new SES accounts start in a sandbox that only sends to verified addresses).
- **A private network layout.** Move the app tasks to private subnets behind a NAT gateway or VPC endpoints,
  rather than the default VPC with public IPs. This also adds cost.

## 17. Email + password signup

Collect only name, email, and password. Rails 8's built-in authentication generator is the
simplest starting point; Devise is the common alternative.

- Store passwords only as strong salted hashes (`has_secure_password` with bcrypt). Never log them
  (the parameter filter in `config/initializers/filter_parameter_logging.rb` already helps).
- Password policy: favor length over complexity rules, and reject known-breached passwords.
- Verify email ownership before the account is usable.
- Use identical responses for "unknown email" and "wrong password" and for "email already registered",
  to avoid user enumeration. Rate-limit signup, login, and reset (Rack::Attack, plus AWS WAF later).
- Password reset: single-use, short-lived tokens, invalidated after use or password change.
- Sessions: secure and HTTP-only cookies, session expiry, regenerate the session on login, CSRF protection on.
- Bot control on the signup form (rate limits first; CAPTCHA only if needed).

## 18. Passkey login

- Add WebAuthn support with the `webauthn-ruby` gem. Set the relying party ID to your domain.
- Store each credential's public key, credential ID, and signature counter per user. Never store private keys
  (they never leave the user's device).
- Build the two flows: registration (after signing in some other way) and authentication, both with a
  server-generated, single-use challenge.
- Plan account recovery up front (a second passkey, recovery codes, or a verified email flow). Recovery is
  usually the weakest link, so test it hard.

## 19. Okta single sign-on

- Create an Okta developer tenant (a free developer tenant is available) and an OIDC web app
  integration with your HTTPS callback URL.
- Integrate with `omniauth_openid_connect` (or SAML if you prefer). Use the authorization code flow
  with PKCE, validate `state` and `nonce`, and verify the token's issuer, audience, and signature.
- Store the Okta client secret in Secrets Manager, never in the repo. This is also a realistic place to
  rehearse a leak and see secret scanning respond.
- Decide the account-linking rule explicitly: never auto-link an Okta login to an existing local
  account based on an unverified email address (a classic account takeover bug).
- Use only the allowed callback URLs in Okta, and test with Okta test users.

## 20. Security testing for authentication

Add these to the vulnerability catalog (section 13) and run them through the detection matrix:

| Vulnerability | Expected detector |
|---|---|
| Missing authorization check (user A reads user B's data) | Tests/DAST, maybe the model |
| User enumeration via different login or signup responses | DAST, tests |
| No rate limiting or lockout on login | Tests/DAST |
| Weak or reusable reset tokens | Tests, code review, the model |
| Session fixation, cookies missing `Secure`/`HttpOnly` | Brakeman, ZAP |
| Open redirect after login (`redirect_to params[:next]`) | Brakeman, CodeQL |
| OIDC without `state`/`nonce`/audience checks | The model, code review |
| Auto-linking on unverified email | The model, tests |
| Hardcoded Okta client secret | Secret scanning (try an Okta-style token) |

Run ZAP with an authenticated session (a test user) so it can see pages behind login. Turn every
confirmed finding into a regression test (section 12): for example, tests asserting identical
responses for known and unknown emails, that a second user can't fetch the first user's record, and that
the 11th rapid login attempt is rejected.

## 21. Opening signups to the public (or deciding not to)

Public signups mean you hold real people's emails and password hashes. Do this only when you're comfortable:

- Before opening up: HTTPS only, AWS WAF with rate-based rules on the ALB, logging and alarms
  (CloudWatch, GuardDuty), encrypted RDS with automated backups, and the whole catalog re-run.
- Consider a privacy notice, a data-retention rule, and an account-deletion path.
- Remember that section 10 locked the ALB to your IP. Opening signups reverses that. Keep a separate,
  locked-down environment for vulnerable-code experiments, or stop injecting vulnerabilities into anything
  that stores real user data.
- A lower-risk alternative: keep the app restricted to your IP and use only test accounts and Okta test users.
  You'll learn nearly the same thing without holding anyone else's data.

---

# Part D — The weather-prep email product and billing

This is the "real app" the earlier parts protect. It depends on Part C (accounts, database, HTTPS, SES
email). Build and test everything with Stripe in test mode and your own email address; no real money or
real customers are needed to learn the whole flow.

## 22. Product definition and data model

- **The product:** a subscriber gets one email each morning: bring an umbrella if rain is likely, wear
  sunscreen if UV is high, or neither. Keep it to those two rules at first.
- **What to store per user:** email (from Part C), location (a ZIP/postal code or city, converted to
  coordinates), time zone, preferred send time, subscription status, and the Stripe customer ID. Location is
  personal data: collect the minimum (a ZIP code is enough) and treat it as sensitive.
- **Entitlement rule:** an email is sent only if the user's subscription is `active` (or in a grace period you
  choose). The app's own database, updated by Stripe webhooks, is the source of truth for that.

## 23. Weather data and report logic

- Pick a forecast API. The US National Weather Service API (`api.weather.gov`) needs no key and covers the US.
  Open-Meteo is another no-key option with a UV index field. Check each one's terms before using it in
  anything commercial, and set a descriptive User-Agent if required. Paid APIs (such as OpenWeather) need an
  API key, which belongs in Secrets Manager, never in the repo.
- Rules to start with: umbrella if the precipitation probability for the morning commute window is at or above a
  threshold (for example 40%); sunscreen if the forecast UV index is at or above 6. Make both thresholds
  configuration, and write unit tests for each rule and for the boundaries.
- Treat the weather API as untrusted input: validate what comes back, set timeouts, handle outages (send nothing
  or a clear "forecast unavailable" message rather than failing silently), and cache results per location.

## 24. Scheduled email delivery

- Use **Amazon EventBridge Scheduler** to trigger a job (an ECS scheduled task or a Lambda function) on a
  schedule, for example every 15 minutes. Each run finds subscribers whose local send time has arrived and who
  haven't been emailed today, builds each report, and sends it with Amazon SES.
- Make sends idempotent: record "sent on date X for user Y" before or atomically with sending, so a retry never
  emails someone twice.
- Email compliance: include an unsubscribe link (and a `List-Unsubscribe` header), a physical or contact address
  as required by anti-spam law in your region, and handle SES bounces and complaints (SNS notifications) by
  suppressing those addresses.
- Use the least-privilege IAM role for the job: send via SES from your verified domain, read only its own secrets,
  and nothing else. This is another good target for the IAM scanners from section 11.

## 25. Subscription billing with Stripe (test mode first)

**Setting up Stripe.** Create an account at stripe.com. You can build and test the whole flow in **test mode**
(Stripe also offers isolated sandboxes) without activating the account, entering business details, or linking a
bank account. In test mode, no real card is charged. Do the following in the Stripe dashboard:

1. Create a **Product** ("Daily Weather Prep") with a recurring **Price** (for example monthly).
2. Note your two API keys: a **publishable key** (safe to expose in browser code) and a **secret key** (server-side only).
3. Configure the **Customer Portal** so subscribers can update their card, cancel, and see invoices.
4. Add a **webhook endpoint** pointing at your app's HTTPS URL; Stripe gives you a **webhook signing secret**.

**Design.**

- Use **Stripe Checkout** (Stripe's hosted payment page) to start a subscription, and the **Customer Portal** for
  self-service. Your servers never see card numbers, which keeps your PCI scope minimal. Never build your own card form
  that posts card numbers to your server.
- The server creates the Checkout Session using the **price ID that your server chooses**, never an amount or price
  sent from the browser.
- Handle webhooks, at least: `checkout.session.completed`, `customer.subscription.updated`,
  `customer.subscription.deleted`, and `invoice.payment_failed`. **Verify the signature** on every webhook using the
  signing secret, ignore events you don't expect, and process each event ID only once (store processed IDs).
- Update the user's subscription status in your database only from verified webhooks, not from the browser's
  "success" redirect.
- Local testing: use the Stripe CLI to forward webhooks to your laptop. Test with Stripe's published test card numbers
  (the standard success card is 4242 4242 4242 4242 with any future expiry and any CVC) and their failure-case cards.
- Keys: put the secret key and the webhook signing secret in AWS Secrets Manager and inject them into the task like other
  secrets. Keep test and live keys strictly separate.
- Secret scanning: Stripe is a supported secret-scanning provider, so a Stripe secret key pushed to a public repo is exactly
  what push protection is built to catch. For the experiment, use a randomly generated fake key shaped like one
  (the same technique as section 7), never a real key, test or live. If a real Stripe key ever leaks, roll it in the
  dashboard immediately.

**Alternatives.** A merchant-of-record service (Paddle, Lemon Squeezy) handles sales tax and compliance for you,
at a different fee structure. Stripe is the most common choice for learning the mechanics.

## 26. Security testing for email and billing

Add these to the vulnerability catalog (section 13) and run them through the detection matrix and the section 12 loop:

| Vulnerability | Expected detector |
|---|---|
| Webhook endpoint that skips signature verification | Tests, the model, code review |
| Replaying an old webhook event (no idempotency) | Tests |
| Price or amount taken from the request instead of the server | Tests, DAST, the model |
| Granting access from the browser's "success" redirect instead of a webhook | Tests, the model |
| One user reading or changing another user's billing portal session or subscription (IDOR) | Tests, DAST |
| Stripe secret key or weather API key committed to the repo | Secret scanning, push protection |
| Email header injection through user-supplied fields | Brakeman, the model |
| Subscribe/unsubscribe links without tokens (anyone can unsubscribe anyone) | Tests, the model |
| User-supplied location used unsafely in an outbound API request (SSRF-style) | CodeQL, the model |
| Over-broad IAM on the scheduled job | Checkov/Trivy |

Regression tests to add as you fix each one: webhook with a bad signature is rejected, the same event twice causes one
state change, an email is never sent to a canceled or unpaid subscriber, and a tampered price is ignored.

## 27. Going live (optional)

Staying in test mode is a perfectly good end state. If you want to charge a real card later (even just your own):
activate the Stripe account (business or individual details, bank account for payouts, tax information), switch to live
keys held separately in Secrets Manager, review sales-tax obligations, publish a privacy policy and terms of service, and
repeat the security catalog against the live-facing environment. Run a small live charge yourself first, and monitor
failed payments and webhook delivery in the Stripe dashboard.

## 28. Cost control / tearing it down

Running: an ALB (~$16-20/month) + a small Fargate task (roughly a few dollars/month at this size)
+ negligible ECR/CloudWatch storage. Nothing here is free-tier-eligible long-term. When you're
done experimenting:

```bash
cd infra
terraform destroy
```

This removes everything Terraform created. Also delete the GitHub repo (or make it private and
scrub the fake secret from history) if you don't want the test artifacts hanging around publicly.
