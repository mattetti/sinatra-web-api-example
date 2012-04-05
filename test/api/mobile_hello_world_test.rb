require 'test/unit'
require 'test_helpers'

class MobileHelloWorldTest < MiniTest::Unit::TestCase

  def test_response_without_mobile_token
    TestApi.mobile_account = nil
    TestApi.mobile_get "/mobile_hello_world"
    response = TestApi.json_response
    assert_equal 401, response.status
  end

  def test_response_with_mobile_token
    TestApi.mobile_account = OpenStruct.new(:mobile_token => 'testtoken')
    TestApi.mobile_get "/mobile_hello_world"
    assert_api_response
  end

end
