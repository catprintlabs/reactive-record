require 'opal-react'

class TodoItemComponent
  
  include React::Component
    
  required_param :todo
  
  before_mount do 
    puts "hey a todo item is being mounted with #{todo}"
  end
  
  after_mount do
    begin
      puts "after mounting"
    #after(0.0001) { 
    puts "Im telling him to load? #{@loading}"; WhileLoading.loading! @loading
    #}
  rescue Exception => e
    puts e
  end
  end
  
  after_update do
    begin
      puts "after updateeeeee (#{@loading})"
    #after(0.0001) { 
    puts "Im telling him to load? #{@loading}"; WhileLoading.loading! @loading
    #}
  rescue Exception => e
    puts e
  end
  end
  
  def render
    @loading = false;
    puts "rendering todo item #{todo}"
    div do
      "Title: #{todo.title}".br; "Description #{todo.description}".br; "User #{todo.user.name}"
    end.while_loading_show { puts "hey still loading";  @loading = true; "baz..." }.tap { puts "all done rendering item #{@loading}"}
  rescue Exception => e
    div do
      "errorzzz: #{e.message}".br
      e.backtrace.each { |line| line.br }
    end
  end
  
end
