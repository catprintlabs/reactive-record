require 'spec_helper'
require 'user'


describe "dummy values" do
  
  it "fetches a dummy value" do
    expect(User.find_by_email("mitch@catprint.com").first_name.to_s.is_a?(String)).to be_truthy
  end
  
  it "can convert the value to a float" do
    expect(User.find_by_email("mitch@catprint.com").id.to_f.is_a?(Float)).to be_truthy
  end
  
  it "can convert the value to an int" do
    expect(User.find_by_email("mitch@catprint.com").id.to_i.is_a?(Integer)).to be_truthy
  end
  
end