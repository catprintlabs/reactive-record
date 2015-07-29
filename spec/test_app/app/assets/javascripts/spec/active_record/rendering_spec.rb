require 'spec/spec_helper'
require 'user'

describe "integration with react" do
  
  after(:each) { ReactiveRecord::Base.reset_records! }

  
  it "reports two things being equal if they are the same underlying record"
  # pending - this depends on a full fetch cycle to be meaningful
  
  rendering("a simple find_by query") do
    User.find_by_email("mitch@catprint.com").email
  end.should_immediately_generate do 
    html == "mitch@catprint.com"
  end
  
  rendering("an attribute from the server") do
    User.find_by_email("mitch@catprint.com").first_name
  end.should_generate do
    puts "got first_name = #{html}"
    html == "Mitch"
  end
  
  rendering("find by two methods gives same object") do
    r1 = User.find_by_email("mitch@catprint.com")
    r2 = User.find_by_first_name("Mitch")
    r1.id
    r2.id
    if r1 == r2
      "SAME OBJECT" 
    else
      "NOT YET"
    end
  end.should_generate do  # failing because id is not tre
    puts "r1 == r2 #{html}"
    html == "SAME OBJECT"
  end
  
end
