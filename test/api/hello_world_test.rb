require 'test/unit'
require 'test_helpers'

class HelloWorldTest < MiniTest::Unit::TestCase

  def test_response
    TestApi.get "/hello_world"
    assert_api_response
  end

  def test_default_response
    TestApi.get "/hello_world"
    assert_equal TestApi.json_response["message"], "Hello World"
  end

  def test_override_response
    TestApi.get "/hello_world", :name => 'Matt'
    assert_equal TestApi.json_response["message"], "Hello Matt"
  end

end
