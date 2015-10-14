require 'spec_helper'

use_case "virtual attributes" do

  first_it "can call a virtual method on the server" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find(1).expensive_math(13)
    end.then_test { |virtual_answer| expect(virtual_answer).to eq(14) }
  end

  and_it "can call a virtual method on a new model on the server" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    ReactiveRecord.load do
      new_user.expensive_math(13)
    end.then_test { |virtual_answer| expect(virtual_answer).to eq(13) }
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
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("J. Schmoe - mitch@catprint.com") }
  end

  and_it "can call a simple virtual method on a new model on the server with data and an updated association" do
    React::IsomorphicHelpers.load_context
    new_user = User.new
    new_user.first_name = "Joe"
    new_user.last_name = "Schmoe"
    new_user.todo_items << TodoItem.new
    ReactiveRecord.load do
      new_user.detailed_name
    end.then_test { |virtual_answer| expect(virtual_answer).to eq("J. Schmoe") }
  end

end
