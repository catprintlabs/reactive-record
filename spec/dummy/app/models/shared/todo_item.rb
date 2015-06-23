class TodoItem < ActiveRecord::Base
  
  attr_accessible :boolean, :complete, :description, :string, :text, :title
  belongs_to :user
  
end