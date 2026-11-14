require "test_helper"

# Regression guard for finding #24: `render json: ENV.to_h` exposed every
# environment variable, including SECRET_KEY_BASE. App code may read a single
# named variable (ENV.fetch("NAME") or ENV["NAME"]), but never list, dump or
# pass around the whole environment or the request's environment.
class NoEnvDumpTest < ActiveSupport::TestCase
  ALLOWED_ENV_METHODS = %w[fetch key? include? has_key?].freeze

  def offenders
    Dir[Rails.root.join("app/**/*.{rb,erb}")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, index|
        code = line.sub(/#.*/, "") # ignore comments
        bad = code.scan(/\bENV\.(\w+[?!]?)/).flatten.reject { |m| ALLOWED_ENV_METHODS.include?(m) }
        bad << "ENV (whole object)" if code.match?(/\bENV\b(?!\s*[.\[])/)
        bad << "request.env" if code.match?(/\brequest\.(env|headers\.env)\b/)
        "#{path.sub("#{Rails.root}/", '')}:#{index + 1}: #{bad.join(', ')}: #{line.strip}" if bad.any?
      end
    end
  end

  test "app code never dumps the environment" do
    assert_empty offenders, "whole-environment access found (read single variables instead):\n#{offenders.join("\n")}"
  end
end
