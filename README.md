# Sinatra + WSDSL + ActiveRecord Example app

## App Usage

To start the server:

    $ rackup

Or 
    $ foreman start

if you have foreman installed.

To use the command line:

    $ irb -Ilib -rbootloader.rb
    > Bootloader.start

## Dependencies

* A Database (set the connection settings in config/database.yml)
* Ruby
* Bundler

## Organization

Models live under the models folder, APIs in the API folder.
The database.yml file in the config folder contains the db info per
environment.

By default all environments share the same settings, but you can drop a
custom environment file in the config/environments folder named after
the env you want to target.

Migrations are simple ActiveRecord migrations and a seed.rb file is
available to pre seed the DB.

Files in the lib folder aren't automatically required.

## Tests

The app test suite uses a series of helpers wrapping rack/test to test
a request going through the stack but without the overhead of actually
doing a real HTTP request.


## TODO:

* Test under Ruby 1.8, JRuby and Rubinius.
* Add test suite for the Sinatra + WSDSL integration.
* Documentation task to generate an HTML (PDF?) version of the offered services.
* Make the ORM configurable.
* Generators for blank APIs and migrations.
* Provide Rack Client as a test alternative to make real HTTP calls.
