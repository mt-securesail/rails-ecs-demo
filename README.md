# rails-ecs-demo

A minimal Rails app, deployed to AWS ECS Fargate via GitHub Actions (OIDC, no long-lived AWS keys).
Built as a hands-on sandbox for trying GitHub secret scanning, push protection, CodeQL, and Brakeman.

Full walkthrough: [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md).

## Layout

- `app/`, `config/`, `test/` — the Rails app (no database, no asset pipeline, kept intentionally small)
- `Dockerfile` — container image used for both local runs and ECS
- `infra/` — Terraform for the AWS side (ECR, ECS/Fargate, ALB, IAM incl. GitHub OIDC role)
- `.github/workflows/ci.yml` — tests + Brakeman on every PR
- `.github/workflows/cd.yml` — builds, pushes to ECR, deploys to ECS on every push to `main`

## Local development

```bash
bundle install
bin/rails server
# visit http://localhost:3000
```
