require "test_helper"
require "yaml"

# Regression guard for finding #16: a Dependabot PR changed only the Dockerfile's
# Ruby image (3.4 -> 4.0), so CI would have kept testing on 3.4 while production
# ran 4.0. The Ruby major.minor version must match in the Dockerfile,
# .ruby-version, and every CI workflow that installs Ruby.
class RubyVersionConsistencyTest < ActiveSupport::TestCase
  def minor(version)
    version.to_s[/\A\d+\.\d+/]
  end

  test "Dockerfile, .ruby-version and CI use the same Ruby major.minor" do
    expected = minor(File.read(Rails.root.join(".ruby-version")).strip)
    assert expected, ".ruby-version has no version"

    found = {}
    File.readlines(Rails.root.join("Dockerfile")).each_with_index do |line, index|
      version = line[/\AFROM\s+ruby:(\d+\.\d+)/i, 1]
      found["Dockerfile:#{index + 1}"] = version if version
    end

    Dir[Rails.root.join(".github/workflows/*.{yml,yaml}")].each do |path|
      workflow = YAML.safe_load_file(path, aliases: true) || {}
      (workflow["jobs"] || {}).each do |job_name, job|
        (job["steps"] || []).each do |step|
          next unless step["uses"].to_s.start_with?("ruby/setup-ruby@")
          version = (step["with"] || {})["ruby-version"]
          # No ruby-version (or ".ruby-version") means setup-ruby reads .ruby-version.
          next if version.nil? || version == ".ruby-version"
          found["#{File.basename(path)} / #{job_name}"] = minor(version)
        end
      end
    end

    assert found.keys.any? { |k| k.start_with?("Dockerfile") }, "no `FROM ruby:X.Y` line found in the Dockerfile"
    mismatches = found.reject { |_, version| version == expected }.map { |where, version| "#{where}: #{version.inspect}" }
    assert_empty mismatches, ".ruby-version is #{expected}; these differ:\n#{mismatches.join("\n")}"
  end
end
