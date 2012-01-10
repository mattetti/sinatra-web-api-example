# require 'active_support/core_ext/object/inclusion'

db_namespace = namespace :db do

  task :load_config => :setup_app do
    require 'active_record'
    ActiveRecord::Base.configurations = Bootloader.db_configuration
    ActiveRecord::Migrator.migrations_paths = [File.join(ROOT, 'db/migrate')]
  end

  desc 'Create the database from config/database.yml for the current RACK_ENV (use db:create:all to create all dbs in the config)'
  task :create do
    old_connect_env = ENV['DONT_CONNECT'] ? 'true' : nil
    ENV['DONT_CONNECT'] = 'true'
    Rake::Task["db:load_config"].invoke
    create_database(Bootloader.db_configuration)
    ENV['DONT_CONNECT'] = old_connect_env
  end

  def mysql_creation_options(config)
    @charset   = ENV['CHARSET']   || 'utf8'
    @collation = ENV['COLLATION'] || 'utf8_unicode_ci'
    {:charset => (config['charset'] || @charset), :collation => (config['collation'] || @collation)}
  end

  def create_database(config)
    begin
      if config['adapter'] =~ /sqlite/
        if File.exist?(config['database'])
          $stderr.puts "#{config['database']} already exists"
        else
          begin
            # Create the SQLite database
            ActiveRecord::Base.establish_connection(config)
            ActiveRecord::Base.connection
          rescue Exception => e
            $stderr.puts e, *(e.backtrace)
            $stderr.puts "Couldn't create database for #{config.inspect}"
          end
        end
        return # Skip the else clause of begin/rescue
      else
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection
      end
    rescue
      case config['adapter']
      when /mysql/
        if config['adapter'] =~ /jdbc/
          #FIXME After Jdbcmysql gives this class
          require 'active_record/railties/jdbcmysql_error'
          error_class = ArJdbcMySQL::Error
        else
          error_class = config['adapter'] =~ /mysql2/ ? Mysql2::Error : Mysql::Error
        end
        access_denied_error = 1045
        begin
          ActiveRecord::Base.establish_connection(config.merge('database' => nil))
          ActiveRecord::Base.connection.create_database(config['database'], mysql_creation_options(config))
          ActiveRecord::Base.establish_connection(config)
        rescue error_class => sqlerr
          if sqlerr.errno == access_denied_error
            print "#{sqlerr.error}. \nPlease provide the root password for your mysql installation\n>"
            root_password = $stdin.gets.strip
            grant_statement = "GRANT ALL PRIVILEGES ON #{config['database']}.* " \
              "TO '#{config['username']}'@'localhost' " \
              "IDENTIFIED BY '#{config['password']}' WITH GRANT OPTION;"
            ActiveRecord::Base.establish_connection(config.merge(
                'database' => nil, 'username' => 'root', 'password' => root_password))
            ActiveRecord::Base.connection.create_database(config['database'], mysql_creation_options(config))
            ActiveRecord::Base.connection.execute grant_statement
            ActiveRecord::Base.establish_connection(config)
          else
            $stderr.puts sqlerr.error
            $stderr.puts "Couldn't create database for #{config.inspect}, charset: #{config['charset'] || @charset}, collation: #{config['collation'] || @collation}"
            $stderr.puts "(if you set the charset manually, make sure you have a matching collation)" if config['charset']
          end
        end
      when /postgresql/
        @encoding = config['encoding'] || ENV['CHARSET'] || 'utf8'
        begin
          ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
          ActiveRecord::Base.connection.create_database(config['database'], config.merge('encoding' => @encoding))
          ActiveRecord::Base.establish_connection(config)
        rescue Exception => e
          $stderr.puts e, *(e.backtrace)
          $stderr.puts "Couldn't create database for #{config.inspect}"
        end
      end
    else
      # Bug with 1.9.2 Calling return within begin still executes else
      $stderr.puts "#{config['database']} already exists" unless config['adapter'] =~ /sqlite/
    end
  end

  desc 'Drops the database for the current RACK_ENV (use db:drop:all to drop all databases)'
  task :drop do
    Rake::Task["db:load_config"].invoke
    config = Bootloader.db_configuration
    begin
      drop_database(config)
    rescue Exception => e
      $stderr.puts "Couldn't drop #{config['database']} : #{e.inspect}"
    end
  end

  def local_database?(config, &block)
    if config['host'].in?(['127.0.0.1', 'localhost']) || config['host'].blank?
      yield
    else
      $stderr.puts "This task only modifies local databases. #{config['database']} is on a remote host."
    end
  end


  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  task :migrate do
    Rake::Task[:environment].invoke
    Rake::Task["db:load_config"].invoke
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    db_namespace["schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby
  end

  namespace :migrate do
    # desc  'Rollbacks the database one migration and re migrate up (options: STEP=x, VERSION=x).'
    task :redo => [:environment, :load_config] do
      if ENV['VERSION']
        db_namespace['migrate:down'].invoke
        db_namespace['migrate:up'].invoke
      else
        db_namespace['rollback'].invoke
        db_namespace['migrate'].invoke
      end
    end

    # desc 'Resets your database using your migrations for the current environment'
    task :reset => ['db:drop', 'db:create', 'db:migrate']

    # desc 'Runs the "up" for a given migration VERSION.'
    task :up => [:environment, :load_config] do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version
      ActiveRecord::Migrator.run(:up, ActiveRecord::Migrator.migrations_paths, version)
      db_namespace['schema:dump'].invoke if ActiveRecord::Base.schema_format == :ruby
    end

    # desc 'Runs the "down" for a given migration VERSION.'
    task :down => [:environment, :load_config] do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version
      ActiveRecord::Migrator.run(:down, ActiveRecord::Migrator.migrations_paths, version)
      db_namespace['schema:dump'].invoke if ActiveRecord::Base.schema_format == :ruby
    end

    desc 'Display status of migrations'
    task :status => [:environment, :load_config] do
      config = Bootloader.db_configuration
      ActiveRecord::Base.establish_connection(config)
      unless ActiveRecord::Base.connection.table_exists?(ActiveRecord::Migrator.schema_migrations_table_name)
        puts 'Schema migrations table does not exist yet.'
        next  # means "return" for rake task
      end
      db_list = ActiveRecord::Base.connection.select_values("SELECT version FROM #{ActiveRecord::Migrator.schema_migrations_table_name}")
      file_list = []
      Dir.foreach(File.join(Bootloader.root_path, 'db', 'migrations')) do |file|
        # only files matching "20091231235959_some_name.rb" pattern
        if match_data = /^(\d{14})_(.+)\.rb$/.match(file)
          status = db_list.delete(match_data[1]) ? 'up' : 'down'
          file_list << [status, match_data[1], match_data[2].humanize]
        end
      end
      db_list.map! do |version|
        ['up', version, '********** NO FILE **********']
      end
      # output
      puts "\ndatabase: #{config['database']}\n\n"
      puts "#{'Status'.center(8)}  #{'Migration ID'.ljust(14)}  Migration Name"
      puts "-" * 50
      (db_list + file_list).sort_by {|migration| migration[1]}.each do |migration|
        puts "#{migration[0].center(8)}  #{migration[1].ljust(14)}  #{migration[2]}"
      end
      puts
    end
  end

  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback => [:environment, :load_config] do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback(ActiveRecord::Migrator.migrations_paths, step)
    db_namespace['schema:dump'].invoke if ActiveRecord::Base.schema_format == :ruby
  end

  # desc 'Pushes the schema to the next version (specify steps w/ STEP=n).'
  task :forward => [:environment, :load_config] do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.forward(ActiveRecord::Migrator.migrations_paths, step)
    db_namespace['schema:dump'].invoke if ActiveRecord::Base.schema_format == :ruby
  end

  # desc 'Drops and recreates the database from db/schema.rb for the current environment and loads the seeds.'
  task :reset => [ 'db:drop', 'db:setup' ]

  # desc "Retrieves the charset for the current environment's database"
  task :charset => :setup_app do
    config = Bootloader.db_configuration
    case config['adapter']
    when /mysql/
      ActiveRecord::Base.establish_connection(config)
      puts ActiveRecord::Base.connection.charset
    when /postgresql/
      ActiveRecord::Base.establish_connection(config)
      puts ActiveRecord::Base.connection.encoding
    when /sqlite/
      ActiveRecord::Base.establish_connection(config)
      puts ActiveRecord::Base.connection.encoding
    else
      $stderr.puts 'sorry, your database adapter is not supported yet, feel free to submit a patch'
    end
  end

  # desc "Retrieves the collation for the current environment's database"
  task :collation => :setup_app do
    config = Bootloader.db_configuration
    case config['adapter']
    when /mysql/
      ActiveRecord::Base.establish_connection(config)
      puts ActiveRecord::Base.connection.collation
    else
      $stderr.puts 'sorry, your database adapter is not supported yet, feel free to submit a patch'
    end
  end

  desc 'Retrieves the current schema version number'
  task :version => :setup_app do
    puts "Current version: #{ActiveRecord::Migrator.current_version}"
  end

  # desc "Raises an error if there are pending migrations"
  task :abort_if_pending_migrations => [:environment, :setup_app] do
    if defined? ActiveRecord
      pending_migrations = ActiveRecord::Migrator.new(:up, ActiveRecord::Migrator.migrations_paths).pending_migrations

      if pending_migrations.any?
        puts "You have #{pending_migrations.size} pending migrations:"
        pending_migrations.each do |pending_migration|
          puts '  %4d %s' % [pending_migration.version, pending_migration.name]
        end
        abort %{Run "rake db:migrate" to update your database then try again.}
      end
    end
  end

  desc 'Create the database, load the schema, and initialize with the seed data (use db:reset to also drop the db first)'
  task :setup => [ 'db:create', 'db:schema:load', 'db:seed' ]

  desc 'Load the seed data from db/seeds.rb'
  task :seed do
    old_no_redis = ENV['NO_REDIS'] ? 'true' : nil
    ENV['NO_REDIS'] = 'true'
    Rake::Task[:environment].invoke
    Rake::Task["db:abort_if_pending_migrations"].invoke
    seed = File.join(Bootloader.root_path, "db", "seed.rb")
    if File.exist?(seed)
      puts "seeding #{seed}"
      load seed
    else
      puts "Seed file: #{seed} is missing"
    end
    ENV['NO_REDIS'] = old_no_redis
  end

  namespace :fixtures do
    desc "Load fixtures into the current environment's database. Load specific fixtures using FIXTURES=x,y. Load from subdirectory in test/fixtures using FIXTURES_DIR=z. Specify an alternative path (eg. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
    task :load => :setup_app do
      require 'active_record/fixtures'

      ActiveRecord::Base.establish_connection(RACK_ENV)
      base_dir     = File.join [Bootloader.root_path, ENV['FIXTURES_PATH'] || %w{test fixtures}].flatten
      fixtures_dir = File.join [base_dir, ENV['FIXTURES_DIR']].compact

      (ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir["#{fixtures_dir}/**/*.{yml,csv}"].map {|f| f[(fixtures_dir.size + 1)..-5] }).each do |fixture_file|
        ActiveRecord::Fixtures.create_fixtures(fixtures_dir, fixture_file)
      end
    end

    # desc "Search for a fixture given a LABEL or ID. Specify an alternative path (eg. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
    task :identify => :setup_app do
      require 'active_record/fixtures'

      label, id = ENV['LABEL'], ENV['ID']
      raise 'LABEL or ID required' if label.blank? && id.blank?

      puts %Q(The fixture ID for "#{label}" is #{ActiveRecord::Fixtures.identify(label)}.) if label

      base_dir = ENV['FIXTURES_PATH'] ? File.join(Bootloader.root_path, ENV['FIXTURES_PATH']) : File.join(Bootloader.root_path, 'test', 'fixtures')
      Dir["#{base_dir}/**/*.yml"].each do |file|
        if data = YAML::load(ERB.new(IO.read(file)).result)
          data.keys.each do |key|
            key_id = ActiveRecord::Fixtures.identify(key)

            if key == label || key_id == id.to_i
              puts "#{file}: #{key} (#{key_id})"
            end
          end
        end
      end
    end
  end

  namespace :schema do
    desc 'Create a db/schema.rb file that can be portably used against any DB supported by AR'
    task :dump => :load_config do
      require 'active_record/schema_dumper'
      filename = ENV['SCHEMA'] || "#{Bootloader.root_path}/db/schema.rb"
      File.open(filename, "w:utf-8") do |file|
        ActiveRecord::Base.establish_connection(Bootloader.db_configuration)
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
      end
      db_namespace['schema:dump'].reenable
    end

    desc 'Load a schema.rb file into the database'
    task :load => :setup_app do
      file = ENV['SCHEMA'] || "#{Bootloader.root_path}/db/schema.rb"
      if File.exists?(file)
        load(file)
      else
        abort %{#{file} doesn't exist yet. Run "rake db:migrate" to create it then try again. If you do not intend to use a database, you should instead alter #{Bootloader.root_path}/config/application.rb to limit the frameworks that will be loaded}
      end
    end
  end

  namespace :structure do
    desc 'Dump the database structure to an SQL file'
    task :dump => :setup_app do
      abcs = Bootloader.db_configuration
      case abcs[RACK_ENV]['adapter']
      when /mysql/, 'oci', 'oracle'
        ActiveRecord::Base.establish_connection(config)
        File.open("#{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
      when /postgresql/
        ENV['PGHOST']     = abcs[RACK_ENV]['host'] if abcs[RACK_ENV]['host']
        ENV['PGPORT']     = abcs[RACK_ENV]["port"].to_s if abcs[RACK_ENV]['port']
        ENV['PGPASSWORD'] = abcs[RACK_ENV]['password'].to_s if abcs[RACK_ENV]['password']
        search_path = abcs[RACK_ENV]['schema_search_path']
        unless search_path.blank?
          search_path = search_path.split(",").map{|search_path_part| "--schema=#{search_path_part.strip}" }.join(" ")
        end
        `pg_dump -i -U "#{abcs[RACK_ENV]['username']}" -s -x -O -f db/#{RACK_ENV}_structure.sql #{search_path} #{abcs[RACK_ENV]['database']}`
        raise 'Error dumping database' if $?.exitstatus == 1
      when /sqlite/
        dbfile = abcs[RACK_ENV]['database'] || abcs[RACK_ENV]['dbfile']
        `sqlite3 #{dbfile} .schema > db/#{RACK_ENV}_structure.sql`
      when 'sqlserver'
        `smoscript -s #{abcs[RACK_ENV]['host']} -d #{abcs[RACK_ENV]['database']} -u #{abcs[RACK_ENV]['username']} -p #{abcs[RACK_ENV]['password']} -f db\\#{RACK_ENV}_structure.sql -A -U`
      when "firebird"
        set_firebird_env(abcs[RACK_ENV])
        db_string = firebird_db_string(abcs[RACK_ENV])
        sh "isql -a #{db_string} > #{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql"
      else
        raise "Task not supported by '#{abcs[RACK_ENV]["adapter"]}'"
      end

      if ActiveRecord::Base.connection.supports_migrations?
        File.open("#{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql", "a") { |f| f << ActiveRecord::Base.connection.dump_schema_information }
      end
    end
  end

  namespace :test do
    # desc "Recreate the test database from the current schema.rb"
    task :load => 'db:test:purge' do
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
      ActiveRecord::Schema.verbose = false
      db_namespace['schema:load'].invoke
    end

    # desc "Recreate the test database from the current environment's database schema"
    task :clone => %w(db:schema:dump db:test:load)

    # desc "Recreate the test databases from the development structure"
    task :clone_structure => [ 'db:structure:dump', 'db:test:purge' ] do
      abcs = ActiveRecord::Base.configurations
      case abcs['test']['adapter']
      when /mysql/
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        IO.readlines("#{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql").join.split("\n\n").each do |table|
          ActiveRecord::Base.connection.execute(table)
        end
      when /postgresql/
        ENV['PGHOST']     = abcs['test']['host'] if abcs['test']['host']
        ENV['PGPORT']     = abcs['test']['port'].to_s if abcs['test']['port']
        ENV['PGPASSWORD'] = abcs['test']['password'].to_s if abcs['test']['password']
        `psql -U "#{abcs['test']['username']}" -f #{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql #{abcs['test']['database']} #{abcs['test']['template']}`
      when /sqlite/
        dbfile = abcs['test']['database'] || abcs['test']['dbfile']
        `sqlite3 #{dbfile} < #{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql`
      when 'sqlserver'
        `sqlcmd -S #{abcs['test']['host']} -d #{abcs['test']['database']} -U #{abcs['test']['username']} -P #{abcs['test']['password']} -i db\\#{RACK_ENV}_structure.sql`
      when 'oci', 'oracle'
        ActiveRecord::Base.establish_connection(:test)
        IO.readlines("#{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql").join.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      when 'firebird'
        set_firebird_env(abcs['test'])
        db_string = firebird_db_string(abcs['test'])
        sh "isql -i #{Bootloader.root_path}/db/#{RACK_ENV}_structure.sql #{db_string}"
      else
        raise "Task not supported by '#{abcs['test']['adapter']}'"
      end
    end

    # desc "Empty the test database"
    task :purge => :setup_app do
      abcs = ActiveRecord::Base.configurations
      case abcs['test']['adapter']
      when /mysql/
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.recreate_database(abcs['test']['database'], mysql_creation_options(abcs['test']))
      when /postgresql/
        ActiveRecord::Base.clear_active_connections!
        drop_database(abcs['test'])
        create_database(abcs['test'])
      when /sqlite/
        dbfile = abcs['test']['database'] || abcs['test']['dbfile']
        File.delete(dbfile) if File.exist?(dbfile)
      when 'sqlserver'
        test = abcs.deep_dup['test']
        test_database = test['database']
        test['database'] = 'master'
        ActiveRecord::Base.establish_connection(test)
        ActiveRecord::Base.connection.recreate_database!(test_database)
      when "oci", "oracle"
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      when 'firebird'
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.recreate_database!
      else
        raise "Task not supported by '#{abcs['test']['adapter']}'"
      end
    end

    # desc 'Check for pending migrations and load the test schema'
    task :prepare => 'db:abort_if_pending_migrations' do
      if defined?(ActiveRecord) && !ActiveRecord::Base.configurations.blank?
        db_namespace[{ :sql  => 'test:clone_structure', :ruby => 'test:load' }[ActiveRecord::Base.schema_format]].invoke
      end
    end
  end

end

task 'test:prepare' => 'db:test:prepare'

def drop_database(config)
  case config['adapter']
  when /mysql/
    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.connection.drop_database config['database']
  when /sqlite/
    require 'pathname'
    path = Pathname.new(config['database'])
    file = path.absolute? ? path.to_s : File.join(Bootloader.root_path, path)

    FileUtils.rm(file) if File.exist?(file)
  when /postgresql/
    ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
    ActiveRecord::Base.connection.drop_database config['database']
  end
end

def session_table_name
  ActiveRecord::SessionStore::Session.table_name
end
