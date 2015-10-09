require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

use_case "using non-ar aggregations" do

  first_it "is time to create a new user and add some data to it" do
    React::IsomorphicHelpers.load_context
    test { expect(User.new(first_name: "Data", data: TestData.new("hello", 3)).data.big_string).to eq("hellohellohello") }
  end

  and_it "can be saved and restored" do
    User.find_by_first_name("Data").save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find_by_first_name("Data").data
      end.then_test do |data|
        expect(data.big_string).to eq("hellohellohello")
      end
    end
  end

  now_it "is time to change it, and force the save" do
    user = User.find_by_first_name("Data")
    user.data.string = "goodby"
    user.save(force: true).then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find_by_first_name("Data").data
      end.then_test do |data|
        expect(data.big_string).to eq("goodbygoodbygoodby")
      end
    end
  end

  now_it "is time to change the value completely and save it (no force needed)" do
    user = User.find_by_first_name("Data")
    user.data = TestData.new("the end", 1)
    user.save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find_by_first_name("Data").data
      end.then_test do |data|
        expect(data.big_string).to eq("the end")
      end
    end
  end

  now_it "is time to delete the value and see if returns nil after saving" do
    user = User.find_by_first_name("Data")
    user.data = nil
    user.save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find_by_first_name("Data").data
      end.then_test do |data|
        expect(data).to be_nil
      end
    end
  end

  now_it "is time to delete our user" do
    User.find_by_first_name("Data").destroy.then_test do
      expect(User.find_by_first_name("Data")).to be_destroyed
    end
  end

  now_it "is time to see to make sure a nil aggregate that has never had a value returns nil" do
    ReactiveRecord.load do
      User.find_by_email("mitch@catprint.com").data
    end.then_test do |data|
      expect(data).to be_nil
    end
  end

end
