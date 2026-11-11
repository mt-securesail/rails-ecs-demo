# --- Production ZAP scan role ---
# The "zap-production" job in .github/workflows/cd.yml uses this role to let
# the GitHub runner through the ALB's IP allow-list for the length of one scan:
# it adds the runner's IP (/32) to the ALB security group, scans, then removes it.
#
# Kept separate from the deploy role so each can do only its own job: this role
# can't deploy, and the deploy role can't open the firewall.

# Trust only workflow runs on main (not pull requests or other branches).
data "aws_iam_policy_document" "github_zap_scan_assume" {
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
      values   = ["${local.github_sub_prefix}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_zap_scan" {
  name                 = "${var.project_name}-github-zap-scan-role"
  assume_role_policy   = data.aws_iam_policy_document.github_zap_scan_assume.json
  max_session_duration = 3600 # the minimum AWS allows
}

# Only add/remove inbound rules on the ALB's security group. Nothing else.
data "aws_iam_policy_document" "github_zap_scan_permissions" {
  statement {
    sid = "OpenAndCloseAlbForScan"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [aws_security_group.alb.arn]
  }
}

resource "aws_iam_role_policy" "github_zap_scan" {
  name   = "${var.project_name}-github-zap-scan-policy"
  role   = aws_iam_role.github_zap_scan.id
  policy = data.aws_iam_policy_document.github_zap_scan_permissions.json
}

output "github_zap_scan_role_arn" {
  value = aws_iam_role.github_zap_scan.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}
