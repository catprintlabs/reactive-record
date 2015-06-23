class User < ActiveRecord::Base
  attr_accessible :email, :first_name, :last_name
  has_many :todo_items
  def name
    "#{first_name} #{last_name}"
  end
end