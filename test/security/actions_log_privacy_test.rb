require "test_helper"
require "yaml"

# Regression guard for finding #18: the AWS account ID was printed in this public
# repo's Actions logs. Every AWS sign-in step in a workflow must take its role ARN
# from a secret (shown as ***) and mask the account ID in later log lines.
class ActionsLogPrivacyTest < ActiveSupport::TestCase
  AWS_SIGN_IN = "aws-actions/configure-aws-credentials@".freeze

  def aws_sign_in_steps
    Dir[Rails.root.join(".github/workflows/*.{yml,yaml}")].flat_map do |path|
      workflow = YAML.safe_load_file(path, aliases: true) || {}
      (workflow["jobs"] || {}).flat_map do |job_name, job|
        (job["steps"] || []).filter_map do |step|
          next unless step["uses"].to_s.start_with?(AWS_SIGN_IN)
          ["#{File.basename(path)} / #{job_name} / #{step['name'] || step['uses']}", step["with"] || {}]
        end
      end
    end
  end

  test "workflows have AWS sign-in steps to check" do
    assert_operator aws_sign_in_steps.size, :>=, 2, "expected the deploy and ZAP scan sign-in steps in cd.yml"
  end

  test "every AWS sign-in step masks the account ID" do
    offenders = aws_sign_in_steps.reject { |_, with| with["mask-aws-account-id"] == true }.map(&:first)

    assert_empty offenders, "set `mask-aws-account-id: true` on:\n#{offenders.join("\n")}"
  end

  test "every AWS sign-in step takes its role ARN from a secret" do
    offenders = aws_sign_in_steps.reject { |_, with| with["role-to-assume"].to_s.match?(/\A\$\{\{\s*secrets\.\w+\s*\}\}\z/) }.map(&:first)

    assert_empty offenders, "role-to-assume must be `${{ secrets.NAME }}` (variables are printed in public logs):\n#{offenders.join("\n")}"
  end
end
