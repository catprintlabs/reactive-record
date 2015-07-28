require 'shared/user'

class User < ActiveRecord::Base
  
  def as_json(*args)
    {name: "bozo"}
  end
  
end
