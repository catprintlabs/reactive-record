require 'spec/spec_helper'
require 'user'
require 'todo_item'
require 'address'

describe "integration with react" do
  
  before(:each) { React::IsomorphicHelpers.load_context }

  it "find by two methods will not give the same object until loaded" do
    r1 = User.find_by_email("mitch@catprint.com")
    r2 = User.find_by_first_name("Mitch")
    expect(r1).not_to eq(r2)
  end

  rendering("find by two methods gives same object once loaded") do
    r1 = User.find_by_email("mitch@catprint.com")
    r2 = User.find_by_first_name("Mitch")
    r1.id
    r2.id
    if r1 == r2
      "SAME OBJECT" 
    else
      "NOT YET"
    end
  end.should_generate do  
    puts "r1 == r2 #{html}"
    html == "SAME OBJECT"
  end
  
  rendering("a simple find_by query") do
    User.find_by_email("mitch@catprint.com").email
  end.should_immediately_generate do 
    html == "mitch@catprint.com"
  end
if false  
  rendering("an attribute from the server") do
    User.find_by_email("mitch@catprint.com").first_name
  end.should_generate do
    puts "got first_name = #{html}"
    html == "Mitch"
  end
    
  rendering("a has_many association") do
    User.find_by_email("mitch@catprint.com").todo_items.collect do |todo|
      todo.title
    end.join(", ")
  end.should_generate do
    puts "html = #{html}"
    html == "a todo for mitch, another todo for mitch"
  end
  
  rendering("a belongs_to association") do
    #User.find_by_email("mitch@catprint.com").todo_items.first.user.email
    TodoItem.find(1).user.email
  end.should_generate do
    puts "html = #{html}"
    html == "mitch@catprint.com"
  end
  
  rendering("a belongs_to association") do
    User.find_by_email("mitch@catprint.com").todo_items.first.user.email
  end.should_generate do
    puts "html = #{html}"
    html == "mitch@catprint.com"
  end
end
  rendering("an aggregation") do
    User.find_by_email("mitch@catprint.com").address.city
  end.should_generate do
    puts "html = #{html}"
    html == "Rochester"
  end
  
end
