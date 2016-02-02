require 'spec_helper'
#require 'user'
#require 'todo_item'
#require 'address'

describe "updating scopes" do

  # this spec needs some massive cleanup... the rendering tests continue to run... that needs to be fixed
  # the test are backwards

  # there are no test for nested scopes like User.todos.active for example which will certainly fail

  #before(:each) { React::IsomorphicHelpers.load_context; TodoItem.all = nil; puts "set all to nil thanks" }

  it "is true" do
    expect(true).to be_truthy
  end

  rendering("destroying records will cause a re-render") do
    puts "destroying [#{@starting_count}]"
    unless @starting_count
      TodoItem.all.last.title
      unless TodoItem.all.count == 1
        @starting_count = TodoItem.all.count
        puts "starting destroy count = #{@starting_count}"
        after(0.1) do
          TodoItem.all.last.destroy do
            TodoItem.all.last.destroy do
              TodoItem.all.last.destroy do
                TodoItem.all.last.destroy
              end
            end
          end
        end
      end
    end
    puts "destroy count = #{TodoItem.all.count}"
    #TodoItem.all.collect { |x| puts x.title }
    (TodoItem.all.count - (@starting_count || 100)).to_s
  end.should_generate do
    puts "testing delete #{html}"
    html == "-3"
  end

  rendering("adding a new matching record will add the record to a scope using full to_sync macro") do
    puts "add full to_sync"
    unless @starting_count
      unless TodoItem.active.first.title.loading?
        @starting_count = TodoItem.active.count
        puts "starting count = #{@starting_count}"
        after(0.1) do
          TodoItem.new(title: "another big mitch todo XXX").save
        end
      end
    end
    puts "TodoItem.active.count = #{TodoItem.active.count}"
    (TodoItem.active.count - (@starting_count || 100)).to_s
  end.should_generate do
    html == "1"
  end

  rendering("adding a new matching record will add the record to a scope using abbreviated to_sync macro") do
    puts "add abbr. sync"
    unless @starting_count
      unless TodoItem.important.first.description.loading?
        @starting_count = TodoItem.important.count
        after(0.1) do
          TodoItem.new(description: "another big mitch todo XXX").save
        end
      end
    end
    (TodoItem.important.count - (@starting_count || 100)).to_s
  end.should_generate do
    html == "1"
  end

  rendering("adding a new matching record will add the record to a scope using abbreviated to_sync macro") do
    puts "add abbr. sync"
    unless @starting_count
      unless TodoItem.important.first.description.loading?
        @starting_count = TodoItem.important.count
        after(0.1) do
          td = TodoItem.new(description: "another big mitch todo XXX")
          td.save do
            puts "after save, pushing #{TodoItem.important} << #{td}"
            #TodoItem.important << td
          end
        end
      end
    end
    (TodoItem.important.count - (@starting_count || 100)).to_s
  end.should_generate do
    puts "testing add abbr sync #{html}"
    html == "1"
  end


  rendering("adding a new record will cause a re-render") do
    puts "add record [#{@starting_count}]"
    unless @starting_count
      TodoItem.all.last.title
      unless TodoItem.all.count == 1
        @starting_count = TodoItem.all.count
        puts "starting_count = #{@starting_count}"

        after(0.1) do
          TodoItem.new(title: "play it again sam").save
        end
      end
    end
    puts "TodoItem.all.count = #{TodoItem.all.count}"
    (TodoItem.all.count - (@starting_count || 100)).to_s
  end.should_generate do
    html == "1"
  end

end
