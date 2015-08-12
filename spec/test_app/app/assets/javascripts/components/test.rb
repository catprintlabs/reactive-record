require 'user'
require 'todo_item'

class Test

  include React::Component

  export_component

  def render
    user = User.find_by_email("mitch@catprint.com")
    div do
      "#{Time.now.to_s} #{user.first_name}".br
      "zip: #{user.address.zip}".br
      "todos: #{user.todo_items.collect { |todo| todo.title }.join(", ")}".br
    end
  end

end
