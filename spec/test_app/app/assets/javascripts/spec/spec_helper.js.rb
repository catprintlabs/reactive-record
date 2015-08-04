require 'spec/reactive_record_config'
require 'react_js_test_only'
require 'opal-react'
require 'reactive_record'
#require 'jquery'

if false 
rendering("a component", timeout: 5) do
  puts "simplified!"
  span {"hello"}
end.should_generate do |component|
  component.html == "hello"
end
end

module Opal
  module RSpec
    module AsyncHelpers
      module ClassMethods
        
        def rendering(title, &block)
          klass = Class.new do
            
            include React::Component
            
            def self.block
              @block
            end
            
            backtrace :on
            
            def render
              instance_eval &self.class.block
            end
            
            def self.should_generate(opts={}, &block)
              sself = self
              @self.async(@title, opts) do
                expect_component_to_eventually(sself, &block)
              end
            end
            
            def self.should_immediately_generate(opts={}, &block)
              sself = self
              @self.it(@title, opts) do
                element = build_element sself, {}
                context = block.arity > 0 ? self : element
                expect((element and context.instance_exec(element, &block))).to be(true)
              end
            end
            
          end
          klass.instance_variable_set("@block", block)
          klass.instance_variable_set("@self", self)
          klass.instance_variable_set("@title", "it can render #{title}")
          klass
        end
      end
    end
  end
end

module ReactTestHelpers
  
  `var ReactTestUtils = React.addons.TestUtils`

  def renderToDocument(type, options = {})
    element = React.create_element(type, options)
    return renderElementToDocument(element)
  end

  def renderElementToDocument(element)
    instance = Native(`ReactTestUtils.renderIntoDocument(#{element.to_n})`)
    instance.class.include(React::Component::API)
    return instance
  end

  def simulateEvent(event, element, params = {})
    simulator = Native(`ReactTestUtils.Simulate`)
    element = `#{element.to_n}.getDOMNode` unless element.class == Element
    simulator[event.to_s].call(element, params)
  end

  def isElementOfType(element, type)
    `React.addons.TestUtils.isElementOfType(#{element.to_n}, #{type.cached_component_class})`
  end
  
  def build_element(type, options)
    component = React.create_element(type, options)
    element = `ReactTestUtils.renderIntoDocument(#{component.to_n})`
    `$(React.findDOMNode(element))`
  end
  
  def expect_component_to_eventually(component_class, opts = {}, &block) 
    # Calls block after each update of a component until it returns true.  When it does set the expectation to true.
    # Uses the after_update callback of the component_class, then instantiates an element of that class
    # The call back is only called on updates, so the call back is manually called right after the
    # element is created.
    # Because React.rb runs the callback inside the components context, we have to 
    # setup a lambda to get back to correct context before executing run_async.
    # Because run_async can only be run once it is protected by clearing element once the test passes.
    element = nil
    check_block = lambda do 
      context = block.arity > 0 ? self : element
      run_async do
         element = nil; expect(true).to be(true) 
      end if element and context.instance_exec(element, &block) 
    end
    component_class.after_update { check_block.call  }
    element = build_element component_class, opts
    check_block.call
  end
    
end

RSpec.configure do |config|
  config.include ReactTestHelpers
  config.before(:each) do 
    `current_state = {}`
  end
end
