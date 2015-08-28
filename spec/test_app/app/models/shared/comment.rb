class Comment < ActiveRecord::Base

  belongs_to :user
  belongs_to :todo_item
  
  has_one :todo  # this is just so we can test null belongs_to relations

end