require "test_helper"

# Regression guard for findings #25 and #26: the deploy role could update and describe
# every ECS service in the AWS account ("*"), not just this app's. Reported by
# the gpt-oss-120b AI review (guide section 14); no scanner flagged it.
#
# Any IAM statement in infra/ that grants these ECS service actions must name
# specific services, with no wildcard.
class DeployRoleScopeTest < ActiveSupport::TestCase
  SERVICE_ACTIONS = ["ecs:UpdateService", "ecs:DescribeServices"].freeze

  # Returns [path, line number, block text] for every `statement { ... }` block,
  # ending at the closing brace with the same indentation.
  def statements
    Dir[Rails.root.join("infra/*.tf")].flat_map do |path|
      blocks = []
      current = nil
      File.readlines(path).each_with_index do |line, index|
        if current
          current[2] << line
          if line.match?(/\A#{current[3]}\}\s*\z/)
            blocks << current.first(3)
            current = nil
          end
        elsif (match = line.match(/\A(\s*)statement\s*\{\s*\z/))
          current = [path.sub("#{Rails.root}/", ""), index + 1, +"", match[1]]
        end
      end
      blocks
    end
  end

  test "ECS service actions are granted somewhere" do
    granting = statements.select { |_, _, text| SERVICE_ACTIONS.any? { |action| text.include?(%("#{action}")) } }

    assert_not_empty granting, "expected the deploy role to grant #{SERVICE_ACTIONS.join(' and ')}"
  end

  test "ECS service actions are limited to named services" do
    offenders = statements.filter_map do |path, line, text|
      next unless SERVICE_ACTIONS.any? { |action| text.include?(%("#{action}")) }
      resources = text[/resources\s*=\s*\[(.*?)\]/m, 1].to_s
      "#{path}:#{line}" if resources.strip.empty? || resources.include?("*")
    end

    assert_empty offenders, "#{SERVICE_ACTIONS.join(' / ')} must name the service ARN, not \"*\":\n#{offenders.join("\n")}"
  end

  # Finding #26: iam:PassRole must name specific roles and only allow passing
  # them to ECS tasks, so they can't be handed to another service.
  test "iam:PassRole names specific roles and is limited to ECS tasks" do
    passrole = statements.select { |_, _, text| text.include?('"iam:PassRole"') }
    assert_not_empty passrole, "expected the deploy role to grant iam:PassRole"

    offenders = passrole.filter_map do |path, line, text|
      resources = text[/resources\s*=\s*\[(.*?)\]/m, 1].to_s
      problems = []
      problems << "resources use a wildcard" if resources.strip.empty? || resources.include?("*")
      unless text.match?(/variable\s*=\s*"iam:PassedToService"/) && text.include?('"ecs-tasks.amazonaws.com"')
        problems << "no iam:PassedToService = ecs-tasks.amazonaws.com condition"
      end
      "#{path}:#{line}: #{problems.join('; ')}" if problems.any?
    end

    assert_empty offenders, "iam:PassRole is too broad:\n#{offenders.join("\n")}"
  end
end
