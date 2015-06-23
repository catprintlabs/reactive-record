require 'opal-react'
require 'user'

class TodosComponent
  
  include React::Component
  
  export_component
  
  optional_param :initial_user_email
  required_param :users, type: [User]
  define_state :user, :user_email, :background_id, :background_id_input
  
  before_mount do
    user_email! initial_user_email
    user! User.find_by_email(initial_user_email) if initial_user_email
  end
  
  after_mount do
    puts "after mount"
   #  `debugger`
    nil
  end

  after_update do
    puts "after update"
    if user
      #  `debugger` 
      nil
    end
  end
  
  def render
    puts "rendering todos"
    div do
      div do
      "I am a dummy div".span
      end.tap { |me| me.delete if user }
      table do
        tr { "name".td; "email".td; "number of todos".td}
        users.each do |user| 
          tr {user.name.td; user.email.td; user.todo_items.count.to_s.td  }
        end
        tr { "the last row".td(col_span: 3)}
      end #.while_loading_show { div { "i'm a div while loading"} } #.while_loading {""} #while_loading_show(style: {display: :none}.to_n)
      div do 
        "Todos for ".span
        input(type: :text, value: user_email, placeholder: "enter a user's email").
          on(:change) { |e| user_email! e.target.value }.
          on(:key_up) { |e| user! User.find_by_email(user_email) if e.key_code == 13 }
      end 
      WhileLoading(display: "loading...") do
        div do
        puts "deciding the right kind of todo item listing to generate"
        if !user
          "type in an email and hit return to find a user"
        elsif user.not_found?
          "#{user.email} does not exist, try another email"
        elsif user.todo_items.count == 0
          "No Todos Yet"
        else
          user.todo_items.each do |todo| 
            TodoItemComponent(todo: todo) 
          end
          puts "what the heck????"
          div {" some stuff "}
        end
      end
      end.tap { |e| puts "completed generating? the todo item div #{e}"}
    end.while_loading_show { "" }
  rescue Exception => e
    puts "exception raised while rendering #{e}"
    div do
      "error: #{e.message}".br
      e.backtrace.each { |line| line.br }
    end
  end
  
end
