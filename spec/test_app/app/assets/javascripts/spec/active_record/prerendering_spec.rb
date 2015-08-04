require 'spec/spec_helper'
require 'user'
require 'todo_item'
require 'address'
require 'components/test'

describe "prerendering" do
  
  before(:each) do
    if false
    `window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData = undefined` rescue nil
    container = Element[Document.body].append('<div></div>').children.last
    complete = lambda do 
      puts "doing the complete thing"
      puts "about to load context"
      React::IsomorphicHelpers.load_context
      puts "context loaded"
      `debugger`
      nil
      #element = React.create_element(Test)
      #React.render(element, container)
    end
    `container.load('/test', complete)`
end
  end

  it "passes" do
    expect(true).to be_truthy
  end
  
  it "will not return an id before preloading" do
    expect(User.find_by_email("mitch@catprint.com").id).not_to eq(1)
  end
  
  async "preloaded the records" do
    `window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData = undefined` rescue nil
    container = Element[Document.body].append('<div></div>').children.last
    complete = lambda do
      React::IsomorphicHelpers.load_context
      run_async do
        mitch = User.find_by_email("mitch@catprint.com")
        expect(mitch.id).to eq(1)
        expect(mitch.first_name).to eq("Mitch")
        expect(mitch.todo_items.first.title).to eq("a todo for mitch")
        expect(mitch.address.zip).to eq("14617")
      end
    end
    `container.load('/test', complete)`
  end
  
  async "does not preload everything" do
    `window.ClientSidePrerenderDataInterface.ReactiveRecordInitialData = undefined` rescue nil
    container = Element[Document.body].append('<div></div>').children.last
    complete = lambda do
      React::IsomorphicHelpers.load_context
      run_async do
        expect(User.find_by_email("mitch@catprint.com").last_name).to eq("")
      end
    end
    `container.load('/test', complete)`
  end
  
if false

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
  
  rendering("an aggregation") do
    User.find_by_email("mitch@catprint.com").address.city
  end.should_generate do
    puts "html = #{html}"
    html == "Rochester"
  end

end
end
