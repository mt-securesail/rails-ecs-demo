require "test_helper"
require "yaml"

# Exceptions for the AI security review (guide section 14) must be complete,
# logged, and reviewed again before they expire, like the Trivy exceptions in
# .trivyignore.yaml. An expired entry fails this test until someone reviews it.
class AiReviewAcceptedRisksTest < ActiveSupport::TestCase
  FILE = ".github/ai-review/accepted-risks.yml".freeze
  REQUIRED = %w[id title where reason decided_by findings_log expires].freeze
  MAX_DAYS = 366

  def entries
    YAML.safe_load_file(Rails.root.join(FILE)).fetch("accepted") || []
  end

  test "every accepted risk has all the required fields" do
    entries.each do |entry|
      missing = REQUIRED.reject { |key| entry[key].to_s.strip.present? }
      assert_empty missing, "#{FILE}: entry #{entry['id'].inspect} is missing #{missing.join(', ')}"
    end
  end

  test "accepted risk ids are unique and simple" do
    ids = entries.map { |entry| entry["id"].to_s }
    assert_equal ids.uniq, ids, "#{FILE}: duplicate ids"
    ids.each { |id| assert_match(/\A[a-z0-9-]+\z/, id, "#{FILE}: id #{id.inspect} must be lowercase letters, digits and dashes") }
  end

  test "accepted risks have not expired and expire within a year" do
    entries.each do |entry|
      expires = Date.iso8601(entry["expires"].to_s)
      assert_operator expires, :>=, Date.current, "#{FILE}: #{entry['id']} expired on #{expires}; review it again"
      assert_operator expires, :<=, Date.current + MAX_DAYS, "#{FILE}: #{entry['id']} must expire within a year"
    end
  end

  test "every accepted risk points to a row in the findings log" do
    log = File.read(Rails.root.join("docs/findings-log.md"))
    entries.each do |entry|
      assert_match(/^\| #{Integer(entry['findings_log'])} \|/, log, "#{FILE}: #{entry['id']} points to a findings log row that doesn't exist")
    end
  end
end
