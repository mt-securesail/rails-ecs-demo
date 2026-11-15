require "test_helper"
require "yaml"

# Guards for the Gitleaks job (findings log #27). Its log is public, it must
# scan every commit in a PR, it must run a verified binary, and a PR must not be
# able to weaken its own scan.
class SecretScanWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = ".github/workflows/secret-scan.yml".freeze

  def job
    YAML.safe_load_file(Rails.root.join(WORKFLOW)).dig("jobs", "gitleaks") or flunk("#{WORKFLOW} has no gitleaks job")
  end

  def scripts
    job["steps"].filter_map { |step| step["run"] }.join("\n")
  end

  test "checks out the full history so every PR commit is scanned" do
    checkout = job["steps"].find { |step| step["uses"].to_s.start_with?("actions/checkout@") }

    assert_equal 0, checkout.dig("with", "fetch-depth"), "fetch-depth must be 0"
    assert_includes scripts, '--log-opts="$BASE_SHA..$HEAD_SHA"', "scan every commit from the base to the PR head"
  end

  test "verifies the Gitleaks download against a pinned checksum" do
    assert_match(/\A\h{64}\z/, job.dig("env", "GITLEAKS_SHA256").to_s, "pin GITLEAKS_SHA256")
    assert_includes scripts, "sha256sum -c"
  end

  test "keeps secret values and commit emails out of the public log" do
    assert_includes scripts, "--redact"
    refute_match(/--verbose|\s-v\b/, scripts, "Gitleaks' verbose output prints the commit author's email")
    refute_match(/\.Email|\.Author|\.Secret|\.Match/, scripts, "print only rule, file, line, commit and fingerprint")
  end

  test "reads its config and ignore list from the base branch, not the PR" do
    assert_includes scripts, 'git show "$BASE_SHA:.gitleaks.toml"'
    assert_includes scripts, 'git show "$BASE_SHA:.gitleaksignore"'
    assert_includes scripts, '--gitleaks-ignore-path "$RUNNER_TEMP/base/.gitleaksignore"'
  end
end
