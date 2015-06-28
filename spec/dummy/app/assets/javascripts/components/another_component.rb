require 'user'
class AnotherComponent
  
  include React::Component
  
  export_component
  
  required_param :user, type: User
  
  def render
    div do
      "#{user.name}'s todos:".br
      ul do
        user.todo_items.each do |todo|
          li { TodoItemComponent(todo: todo) }
        end
      end
    end
  rescue Exception => e
    puts "exception #{e}"
  end
  
end