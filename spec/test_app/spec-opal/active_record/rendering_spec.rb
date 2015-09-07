require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

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
    html == "SAME OBJECT"
  end

  rendering("a simple find_by query") do
    User.find_by_email("mitch@catprint.com").email
  end.should_immediately_generate do 
    html == "mitch@catprint.com"
  end
 
  rendering("an attribute from the server") do
    User.find_by_email("mitch@catprint.com").first_name
  end.should_generate do
    html == "Mitch"
  end
    
  rendering("a has_many association") do
    User.find_by_email("mitch@catprint.com").todo_items.collect do |todo|
      todo.title
    end.join(", ")
  end.should_generate do
    html == "a todo for mitch, another todo for mitch"
  end
  
  rendering("a belongs_to association from id") do
    TodoItem.find(1).user.email
  end.should_generate do
    html == "mitch@catprint.com"
  end
  
  rendering("a belongs_to association from an attribute") do
    User.find_by_email("mitch@catprint.com").todo_items.first.user.email
  end.should_generate do
    html == "mitch@catprint.com"
  end

  rendering("an aggregation") do
    User.find_by_email("mitch@catprint.com").address.city
  end.should_generate do
    html == "Rochester"
  end
  
  rendering("a record that is updated multiple times") do
    @record ||= User.new
    after(0.1) do
      @record.counter = (@record.counter || 0) + 1
    end
    after(1) do
      @record.all_done = true
    end unless @record.changed?
    if @record.all_done
      @record.all_done = nil
      "#{@record.counter}" 
    end
  end.should_generate do
    html == "2"
  end
    
end
