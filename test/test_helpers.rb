ENV['RACK_ENV'] ||= 'test'
require 'test/unit'
require 'rack'
require 'rack/test'
require 'json'
require 'json_response_verification'
require File.join(File.dirname(__FILE__), '..', 'lib', 'bootloader')

require 'minitest/autorun'

ENV['NO_ROUTE_PRINT'] = 'true'
Bootloader.start
WeaselDiesel.send(:include, JSONResponseVerification)

ActiveRecord::Base.logger = nil

class Requester
  include ::Rack::Test::Methods

  def app
    Sinatra::Application
  end
end

module TestApi
  module_function

  URL_PLACEHOLDER   = /\/*(:[a-z A-Z _]+)\/*/
  INTERNAL_X_HEADER = AuthHelpers::INTERNAL_X_HEADER[/HTTP_(.*)/, 1] # strip the header marker added by Rack
  MOBILE_X_HEADER   = AuthHelpers::MOBILE_X_HEADER[/HTTP_(.*)/, 1]   # strip the header marker added by Rack

  def request(verb, uri, params={}, headers=nil)
    params ||= {}
    service_uri = uri.dup
    matching = uri.scan URL_PLACEHOLDER
    unless matching.empty?
      # replace the placeholder by real value
      matching.flatten.each_with_index do |str, idx|
        key = str.delete(":").to_sym
        value = params[key].to_s
        # delete the value from the params
        params.delete(key)
        uri = uri.gsub(str, value)
        end
    end
    
    request = Requester.new
    yield request if block_given?
    headers.each {|name, value| request.header(name, value) } if headers
    response = request.send(verb, uri, params)
    @json_response = JsonWrapperResponse.new(response, :verb => verb, :uri => service_uri)
  end

  def mobile_account=(account)
    @account = account
  end

  def get(uri, params=nil, headers=nil)
    request(:get, uri, params, headers)
  end

  def internal_get(uri, params=nil, headers=nil)
    get(uri, params, valid_internal_api_headers(headers))
  end

  def mobile_get(uri, params=nil, headers=nil)
    request(:get, uri, params, mobile_headers(headers))
  end

  def post(uri, params=nil, headers=nil)
    request(:post, uri, params, headers)
  end

  def internal_post(uri, params=nil, headers=nil)
    post(uri, params, valid_internal_api_headers(headers))
  end

  def mobile_post(uri, params=nil, headers=nil)
    request(:post, uri, params, mobile_headers(headers))
  end

  def put(uri, params=nil, headers=nil)
    request(:put, uri, params, headers)
  end

  def internal_put(uri, params=nil, headers=nil)
    put(uri, params, valid_internal_api_headers(headers))
  end

  def mobile_put(uri, params=nil, headers=nil)
    request(:put, uri, params, mobile_headers(headers))
  end

  def delete(uri, params=nil, headers=nil)
    request(:delete, uri, params, headers)
  end

  def internal_delete(uri, params=nil, headers=nil)
    delete(uri, params, valid_internal_api_headers(headers))
  end

  def mobile_delete(uri, params=nil, headers=nil)
    request(:delete, uri, params, mobile_headers(headers))
  end

  def head(uri, params=nil, headers=nil)
    request(:head, uri, params, headers)
  end

  def internal_head(uri, params=nil, headers=nil)
    head(uri, params, valid_internal_api_headers(headers))
  end

  def mobile_head(uri, params=nil, headers=nil)
    request(:head, uri, params, mobile_headers(headers))
  end

  def json_response
    @json_response
  end

  def last_response
    @json_response.rest_response if @json_response
  end

  def valid_internal_api_headers(headers)
    custom_headers = {INTERNAL_X_HEADER => AuthHelpers::ALLOWED_API_KEYS[0]}
    custom_headers.merge!(headers) if headers
    custom_headers
  end

  def mobile_headers(headers)
    custom_headers = {MOBILE_X_HEADER => @account ? Base64.urlsafe_encode64(@account.mobile_token) : nil}
    custom_headers.merge!(headers) if headers
    custom_headers
  end

end


# Wrapper around a rest response
class JsonWrapperResponse
  extend Forwardable

  attr_reader :rest_response
  attr_reader :verb
  attr_reader :uri

  def initialize(response, opts={})
    @rest_response = response
    @verb = opts[:verb]
    @uri = opts[:uri]
  end

  def body
    @body ||= JSON.load(rest_response.body) rescue rest_response.body
  end

  def success?
    @rest_response.status == 200
  end
  
  def redirected?
    @rest_response.status.to_s =~ /30\d/
  end

  def [](val)
    if body
      body[val.to_s]
    else
      nil
    end
  end

  def method_missing(meth, *args)
    body.send(meth, args)
  end

  def_delegators :rest_response, :code, :headers, :raw_headers, :cookies, :status, :errors
end


# Custom assertions
def assert_api_response(response=nil, message=nil)
  response ||= TestApi.json_response
  print response.rest_response.errors if response.status === 500
  assert response.success?, message || ["Body: #{response.rest_response.body}", "Errors: #{response.errors}", "Status code: #{response.status}"].join("\n")
  service = WSList.all.find{|s| s.verb == response.verb && s.url == response.uri[1..-1]}
  raise "Service for (#{response.verb.upcase} #{response.uri[1..-1]}) not found" unless service
  unless service.response.nodes.empty?
    assert response.body.is_a?(Hash), "Invalid JSON response:\n#{response.body}"
    valid, errors = service.validate_hash_response(response.body)
    assert valid, errors.join(" & ") || message
  end
end

def assert_api_response_with_redirection(redirection_url=nil)
  response = TestApi.json_response
  print response.rest_response.errors if response.status === 500
  assert response.status == 302, "Redirection expect, but got #{response.status}"
  if redirection_url
    assert response.headers["location"], redirection_url
  end
end
