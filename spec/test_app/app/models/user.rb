class User < ActiveRecord::Base
  
  def as_json(*args)
    {name: "bozo"}
  end
  
  validates :email, format: {with: /\@.+\./}, :allow_nil => true
  
  def name=(val)  # this is here to test ability to save changes to this type of psuedo attribute
    val = val.split(" ")
    self.first_name = val[0]
    self.last_name = val[1]
  end
  
end


