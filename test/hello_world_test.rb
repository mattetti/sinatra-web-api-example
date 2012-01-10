require 'test/unit'
require 'test_helpers'

class HelloWorldTest < MiniTest::Unit::TestCase

  def test_response
    TestApi.get "/hello_world", :name => 'Matt'
    assert_api_response
  end

end
