class WhileLoading 
  
  include React::Component
  
  export_state :loading
  
  required_param :display, type: String
  
  after_update do
    puts "!!!!!!!!!!!!!!!! while loading updated !!!!!!!!!!!!!!!!!"
  end
  
  def render
    if loading
      puts "loading! so I am displaying: #{display}"
      display
    else
      first_child = React::Element.new `self.native.props.children`
      puts "not loading so I am displaying #{first_child}"
      React::RenderingContext.push first_child
    end
  end
  
end
    