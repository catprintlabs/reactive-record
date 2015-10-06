require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

use_case "updating associations" do

  first_it "is time to make a new user" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find_by_first_name("Jon").id
    end.then_test do |id|
      expect(id).to be_nil
      React::IsomorphicHelpers.load_context
      jon = User.new({first_name: "Jon", last_name: "Weaver"})
    end
  end

  now_it "has no todo items" do
    jon =  User.find_by_first_name("Jon")
    test { expect(jon.todo_items).to be_empty }
  end

  now_it "is time to give the user a todo" do
    jon = User.find_by_first_name("Jon")
    jon.todo_items << (item = TodoItem.new({title: "Jon's first todo!"}))
    test { expect(jon.todo_items.count).to be(1) }
  end

  now_it "will save everything" do
    jon = User.find_by_first_name("Jon")
    jon.save.while_waiting { expect(jon).to be_saving }
  end

  now_it "will have one todo item in the data base" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find_by_first_name("Jon").todo_items.count
    end.then_test do | count |
      expect(count).to be(1)
    end
  end

  and_it "will have the correct titles" do
    ReactiveRecord.load do
      User.find_by_first_name("Jon").todo_items.collect { | todo | todo.title }
    end.then_test do | titles |
      expect(titles).to eq(["Jon's first todo!"])
    end
  end

  and_it "can by found by its owner" do
    todo = TodoItem.find_by_title("Jon's first todo!")
    test { expect(todo.user.first_name).to eq("Jon") }
  end

  now_it "can be moved to another owner, and it will be removed from the old owner" do
    TodoItem.find_by_title("Jon's first todo!").user = User.new({first_name: "Jan", last_name: "VanDuyn"})
    test { expect(User.find_by_first_name("Jon").todo_items).to be_empty }
  end

  and_it "will belong to the new owner" do
    test { expect(User.find_by_first_name("Jan").todo_items.all == [TodoItem.find_by_title("Jon's first todo!")]).to be_truthy }
  end

  now_it "can be saved and it will remember its new owner" do
    TodoItem.find_by_title("Jon's first todo!").save do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        TodoItem.find_by_title("Jon's first todo!").user.first_name
      end.then_test do | first_name |
        expect(first_name).to be("Jan")
      end
    end
  end

  and_it "will have been removed from Jon's todos" do
    ReactiveRecord.load do
      User.find_by_first_name("Jon").todo_items.all
    end.then_test do | todos |
      expect(todos).to be_empty
    end
  end

  now_it "can be assigned to nobody" do
    todo = TodoItem.find_by_title("Jon's first todo!")
    todo.user = nil
    todo.save do | success |
      test { expect(success).to be_truthy }
    end
  end

  and_it "will not belong to Jan anymore" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      TodoItem.find_by_title("Jon's first todo!").user # load the todo in prep for the next test
      User.find_by_first_name("Jan").todo_items.all.count
    end.then_test do |count|
      expect(count).to be(0)
    end
  end

  and_it "can be reassigned to Jan" do
    todo = TodoItem.find_by_title("Jon's first todo!")
    todo.user = User.find_by_first_name("Jan")
    todo.save do | success |
      test { expect(success).to be_truthy }
    end
  end

  now_it "can be deleted" do
    User.find_by_first_name("Jan").todo_items.first.destroy.then_test do
      expect(User.find_by_first_name("Jan").todo_items).to be_empty
    end
  end

  and_it "won't exist" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      TodoItem.find_by_title("Jon's first todo!").id
    end.then_test do | id |
      expect(id).to be_nil
    end
  end

  now_it "is time to create a todo that belongs to nobody" do
    nobodys_business = TodoItem.new({title: "round to it"})
    nobodys_business.save.then_test do
      expect(nobodys_business).to be_saved
    end
  end

  and_it "can be reloaded" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      TodoItem.find_by_title("round to it").id
    end.then_test do |id|
      expect(id).not_to be_nil
    end
  end

  and_it "can be deleted of course" do
    TodoItem.find_by_title("round to it").destroy.then_test do
      expect(TodoItem.find_by_title("round to it")).to be_destroyed
    end
  end

  and_it "is time to delete Jan" do
    User.find_by_first_name("Jan").destroy.then_test do
      expect(User.find_by_first_name("Jan")).to be_destroyed
    end
  end

  and_it "is time to delete Jon" do
    User.find_by_first_name("Jon").destroy.then_test do
      expect(User.find_by_first_name("Jon")).to be_destroyed
    end
  end

end
