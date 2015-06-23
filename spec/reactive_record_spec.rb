require 'spec_helper'

class TestContext
  
  attr_reader :last_hello_data
  
  def initialize
    @hello_count = 0
  end
  
  def hello(data)
    @last_hello_data = hello_data
    @hello_count += 1
  end
  
end

describe ReactiveRecord do
  it "has a version" do
    expect(ReactiveRecord::VERSION).to be_truthy
  end
  
  it "can communicate with a react component during server rendering" do
    helper = ActionView::Base.new.extend(React::Rails::ViewHelper)
    test_context = TestContext.new
    html = helper.react_component('Baz', {tell_me: "goodby"}, prerender: {server_context: test_context})
    expect(html).to eq('<span>1</span>')
    expect(test_context.last_hello_data).to eq("goodby")
  end
  
  
  #describe "monkey patches to the react-rails gem" do
    
    #it "will pass along the prerender_options server_context object to the rendering engine" do
      #React::ServerRendering::SprocketsRenderer
      
      #def render(component_name, props, prerender_options)
        # grab prerender options... if its a hash and contains server_context: then @context[:server_context] = the server context... 
        # make sure we are using the rubyracer or compatible
        # then if :static is in the options hash change prerender-options to :static
        # call the original render method
        # pass prerender: :static to use renderToStaticMarkup
        #react_render_method = if prerender_options == :static
        #    "renderToStaticMarkup"
        #  else
        #    "renderToString"
        #  end
      
      
      #we want to do a @context[:xxx] = some ruby instance
      #https://github.com/reactjs/react-rails/blob/1c03b00b8105c78fbf674abe34be4941084bede4/lib/react/server_rendering/sprockets_renderer.rb
      #react_component()
end