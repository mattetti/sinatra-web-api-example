source "http://rubygems.org"

# web engine
gem "sinatra", "1.3.2"
# service DSL
gem "wsdsl", "0.5.0"
#
gem "redis", "~> 2.2.2"
gem 'mysql2', '0.3.11'
gem 'activerecord', '3.1.3'
gem 'sinatra-activerecord', '0.1.3'
gem 'email_veracity', '0.6.0'
# gem "hiredis", "~> 0.4.1"
# gem 'rest-client', '~> 1.6.7'

if ENV['RACK_ENV'] != "production"
  gem "rack-test", "0.6.1"
  gem "foreman", "~> 0.26.1"
  gem "puma", "~> 0.9.3"
end
