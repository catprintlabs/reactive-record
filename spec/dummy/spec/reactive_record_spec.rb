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

require 'action_view'
require 'active_support'
require 'react-rails'

class Hash
  # Returns a hash that includes everything but the given keys.
  #   hash = { a: true, b: false, c: nil}
  #   hash.except(:c) # => { a: true, b: false}
  #   hash # => { a: true, b: false, c: nil}
  #
  # This is useful for limiting a set of parameters to everything but a few known toggles:
  #   @person.update(params[:person].except(:admin))
  def except(*keys)
    dup.except!(*keys)
  end

  # Replaces the hash without the given keys.
  #   hash = { a: true, b: false, c: nil}
  #   hash.except!(:c) # => { a: true, b: false}
  #   hash # => { a: true, b: false }
  def except!(*keys)
    keys.each { |key| delete(key) }
    self
  end
end

describe ReactiveRecord do
  it "has a version" do
    expect(ReactiveRecord::VERSION).to be_truthy
  end
  
  it "can communicate with a react component during server rendering" do
    h = {a: 1, b: 2}
    h.except! :b
    helper = ActionView::Base.new.extend(React::Rails::ViewHelper)
    test_context = TestContext.new
    html = helper.react_component('Callback', {tell_me: "goodby"}, prerender: true) #{server_context: test_context})
    expect(html).to eq('<span>1</span>')
    expect(test_context.last_hello_data).to eq("goodby")
  end
end