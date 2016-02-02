require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

use_case "reading and writting enums" do

  first_it "can change the enum and read it back" do
    React::IsomorphicHelpers.load_context
    set_acting_user "super-user"
    user = User.find(1)
    user.test_enum = :no
    user.save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find(1).test_enum
      end.then_test do |test_enum|
        expect(test_enum).to eq(:no)
      end
    end
  end

  now_it "can set it back" do
    React::IsomorphicHelpers.load_context
    set_acting_user "super-user"
    user = User.find(1)
    user.test_enum = :yes
    user.save.then do
      React::IsomorphicHelpers.load_context
      ReactiveRecord.load do
        User.find(1).test_enum
      end.then_test do |test_enum|
        expect(test_enum).to eq(:yes)
      end
    end
  end



  and_it "can change it back" do
    user = User.find(1)
    user.test_enum = :yes
    user.save.then_test do |success|
      expect(success).to be_truthy
    end
  end

end
