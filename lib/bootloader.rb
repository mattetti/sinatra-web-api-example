require 'bundler'
require 'logger'
Bundler.require
ROOT = File.expand_path('..', File.dirname(__FILE__))
LOGGER = Logger.new($stdout)

module Bootloader
  module_function

  def start
    unless @booted
      set_env
      load_environment
      set_loadpath
      load_lib_dependencies
      set_db_connection
      connect_to_db
      load_models unless ENV['DONT_CONNECT']
      load_apis
      load_middleware
      set_sinatra_routes
      set_sinatra_settings
      @booted = true
    end
  end

  def root_path
    ROOT
  end

  def set_env
    if !Object.const_defined?(:RACK_ENV)
      ENV['RACK_ENV'] ||= "development"
      Object.const_set(:RACK_ENV, ENV['RACK_ENV'])
    end
    LOGGER.info "Running in #{RACK_ENV} mode"
  end

  def load_environment(env=nil)
    # Load the detault which can be overwritten or extended by specific
    # env config files.
    require File.join(ROOT, 'config', 'environments', 'default.rb')
    env_file = File.join(ROOT, "config", "environments", "#{env}.rb")
    if File.exist?(env_file)
      require env_file
    else
      LOGGER.debug "Environment file: #{env_file} couldn't be found, using only the default environment config instead." unless env == 'development'
    end
  end

  def set_loadpath
    $: << ROOT
    $: << File.join(ROOT, 'lib')
    $: << File.join(ROOT, 'models')
  end

  def load_lib_dependencies
    # WSDSL is the web service DSL gem used to define services.
    require 'wsdsl'
    require 'wsdsl_sinatra_ext'
    require 'sinatra'
    require 'active_record'
    require 'base64'
    require 'digest/md5'
    require 'hax'
  end

  def set_db_connection
    # Set the AR logger
    if Object.const_defined?(:LOGGER)
      ActiveRecord::Base.logger = LOGGER
    else
      ActiveRecord::Base.logger = Logger.new($stdout)
    end
    # Establish the DB connection
    db_file = File.join(ROOT, "config", "database.yml")
    if File.exist?(db_file)
      hash_settings = YAML.load_file(db_file)
      if hash_settings && hash_settings[RACK_ENV]
        @db_configurations = hash_settings
        @db_configuration = @db_configurations[RACK_ENV]
        connect_to_db unless ENV['DONT_CONNECT']
      else
        raise "#{db_file} doesn't have an entry for the #{RACK_ENV} environment"
      end
    else
      raise "#{db_file} file missing, can't connect to the DB"
    end
  end

  def db_configuration
    old_connect_status = ENV['DONT_CONNECT']
    set_db_connection unless @db_configuration
    ENV['DONT_CONNECT'] = old_connect_status
    @db_configuration
  end

  def connect_to_db
    if @db_configuration
      connection = ActiveRecord::Base.establish_connection(@db_configuration)
      # LOGGER.debug connection.inspect
    else
      raise "Can't connect without the config previously set"
    end
  end

  def load_models
    Dir.glob(File.join(ROOT, "models", "**", "*.rb")).each do |model|
      require model
    end
  end

  # DSL routes are located in the api folder
  def load_apis
    Dir.glob(File.join(ROOT, "api", "**", "*.rb")).each do |api|
      require api
    end
  end

  def set_sinatra_routes
    WSList.all.sort.each{|api| api.load_sinatra_route }
  end

  def load_middleware
    require File.join(ROOT, 'config', 'middleware')
  end

  def set_sinatra_settings
    # Using the :production env would wrap errors instead of displaying them
    # like in dev mode
    set :environment, RACK_ENV
    set :root, ROOT
    set :app_file, __FILE__
    set :public_folder, File.join(ROOT, "public")
    # Checks on static files before dispatching calls
    enable :static
    # enable rack session
    enable :session
    set :raise_errors, false
    # enable that option to run by calling this file automatically (without using the config.ru file)
    # enable :run
    use Rack::ContentLength
  end

end
