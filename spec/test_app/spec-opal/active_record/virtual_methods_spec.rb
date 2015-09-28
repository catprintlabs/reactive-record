require 'spec_helper'

use_case "virtual attributes" do

  first_it "it can call a virtual method on the server" do
    React::IsomorphicHelpers.load_context
    ReactiveRecord.load do
      User.find(1).expensive_math(13)
    end.then_test { |virtual_answer| expect(virtual_answer).to eq(14) }
  end

end
