require 'spec_helper'
require 'user'

use_case "simple record update and save" do
  
  first_it "can find mitch" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find_by_email("mitch@catprint.com").first_name
    end.then_test do |first_name|
      expect(first_name).to be("Mitch")
    end
  end
  
  and_it "doesn't find mitch changed" do
    test {expect(User.find_by_email("mitch@catprint.com")).not_to be_changed}
  end
  
  and_it "doesn't find mitch saving" do
    test {expect(User.find_by_email("mitch@catprint.com")).not_to be_saving}
  end
  
  now_it "changes mitch to mitchell" do
    mitch = User.find_by_email("mitch@catprint.com")
    mitch.first_name = "Mitchell"
    test {expect(mitch.first_name).to eq("Mitchell")}
  end
    
  and_it "finds mitch to be changed"do
    test {expect(User.find_by_email("mitch@catprint.com")).to be_changed}
  end
  
  now_it "saves mitch" do 
    mitch = User.find_by_email("mitch@catprint.com")
    mitch.save.then_test {}
    expect(mitch).to be_saving
  end
  
  and_it "finds mitch not be changed" do
    test {expect(User.find_by_email("mitch@catprint.com")).not_to be_changed}
  end
  
  and_it "finds mitch not to be saving" do
    test {expect(User.find_by_email("mitch@catprint.com")).not_to be_saving}
  end
  
  now_it "reloads the record and finds the name is mitchell" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find_by_email("mitch@catprint.com").first_name
    end.then_test do |first_name|
      expect(first_name).to eq("Mitchell")
    end
  end
    
  now_it "changes the name back to mitch and saves it" do
    mitchell = User.find_by_email("mitch@catprint.com")
    mitchell.first_name = "Mitch"
    mitchell.save.then_test do
      expect(mitchell).not_to be_saving
    end
  end
    
end