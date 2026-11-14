require "test_helper"
require "yaml"

# Regression guard for finding #5: two deploys ran at once, ECS replaced the first
# deployment mid-rollout, and that run failed. cd.yml must run one deploy at a
# time, queueing newer pushes instead of cancelling the one in progress.
class DeployConcurrencyTest < ActiveSupport::TestCase
  test "cd.yml runs one deploy at a time without cancelling a running one" do
    workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/cd.yml"), aliases: true)
    concurrency = workflow["concurrency"]

    assert_kind_of Hash, concurrency, "cd.yml needs a top-level `concurrency:` block with a fixed group"
    assert_predicate concurrency["group"].to_s.strip, :present?, "cd.yml `concurrency.group` is empty"
    refute_match(/\$\{\{/, concurrency["group"].to_s,
      "cd.yml `concurrency.group` must be a fixed name, so every deploy shares it")
    assert_equal false, concurrency["cancel-in-progress"],
      "cd.yml must set `cancel-in-progress: false` (cancelling mid-deploy leaves ECS half rolled out)"
  end
end
