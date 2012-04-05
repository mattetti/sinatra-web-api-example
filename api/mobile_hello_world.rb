describe_service "mobile_hello_world" do |service|
  service.formats   :json
  service.http_verb :get
  service.extra[:mobile] = true

  # INPUT
  service.param.string  :name, :default => 'World for mobile devices'

  # OUTPUT
  service.response do |response|
    response.object do |obj|
      obj.string :message, :doc => "The greeting message sent back. Defaults to 'Hello World for mobile devices'"
      obj.datetime :at, :doc => "The timestamp of when the message was dispatched"
    end
  end

  # DOCUMENTATION
  service.documentation do |doc|
    doc.overall "This service provides a simple hello world implementation example."
    doc.param :name, "The name of the person to greet."
    doc.example "<code>curl -I 'http://localhost:9292/mobile_hello_world?name=Matt'</code>"
  end

  # ACTION/IMPLEMENTATION
  service.implementation do
    {:message => "Hello #{params[:name]} from mobile devices", :at => Time.now}.to_json
  end

end
