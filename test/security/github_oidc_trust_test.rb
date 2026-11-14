require "test_helper"

# Regression guard for finding #23: the deploy role trusted every workflow run in
# this repo (StringLike "<prefix>:*"), including pull requests and other branches.
# Trivy's config scan does not flag that, so this test does.
#
# Every IAM trust policy in infra/ that lets GitHub Actions sign in (through the
# GitHub OIDC provider) must limit the token's "sub" claim with StringEquals to
# runs on main, with no wildcards.
class GithubOidcTrustTest < ActiveSupport::TestCase
  MAIN_ONLY_SUFFIX = ":ref:refs/heads/main".freeze
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

    assert_operator trusts, :>=, 2, "expected the deploy and ZAP scan roles to trust the GitHub OIDC provider"
    assert_equal trusts, sub_conditions.size,
      "a policy trusts the GitHub OIDC provider without limiting the sub claim (any repo could use it)"
  end

  test "GitHub OIDC sub conditions allow only runs on main" do
    offenders = sub_conditions.filter_map do |path, line, text|
      test_op = text[/test\s*=\s*"([^"]+)"/, 1]
      values = text[/values\s*=\s*\[(.*?)\]/m, 1].to_s.scan(/"([^"]*)"/).flatten

      problems = []
      problems << "test is #{test_op.inspect}, must be \"StringEquals\"" unless test_op == "StringEquals"
      problems << "no values" if values.empty?
      values.each do |value|
        problems << "#{value.inspect} contains a wildcard" if value.match?(/[*?]/)
        problems << "#{value.inspect} must end with #{MAIN_ONLY_SUFFIX.inspect}" unless value.end_with?(MAIN_ONLY_SUFFIX)
      end
      "#{path}:#{line}: #{problems.join('; ')}" if problems.any?
    end

    assert_empty offenders, "GitHub OIDC trust is wider than main:\n#{offenders.join("\n")}"
  end
end
