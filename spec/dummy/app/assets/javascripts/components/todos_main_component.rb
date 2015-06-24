class TodosMainComponent
  
  include React::Component
  
  required_param :users
  
  define_state :user, :user_email
  
  before_mount do
    #user_email! "mitch@catprint.com"
    user! User.find_by_email(user_email) if user_email
  end
  
  def render
    while_loading do
      div do
        table do
          tr { "name".td; "email".td; "number of todos".td}
          users.each do |user| 
            tr {user.name.td; user.email.td; user.todo_items.count.to_s.td  }
          end
          tr { "the last row".td(col_span: 3)}
        end
        div do 
          "Todos for ".span
          input(type: :text, value: user_email, placeholder: "enter a user's email").
            on(:change) { |e| user_email! e.target.value }.
            on(:key_up) { |e| user! User.find_by_email(user_email) if e.key_code == 13 }
        end
        while_loading do
          if !user
            "type in an email and hit return to find a user"
          elsif user.not_found?
            "#{user.email} does not exist, try another email"
          elsif user.todo_items.count == 0
            "No Todos Yet"
          else
            div do
              user.todo_items.each do |todo| 
                TodoItemComponent(todo: todo) 
              end
            end
          end
        end.show("searching...")
      end
    end
  end
  
end