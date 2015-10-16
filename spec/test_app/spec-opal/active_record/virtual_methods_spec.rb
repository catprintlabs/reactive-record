require 'spec_helper'

use_case "virtual attributes" do

  first_it "can call a virtual method on the server" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find(1).expensive_math(5)
    end.then_test { |virtual_answer| expect(virtual_answer).to eq(25) }
  end

  and_it "can call a virtual method on a new model on the server" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    ReactiveRecord.load do
      new_user.expensive_math(4)
    end.then_test { |virtual_answer| expect(virtual_answer).to eq(16) }
  end

  and_it "can call a simple virtual method on a new model on the server" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    ReactiveRecord.load do
      new_user.detailed_name
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("") }
  end

  and_it "can call a simple virtual method on a new model on the server with data" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    new_user.first_name = "Joe"
    new_user.last_name = "Schmoe"
    ReactiveRecord.load do
      new_user.detailed_name
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("J. Schmoe") }
  end

  and_it "can call a simple virtual method on an existing updated model on the server" do
    React::IsomorphicHelpers.load_context
    user = User.find(1)
    user.first_name = "Joe"
    user.last_name = "Schmoe"
    ReactiveRecord.load do
      user.detailed_name
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("J. Schmoe - mitch@catprint.com (2 todos)") }
  end

  and_it "can call a simple virtual method on a new model on the server with data and an updated association" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    new_user.first_name = "Joe"
    new_user.last_name = "Schmoe"
    todo_item = TodoItem.new
    todo_item.title = "Mongo DB"
    new_user.todo_items << TodoItem.new #todo_item
    ReactiveRecord.load do
      new_user.detailed_name
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("J. Schmoe (1 todo)") }
  end

end
