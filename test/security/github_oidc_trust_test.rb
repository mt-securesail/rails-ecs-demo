require "test_helper"

# Regression guard for finding #23: the deploy role trusted every workflow run in
# this repo (StringLike "<prefix>:*"), including pull requests and other branches.
# Trivy's config scan does not flag that, so this test does.
#
# Every IAM trust policy in infra/ that lets GitHub Actions sign in (through the
# GitHub OIDC provider) must limit the token's "sub" claim with StringEquals to
# runs on main, with no wildcards.
#
# One narrow exception: the AI review role (infra/ai_review.tf, guide section 14)
# trusts pull-request runs, because it reviews code before merge. It is allowed
# only in that file, and only while that file grants nothing but
# bedrock:InvokeModel on named models (checked below).
class GithubOidcTrustTest < ActiveSupport::TestCase
  MAIN_ONLY_SUFFIX = ":ref:refs/heads/main".freeze
  PULL_REQUEST_SUFFIX = ":pull_request".freeze
  PULL_REQUEST_TRUST_FILE = "infra/ai_review.tf".freeze
  PULL_REQUEST_ROLE_ACTIONS = ["bedrock:InvokeModel"].freeze
  SUB_CLAIM = "token.actions.githubusercontent.com:sub".freeze
  GITHUB_PROVIDER = "aws_iam_openid_connect_provider.github.arn".freeze

  # Returns [path, line number, block text] for every `condition { ... }` block.
  # Reads line by line because values like "${local.x}" contain braces.
  def condition_blocks
    Dir[Rails.root.join("infra/*.tf")].flat_map do |path|
      blocks = []
      current = nil
      File.readlines(path).each_with_index do |line, index|
        if current
          current[2] << line
          if line.match?(/\A\s*\}\s*\z/)
            blocks << current
            current = nil
          end
        elsif line.match?(/\A\s*condition\s*\{\s*\z/)
          current = [path.sub("#{Rails.root}/", ""), index + 1, +""]
        end
      end
      blocks
    end
  end

  def sub_conditions
    condition_blocks.select { |_, _, text| text.include?(%("#{SUB_CLAIM}")) }
  end

  test "every GitHub OIDC trust policy has a sub condition" do
    trusts = Dir[Rails.root.join("infra/*.tf")].sum { |path| File.read(path).scan(GITHUB_PROVIDER).size }

    assert_operator trusts, :>=, 3, "expected the deploy, ZAP scan and AI review roles to trust the GitHub OIDC provider"
    assert_equal trusts, sub_conditions.size,
      "a policy trusts the GitHub OIDC provider without limiting the sub claim (any repo could use it)"
  end

  test "GitHub OIDC sub conditions allow only runs on main (or PRs for the AI review role)" do
    offenders = sub_conditions.filter_map do |path, line, text|
      suffix = path == PULL_REQUEST_TRUST_FILE ? PULL_REQUEST_SUFFIX : MAIN_ONLY_SUFFIX
      test_op = text[/test\s*=\s*"([^"]+)"/, 1]
      values = text[/values\s*=\s*\[(.*?)\]/m, 1].to_s.scan(/"([^"]*)"/).flatten

      problems = []
      problems << "test is #{test_op.inspect}, must be \"StringEquals\"" unless test_op == "StringEquals"
      problems << "no values" if values.empty?
      values.each do |value|
        problems << "#{value.inspect} contains a wildcard" if value.match?(/[*?]/)
        problems << "#{value.inspect} must end with #{suffix.inspect}" unless value.end_with?(suffix)
      end
      "#{path}:#{line}: #{problems.join('; ')}" if problems.any?
    end

    assert_empty offenders, "GitHub OIDC trust is wider than allowed:\n#{offenders.join("\n")}"
  end

  # A role that pull requests can use must not be able to do anything that
  # matters if a PR's code or workflow is malicious: only call named models.
  test "the PR-trusted AI review role can only invoke named Bedrock models" do
    source = File.read(Rails.root.join(PULL_REQUEST_TRUST_FILE))
    actions = source.scan(/^\s*actions\s*=\s*\[(.*?)\]/m).flatten.flat_map { |list| list.scan(/"([^"]*)"/).flatten }
    resources = source.scan(/^\s*resources\s*=\s*\[(.*?)\]/m).flatten.join

    assert_equal ["sts:AssumeRoleWithWebIdentity", *PULL_REQUEST_ROLE_ACTIONS].sort, actions.uniq.sort,
      "#{PULL_REQUEST_TRUST_FILE} may grant only #{PULL_REQUEST_ROLE_ACTIONS.join(', ')}"
    assert_includes resources, "foundation-model/", "the AI review policy must name the models it allows"
    code = source.lines.map { |line| line.sub(/#.*/, "") }.join
    refute_includes code, "*", "#{PULL_REQUEST_TRUST_FILE} must not use wildcards (in model IDs, ARNs or actions)"
    refute_match(/aws_iam_role_policy_attachment|managed_policy_arns/, source,
      "the AI review role must not get extra (managed) policies")
  end
end
