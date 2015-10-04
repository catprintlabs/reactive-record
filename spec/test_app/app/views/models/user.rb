class User < ActiveRecord::Base

  def view_permitted?(attribute)
    return self == acting_user if acting_user
    super  # we call super to test if its there (just for the spec) not really the right way to do it, see comments or todo_items
  end

  has_many :todo_items
  has_many :comments
  has_many :commented_on_items, class_name: "TodoItem", through: :comments, source: :todo_item

  composed_of :address,  :class_name => 'Address', :constructor => :compose, :mapping => Address::MAPPED_FIELDS.map {|f| ["address_#{f}", f] }
  composed_of :address2, :class_name => 'Address', :constructor => :compose, :mapping => Address::MAPPED_FIELDS.map {|f| ["address2_#{f}", f] }

  def name
    "#{first_name} #{last_name}"
  end

  # two examples of server side calculated attributes.  The second takes a parameter.
  # the first does not rely on an id, so can be used before the record is saved.

  def detailed_name
    "#{first_name[0]}. #{last_name} #{' - '+email if email}"
  end unless RUBY_ENGINE == 'opal'

  def expensive_math(n)
    n+id.to_i
  end unless RUBY_ENGINE == 'opal'

end
