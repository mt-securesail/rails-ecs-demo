# --- AI code review role (guide section 14) ---
# .github/workflows/ai-review.yml uses this role to send the code in a pull
# request to two open-weight models on Amazon Bedrock for an advisory security
# review. It runs only when the PR has the "ai-review" label.
#
# Unlike the deploy and ZAP scan roles, this role trusts pull-request runs, not
# main, because the review happens before merge. That is safe only because the
# role can do nothing except call the two models below: it can't deploy, read
# secrets, or touch any other AWS resource. The worst case if it were misused is
# Bedrock charges, which the budget alarm below reports.
# test/security/github_oidc_trust_test.rb allows PR trust in this file only, and
# checks that this file grants nothing but bedrock:InvokeModel.
#
# GitHub doesn't issue OIDC tokens to pull requests from forks, so only branches
# pushed to this repo can use the role.

locals {
  # Approved models only. Non-PRC-origin open-weight models (OpenAI, Mistral AI).
  # Both are on-demand in us-east-1. Prices checked 2026-11-14 with the AWS
  # Pricing API; they are copied in .github/scripts/ai_review.py for the cost estimate.
  ai_review_model_ids = [
    "openai.gpt-oss-120b-1:0",               # $0.15 in / $0.60 out per 1M tokens
    "mistral.mistral-large-3-675b-instruct", # $0.50 in / $1.50 out per 1M tokens
  ]
}

# Trust only pull-request runs in this repo.
data "aws_iam_policy_document" "github_ai_review_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_sub_prefix}:pull_request"]
    }
  }
}

resource "aws_iam_role" "github_ai_review" {
  name                 = "${var.project_name}-github-ai-review-role"
  assume_role_policy   = data.aws_iam_policy_document.github_ai_review_assume.json
  max_session_duration = 3600 # the minimum AWS allows
}

# Call the approved models, nothing else. (The Converse API uses this same
# bedrock:InvokeModel permission.)
data "aws_iam_policy_document" "github_ai_review_permissions" {
  statement {
    sid     = "InvokeApprovedModelsOnly"
    actions = ["bedrock:InvokeModel"]
    resources = [
      for id in local.ai_review_model_ids :
      "arn:aws:bedrock:${var.aws_region}::foundation-model/${id}"
    ]
  }
}

resource "aws_iam_role_policy" "github_ai_review" {
  name   = "${var.project_name}-github-ai-review-policy"
  role   = aws_iam_role.github_ai_review.id
  policy = data.aws_iam_policy_document.github_ai_review_permissions.json
}

# Email alerts when Amazon Bedrock spending in this account reaches 80% of the
# monthly limit, or is forecast to pass it. This covers all Bedrock use in the
# account, not just this role. Alerts are emails only; nothing is stopped.
# (The first two budgets in an account are free.)
resource "aws_budgets_budget" "bedrock" {
  name         = "${var.project_name}-bedrock-monthly"
  budget_type  = "COST"
  limit_amount = var.bedrock_monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}

output "github_ai_review_role_arn" {
  value = aws_iam_role.github_ai_review.arn
}
