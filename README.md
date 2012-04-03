# Sinatra + WSDSL + ActiveRecord Example app

## App Usage

To start the server:
    
    $ bundle install

    $ rackup

Or 
    $ foreman start

if you have foreman installed.

To use the command line:

    $ bundle exec irb -Ilib -rbootloader.rb
    > Bootloader.start

See/generate the API documentation:

    $ rake doc:services

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


## Writing an API

The DSL for writing an API is straight forward:

    describe_service "hello_world" do |service|
      service.formats   :json
      service.http_verb :get
      service.disable_auth # on by default

      # INPUT
      service.param.string  :name, :default => 'World'

      # OUTPUT
      service.response do |response|
        response.object do |obj|
          obj.string :message, :doc => "The greeting message sent back. Defaults to 'World'"
          obj.datetime :at, :doc => "The timestamp of when the message was dispatched"
        end
      end

      # DOCUMENTATION
      service.documentation do |doc|
        doc.overall "This service provides a simple hello world implementation example."
        doc.param :name, "The name of the person to greet."
        doc.example "<code>curl -I 'http://localhost:9292/hello_world?name=Matt'</code>"
     end

      # ACTION/IMPLEMENTATION
      service.implementation do
        {:message => "Hello #{params[:name]}", :at => Time.now}.to_json
      end

    end


APIs are described in files named the way you want but stored in the API
folder.
The DSL used comes from the WSDSL gem. It works by defining the end
point url (with or without placeholders) and a few key elements of the
services:

    describe_service "uri/to/service" do |service|
      service.http_verb :post  # HTTP verb to access this service
      service.disable_auth # disable the auth check (on by default)
      # extra params can be passed to be handled by your code:
      # service.extra[:mobile] = true

      # DOCUMENTATION
      # a documentation block for the service and the request params
      service.documentation do |doc|
        doc.overall "service description"
        doc.param :email, "Description of the param"
        doc.param :password, "TDescription of the param"
      end

      # INPUT
      # request params, optional unless mentioned othwerwise.
      # if bad params are passed, the request will be returned with a
      # 400 status code. Various data types can be used to cast and
      # check the passed params.
      service.params do |p|
        p.string :email, :required => true
        p.string :password, :required => true
      end

      # OUTPUT
      # response block describing the response sent back to the client.
      # Used to test the services and to document them.
      service.response do |response|
        response.object do |obj|
          obj.string :token, :doc => "The auth token for the authenticated user, only sent back if a callback url isn't sent"
        end
      end

      # ACTION CODE
      # Finally the implementation block being called when the service
      # is reached. The block's returned value is be used as the
      # response's body.
      service.implementation do
        {:foo => :bar}.to_json
      end

      # If you need to define methods to use within this service, you
      # can defined them direcly on the service object ensuring that
      # the method will only be available within this service.
      def service.baz
        :baz
      end

    end

## Tests

The app test suite uses a series of helpers wrapping rack/test to test
a request going through the stack but without the overhead of actually
doing a real HTTP request.

To validate that a service responds as defined in the DSL, you can use
the provided helpers, here is an example:

    class HelloWorldTest < MiniTest::Unit::TestCase

      def test_response
        TestApi.get "/hello_world", :name => 'Matt'
        assert_api_response
      end

    end


The `TestAPI` module dispatches a request to the app and the
`assert_api_response` helper will validate that the response matches the
service description.

Look at the `test/test_helpers.rb` file to see the many other helpers
such as `TestAPI.last_response`, `TestAPI.json_response`,
`TestAPI.mobile_get` etc...


## More about the DSL

This app is built on top of Sinatra and the WSDSL (WebService DSL gem).
Reasons for a DSL vs the standard Rails approach:

1. API design becomes the number 1 focus.
By focusing on designing the API and documenting it in one unique place, there is no more digging through 5 layers of code.
Using the provided tools meant to generate HTML documentation, you can focus on what matters the most: design and communication.

2. Save development time
An API can be designed and even tested (mocked) right away, even before the implementation is done.
This is a huge gain of time when dealing with multiple third parties consuming an API. One can spend more time designing and testing against mock data and then finally implement.

3. Isolation/standalone
Each API lives in its own file, it's easily copied over, easy to grasp and easy to see the involved dependencies.

4. Backend agnostic (potentially language agnostic)
Because the DSL is "precompiled" and creates simple objects, the DSL can be plugged on almost any backend (as long as the backend is flexible enough to let you create a route and a function to execute when the route is matched).
The implementation doesn't even actually have to be in Ruby, this is far to be done, but I'd love to see the DSLs to be compiled in a language agnostic format to then be loaded by a different backend offering a processing engine for it (i.e: implementation).

5. Simpler/Easier
This goes back to my #1 point, but think about new developers and people wanting to build APIs.
Do they really need to know and understand how the router works, enter a route pointing to a controller and a specific action which has a view attached?
By simplifying the path, you get better performance (less objects allocated, less GC time, smaller stack), better understanding for all (the entire stack in probably 2k LOC max) and people getting up and running right away.

6. Documentation
Documenting APIs is a pain and it's hard to keep track of changes. Generated documentation usually isn't really good and you want some humans to explain what the service does and how.
By offering a compromise of required documentation (incoming param rules), strongly encouraged documentation (response definition used for testing) and suggested documentation (English text for each parts of the request/response), the developer can think of how people will consume the data and can keep the documentation up to date at a pretty low cost.
The documentation is then extracted from the DSL and provided in a HTML format.

7. Security
The DSL implementation enforces param verification (name, type, options, length etc...) which provides an extra layer of security for your endpoints. (Remember the GitHub security accident?)

10. Conventions
Because the work surface is smaller, one can more easily encourage conventions and provide "DSL add-ons" for shared features.
Also, because the implementation call is a simple Ruby block (with helpers and request context available) it encourages developers to better organize their code.

11. Stability
Because the code base is simple, it doesn't need to be updated often. A new ORM can be added or a new library, but doing that doesn't have to affect the provided "micro framework".

12. Portability
Porting a Rails app to the DSL is actually almost trivial, I even have a a module to point DSLs to controller with actions so the only thing that needs to be changed is the view rendering. (see the WSDSL for the module in question).

13. Testability
Tests can run fast while still going through the stack. Because each test can have access to the entire service description (including the expected response), the amount of automatic tests can be increased, reducing the amount of dev work and assuring that the 3rd party users who built on their code on top of the documentation don't see regressions due to poorly written tests.

14. Performance
This mini-framework is designed to run at optimal speed, a thread pool is set by default and can be tweaked. The amount of objects allocated is reduced to a minimum and because of the small code base optimizations can be done for a given runtime environment.

15. Freedom
Because the implementation of each service is left up to the developer, various ORMs, data stores or libraries can be used without making a radical change to the project. APIs still look the same and all follow the DSL but the implementation is a different concern which can evolve at a different path.

16. Modularity
If an API app grows too much, it is very easy to extract some APIs and move them to a new app. Especially if models are organized in packages and can be shared between applications. (that's a longer discussion, ask me if you want to hear more about that)

17. Customization
Adding new features or standard code paths for all apps is trivial and easy to maintain.



There are very little cons, but let me try to list them nonetheless:

1. It's not Rails. 
Rails has decent documentation, people are used to it and it's a well maintained project. The problem though is that most of the documentation isn't to develop APIs, people are used to write Web2.0 websites with Rails and well, most of the new features are HTML related. (streaming, asset pipeline, coffeescript/SCSS)
The good news is that we can probably run the same DSL on top of Rails 3.

2. You can't google it.
True, but it should be so easy that you don't need to google it. You can also not google most of what's going in out apps nowadays.
Because the code is simple and it is based on well known elements, that shouldn't be a problem.

3. Deployment.
It's Ruby based, it's rack based and it's even Sinatra based. If you can deploy a Ruby web app, you can deploy an app like that, and yes it even works on Heroku.

4. Maintenance and support.
The code shouldn't need maintenance except for bugs being found or new requested features. Because it's just a bootloader (150 LOC w/ empty lines), a layer to implement the DSL on top of Sinatra (100 LOC w/ spaces), some test helpers (130 LOC w/ spaces) and some rake tasks, most of the maintenance and support is actually required on the libraries used such as the web engine (Sinatra), the ORM or the other 3rd party libraries used. At the end of the day, this is just a simple DSL on top of well known, well maintained libraries, and there are no monkey patching going on.

## TODO:

* RSpec helpers
* Make the ORM configurable.
* Generators for blank APIs and migrations.
* Provide Rack Client as a test alternative to make real HTTP calls.
