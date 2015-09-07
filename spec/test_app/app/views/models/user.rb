class User < ActiveRecord::Base
    
  def view_permitted?(attribute)
    return self == acting_user if acting_user
    super  # we call super to test if its there (just for the spec) not really the right way to do it, see comments or todo_items
  end
  
  has_many :todo_items
  has_many :comments
  has_many :commented_on_items, class_name: "TodoItem", through: :comments, source: :todo_item
  
  composed_of :address, :class_name => 'Address', :constructor => :compose, :mapping => Address::MAPPED_FIELDS.map {|f| ["address_#{f}", f] }
  
  def name
    "#{first_name} #{last_name}"
  end
  
 
end