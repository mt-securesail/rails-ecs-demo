# Project context for Claude

This is a learning project: a small Rails app deployed to AWS ECS Fargate by GitHub Actions, used to
practice secure-SDLC tooling (secret scanning, CodeQL, Brakeman, Dependabot, and more). The full plan is in
`docs/DEPLOYMENT_GUIDE.md`. Read it at the start of a session and follow its section order.

## How to talk to me

- Always say exactly where an instruction applies: the **AWS Management Console** (browser), the **GitHub website**,
  the **Stripe dashboard**, the **VS Code terminal**, or the **Claude Code panel**. Never just say "the console".
- Be concise.

## Safety rules

- Never push to `main` or merge a PR without asking me first. Pushes to `main` deploy to production.
- Never run `terraform apply` or `terraform destroy` without showing me the plan and getting a clear yes.
- Do all experiments (including deliberately vulnerable code) on a new branch, and never merge them.
- Never put real secrets, keys, or tokens in files, commits, or prompts. Use clearly fake random values for
  secret-scanning tests. This repo is **public**.
- Warn me before any command that discards uncommitted work (for example `git reset --hard`).

## Facts about this setup

- GitHub repo: `mt-securesail/rails-ecs-demo` (public). Default branch: `main`.
- AWS region: `us-east-1`. Cluster `rails-ecs-demo-cluster`, service `rails-ecs-demo-service`.
- Infrastructure is Terraform in `infra/`, with state stored locally. `terraform.tfvars` and state files are gitignored.
- CI (`.github/workflows/ci.yml`) runs tests and Brakeman. CD (`.github/workflows/cd.yml`) deploys on push to `main`
  using GitHub OIDC (no stored AWS keys).
- The GitHub OIDC trust policy uses the repo's immutable subject prefix (`github_oidc_sub_prefix` in `terraform.tfvars`).
