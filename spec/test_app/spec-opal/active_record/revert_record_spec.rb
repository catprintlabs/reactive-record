require 'spec_helper'
#require 'user'
#require 'todo_item'

use_case "reverting records" do
  
  first_it "finds that the user Adam has not changed yet" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do 
      User.find_by_first_name("Adam")
    end.then_test do |user|
      expect(user).not_to be_changed
    end
  end
  
  and_it "creates a new todo which should be changed (because its new)" do
    test do
      new_todo = TodoItem.new({title: "Adam is not getting this todo"})
      expect(new_todo).to be_changed
    end
  end
  
  and_it "adds the todo to adam's todos and expects adam to change" do
    test do
      adam = User.find_by_first_name("Adam")
      adam.todo_items << TodoItem.find_by_title("Adam is not getting this todo")
      expect(adam).to be_changed
    end
  end
  
  and_it "will show that the new todo is still changed" do
    test do
      expect(TodoItem.find_by_title("Adam is not getting this todo")).to be_changed
    end
  end
  
  now_it "can be reverted and the todo will not be changed" do
    test do
      todo = TodoItem.find_by_title("Adam is not getting this todo")
      todo.revert
      expect(todo).not_to be_changed
    end
  end
  
  and_it "will not have changed adam" do
    test do
      expect(User.find_by_first_name("Adam")).not_to be_changed
    end
  end
  
  now_it "is time to test going the other way, lets give adam a todo again" do
    test do
      new_todo = TodoItem.new({title: "Adam is still not getting this todo"})
      adam = User.find_by_first_name("Adam")
      adam.todo_items << new_todo
      expect(adam).to be_changed
    end
  end  
  
  and_it "adam can be reverted" do
    test do
      adam = User.find_by_first_name("Adam")
      adam.revert
      expect(adam).not_to be_changed
    end
  end
  
  and_it "finds the todo is still changed" do
    test do
      expect(TodoItem.find_by_title("Adam is still not getting this todo")).to be_changed
    end
  end
  
end
