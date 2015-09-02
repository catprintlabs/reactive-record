class Comment < ActiveRecord::Base
  
  def create_permitted?
    !acting_user or user_is? acting_user
  end
  
  def destroy_permitted?
    !acting_user or user_is? acting_user
  end

  belongs_to :user
  belongs_to :todo_item
  
  has_one :todo, -> {}, class_name: "TodoItem"  # this is just so we can test scopes params and null belongs_to relations

end