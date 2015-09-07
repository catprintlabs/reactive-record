require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

use_case "updating aggregations" do
  
  first_it "is time to make a new user" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do 
      User.find_by_first_name("Jon").id
    end.then_test do |id|
      expect(id).to be_empty
      React::IsomorphicHelpers.load_context
      jon = User.new({first_name: "Jon", last_name: "Weaver"})
    end
  end
  
  now_it "has a blank address" do
    test { expect(User.find_by_first_name("Jon").address.zip).to be_blank }
  end
  
  now_it "is time to update the address" do
    User.find_by_first_name("Jon").address.zip = "14609"
    test { expect(User.find_by_first_name("Jon").address.zip).to eq("14609") }
  end
  
  and_it "can be saved" do
    User.find_by_first_name("Jon").save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find_by_first_name("Jon").address.zip
      end.then_test do |zip|
        expect(zip).to eq("14609")
      end
    end
  end
  
  now_it "is time to assign a whole address at once" do
    user = User.find_by_first_name("Jon")
    user.address = Address.new({zip: "14622", city: "Rochester"})
    test { expect([user.address.zip, user.address.city]).to eq(["14622", "Rochester"]) }
  end
  
  now_it "is time to save the user again" do
    User.find_by_first_name("Jon").save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        [User.find_by_first_name("Jon").address.zip, User.find_by_first_name("Jon").address.city]
      end.then_test do |zip_and_city|
        expect(zip_and_city).to eq(["14622", "Rochester"])
      end
    end
  end
  
  now_it "is time to delete our user" do
    User.find_by_first_name("Jon").destroy.then_test do
      expect(User.find_by_first_name("Jon")).to be_destroyed
    end
  end
  
end
  