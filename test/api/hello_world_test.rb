require 'test/unit'
require 'test_helpers'

class HelloWorldTest < MiniTest::Unit::TestCase

  def test_default_response
    TestApi.get "/hello_world"
    response = TestApi.json_response
    assert_api_response response
    assert_equal response["message"], "Hello World"
  end

  def test_override_response
    TestApi.get "/hello_world", :name => 'Matt'
    response = TestApi.json_response
    assert_api_response response
    assert_equal response["message"], "Hello Matt"
  end

end
