require 'spec_helper'
require 'user'
require 'todo_item'

use_case "can scope models" do

  first_it "scopes todos by string" do
    ReactiveRecord.load do
      User.find_by_email("mitch@catprint.com").todo_items.find_string("mitch").first.title
    end.then_test do |title|
      expect(title).to be("a todo for mitch")
    end
  end

end
