class TestData

  def initialize(string, times)
    @string = string
    @times = times
  end

  attr_accessor :string
  attr_accessor :times

  def big_string
    puts "calling big_string #{string} * #{times}"
    string * times
  end

end


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

  composed_of :data, :class_name => 'TestData', :allow_nil => true, :mapping => [['data_string', 'string'], ['data_times', 'times']]

  def name
    "#{first_name} #{last_name}"
  end

  # two examples of server side calculated attributes.  The second takes a parameter.
  # the first does not rely on an id, so can be used before the record is saved.

  if RUBY_ENGINE == 'opal'
  #  server_method :detailed_name  # because it does not take a parameter we need to tell system not to treat as an attribute (at least until we use schema.rb)
  else
    def detailed_name
      "#{first_name[0]}. #{last_name}#{' - '+email if email}" rescue ""
    end
  end

  def expensive_math(n)
    n+id.to_i
  end unless RUBY_ENGINE == 'opal'

end
