require File.join( File.dirname(__FILE__), 'lib', 'bootloader')
Bootloader.start
run Sinatra::Application
