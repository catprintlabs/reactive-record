require 'opal-react'
require 'user'
require 'reactive_record'

class TodosComponent
  
  include React::Component
  
  export_component
  
  #optional_param :initial_user_email
  required_param :users, type: [User]
  
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
    TodosMainComponent users: users
  rescue Exception => e
    puts "exception raised while rendering #{e}"
    div do
      "error: #{e.message}".br
      e.backtrace.each { |line| line.br }
    end
  end
  
end
