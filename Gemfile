source "http://rubygems.org"

# web engine
gem "sinatra", "1.3.2"
# service DSL
gem "weasel_diesel", "1.0.0"
#
gem 'mysql2', '0.3.11'
gem 'activerecord', '3.1.3'

if RUBY_VERSION =~ /1.8/
  gem 'backports', '2.3.0'
  gem 'json'
end

if ENV['RACK_ENV'] != "production"
  gem "rack-test", "0.6.1"
  gem "foreman"
  gem "puma"
  gem "minitest"
  gem "guard-puma"
  gem "guard-minitest"
end
