require 'spec/spec_helper'
require 'user'

describe "integration with react" do

  
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
    puts "html = #{html}"
    html.downcase == "mitch"
  end
  
end
