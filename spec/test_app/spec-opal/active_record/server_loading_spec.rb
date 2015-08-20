require 'spec_helper'
require 'user'
require 'todo_item'

use_case "server loading edge cases" do
  
  first_it "knows a targets owner before loading" do
    React::IsomorphicHelpers.load_context
    test { expect(User.find_by_email("mitch@catprint.com").todo_items.first.user.email).to eq("mitch@catprint.com") }
  end
  
  and_it "will get the todo with no user" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do 
      [] # just fail for now TodoItem.all.collect { |item| item.user.first_name }.compact.count
    end.then_test do |count|
      raise "test basically passes but runs forever because item.user keeps getting fetched because its nil - need to fix"
      expect(count).to eq(3)
    end
  end

end