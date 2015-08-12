require 'address'

class User < ActiveRecord::Base
  
  #attr_accessible :email, :first_name, :last_name
  
  has_many :todo_items
  
  composed_of :address, :class_name => 'Address', :constructor => :compose, :mapping => Address::MAPPED_FIELDS.map {|f| ["address_#{f}", f] }
  
  def name
    "#{first_name} #{last_name}"
  end
 
end