require 'opal-react'
require "reactive_record/cache"

class Callback
  
  include React::Component
  
  export_component
  
  required_param :tell_me
  optional_param :id, default: 123
  
  def render
    div do
      span { `window.test_context.hello(#{tell_me})` }
      br
      span { "find('TestModel', #{id}) returns: "}
      span { `window.ReactiveRecordCache.find("TestModel", #{id})` }
      span { "!" }
    end
  rescue Exception => e
    span { "error: #{e.message}" }
    
  end
  
end