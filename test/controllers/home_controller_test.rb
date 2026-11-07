require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  # Regression test for finding #7 (code injection via eval of a request param).
  # If anything evaluates the `expr` parameter as Ruby, the marker gets set and this fails.
  test "request params are never evaluated as code" do
    $eval_marker = nil
    get root_url, params: { expr: "$eval_marker = :executed" }
    assert_response :success
    assert_nil $eval_marker, "a request parameter was evaluated as Ruby code"
  end
end
