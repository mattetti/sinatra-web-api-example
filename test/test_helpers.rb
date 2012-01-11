ENV['RACK_ENV'] ||= 'test'
require 'rack'
require 'rack/test'
require 'json'
require 'json_response_verification'
require File.join(File.dirname(__FILE__), '..', 'lib', 'bootloader')

ENV['NO_ROUTE_PRINT'] = 'true'
Bootloader.start
WSDSL.send(:include, JSONResponseVerification)

ActiveRecord::Base.logger = nil

class Requester
  include ::Rack::Test::Methods

  def app
    Sinatra::Application
  end
end

module TestApi
  module_function

  URL_PLACEHOLDER = /\/*(:[a-z A-Z _]+)\/*/

  def request(verb, uri, params={})
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

    response = Requester.new.send(verb, uri, params)
    @json_response = JsonWrapperResponse.new(response, :verb => verb, :uri => service_uri)
  end

  def get(uri, params=nil)
    request(:get, uri, params)
  end

  def post(uri, params=nil)
    request(:post, uri, params)
  end

  def put(uri, params=nil)
    request(:put, uri, params)
  end

  def delete(uri, params=nil)
    request(:delete, uri, params)
  end

  def head(uri, params=nil)
    request(:head, uri, params)
  end

  def json_response
    @json_response
  end

  def last_response
    @json_response.rest_response if @json_response
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
  assert response.success?, message || ["Body: #{response.rest_response.body}", "Errors: #{response.errors}", "Status code: #{response.status}"].join("\n")
  service = WSList.all.find{|s| s.verb == response.verb && s.url == response.uri[1..-1]}
  raise "Service for (#{response.verb.upcase} #{response.uri[1..-1]}) not found" unless service
  valid, errors = service.validate_hash_response(response.body)
  assert valid, errors.join(" & ") || message
end
