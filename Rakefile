require 'rbconfig'
require 'rake/testtask'
require File.join(File.dirname(__FILE__), 'lib', 'bootloader')

Rake::TestTask.new do |t|
  t.libs << "."
  t.libs << 'test'
  t.pattern = "test/**.rb"
end

# boot the app
task :setup_app do
  ENV['DONT_CONNECT'] = 'true'
  Bootloader.start
end

task :environment do
  ENV['DONT_CONNECT'] = nil
  Bootloader.start
end

desc "Run the test suite by resting the DB first"
task :clean_test_suite do
  ENV['RACK_ENV'] ||= 'test'
  Rake::Task["db:drop"].invoke
  Rake::Task["db:create"].invoke
  Rake::Task["db:setup"].invoke
  Rake::Task["test"].invoke
end

Bootloader.set_loadpath
load File.join('tasks', 'db.rake')
load File.join('tasks', 'doc.rake')
