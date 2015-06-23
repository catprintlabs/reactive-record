

#  require 'opal-rspec'
#require 'jquery/jquery.js'
#require 'opal-jquery'
#require 'jquery/rspec' #was opal/jquery
#require 'react/react.js'
if false
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
  
  def create_element(type, options)
    component = React.create_element(type, options)
    element = `ReactTestUtils.renderIntoDocument(#{component.to_n})`
  end
  
  def find_dom_node(element)
    `$(React.findDOMNode(element))`
  end
  
  def get_component_instance(element)
    `#{element}._getOpalInstance.apply(#{element})`
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
    check_block = lambda {run_async { element = nil; expect(true).to be(true) } if element and block.call(element) }
    component_class.after_update { check_block.call  }
    element = build_element component_class, opts
    check_block.call
  end  
  
end

RSpec.configure do |config|
  config.include ReactTestHelpers
end
end