require 'spec_helper'
#require 'todo_item'
#require 'user'

use_case "many to many associations" do
  
  first_it "it is time to count some comments" do
    puts "firing up"
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do 
      TodoItem.find_by_title("a todo for mitch").comments.count
    end.then_test do |count|
      expect(count).to be(1)
    end
  end
  
  now_it "is time to see who made the comment" do
    ReactiveRecord.load do 
      TodoItem.find_by_title("a todo for mitch").comments.first.user.email
    end.then_test do |email|
      expect(email).to eq("adamg@catprint.com")
    end
  end
  
  now_it "is time to get it directly through the relationship" do
    ReactiveRecord.load do
      TodoItem.find_by_title("a todo for mitch").commenters.first.email
    end.then_test do |email|
      expect(email).to eq("adamg@catprint.com")
    end
  end
  
end