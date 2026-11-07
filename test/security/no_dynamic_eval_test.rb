require "test_helper"

# Regression guard for finding #7: no dynamic code evaluation anywhere in app code.
# This is a crude pattern check. A real rule engine (Semgrep or a custom CodeQL query)
# would be more precise, but this fails fast in the normal test run.
class NoDynamicEvalTest < ActiveSupport::TestCase
  FORBIDDEN = /\b(eval|instance_eval|class_eval|module_eval)\s*[\(\s]/

  test "app code contains no dynamic eval calls" do
    offenders = Dir[Rails.root.join("app/**/*.rb")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, index|
        next if line.strip.start_with?("#")
        "#{path.sub(Rails.root.to_s + '/', '')}:#{index + 1}: #{line.strip}" if line.match?(FORBIDDEN)
      end
    end

    assert_empty offenders, "dynamic eval found:\n#{offenders.join("\n")}"
  end
end
