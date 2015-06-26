require 'opal-react'

class TodoItemComponent
  
  include React::Component
    
  required_param :todo
  
  def render
    div do
      "Title: #{todo.title}".br; "Description #{todo.description}".br; "User #{todo.user.name}"
    end
  rescue Exception => e
    div do
      "errorzzz: #{e.message}".br
      e.backtrace.each { |line| line.br }
    end
  end
  
end
