require "test_helper"
require "yaml"

# Guards the on/off switch (bin/app-power, DEPLOYMENT_GUIDE section 34). The
# script refuses to apply a plan that changes anything except its TOGGLED list,
# so that list, the `count = var.app_enabled` resources in infra/, and the CD
# workflow's off-handling must stay in step.
class AppPowerTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/app-power")

  def toggled_in_script
    File.read(SCRIPT)[/^TOGGLED=\((.*?)\)/m, 1].scan(/"([^"]+)"/).flatten.sort
  end

  def toggled_in_terraform
    Dir[Rails.root.join("infra/*.tf")].flat_map do |path|
      File.read(path).scan(/^resource "(\w+)" "(\w+)" \{\n\s*count = var\.app_enabled \? 1 : 0/)
        .map { |type, name| "#{type}.#{name}[0]" }
    end.sort
  end

  test "the script's allowed changes match the switched resources in infra/" do
    assert_equal ["aws_ecs_service.this[0]", "aws_lb.this[0]", "aws_lb_listener.http[0]"], toggled_in_terraform
    assert_equal toggled_in_terraform, toggled_in_script
  end

  test "the script shows the plan, checks it, and asks before applying" do
    script = File.read(SCRIPT)

    assert_match(/terraform plan .*-out/, script)
    assert_match(/changes" != "\$expected"/, script, "the script must refuse plans with unexpected changes")
    assert_match(/read -r -p "Type yes to apply: "/, script)
    assert_match(/terraform apply -input=false "\$workdir\/power\.tfplan"/, script,
      "apply only the reviewed plan file")
    refute_match(/-auto-approve/, script)
  end

  test "the deploy role can still name the service while it's switched off" do
    iam = File.read(Rails.root.join("infra/iam.tf"))

    refute_match(/aws_ecs_service\.this/, iam, "use the service's built ARN; the resource is absent while off")
  end

  test "cd.yml skips the service update and the ZAP scan while the app is off" do
    workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/cd.yml"), aliases: true)
    steps = workflow.dig("jobs", "deploy", "steps")
    deploy = steps.find { |step| step["name"] == "Deploy to ECS" }
    register = steps.find { |step| step["name"].to_s.start_with?("Register only") }

    assert_equal "vars.APP_ENABLED != 'false'", deploy["if"]
    assert_equal "vars.APP_ENABLED == 'false'", register["if"]
    assert_nil register.dig("with", "service"), "while off, only register the task definition"
    assert_equal "vars.APP_ENABLED != 'false'", workflow.dig("jobs", "zap-production", "if").to_s.split(" #").first
  end
end
