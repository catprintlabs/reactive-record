require 'spec_helper'
require 'user'
require 'todo_item'

use_case "server loading edge cases" do
  
  first_it "knows a targets owner before loading" do
    React::IsomorphicHelpers.load_context
    test { expect(User.find_by_email("mitch@catprint.com").todo_items.first.user.email).to eq("mitch@catprint.com") }
  end
  
  and_it "can return a nil association" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      TodoItem.all.collect do |todo|
        todo.comment and todo.comment.comment
      end.compact
    end.then_test do |collection|
      expect(collection).to be_empty
    end
  end
  
  and_it "trims the association tree" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      TodoItem.all.collect do |todo|
        todo.user && todo.user.first_name
      end.compact
    end.then_test do |first_names|
      expect(first_names.count).to eq(3)
    end
  end

end