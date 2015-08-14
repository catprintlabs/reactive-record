class TodoItem < ActiveRecord::Base

  #attr_accessible :boolean, :complete, :description, :string, :text, :title
  belongs_to :user

  scope :find_string, ->(s) { where("title LIKE ? OR description LIKE ?", "%#{s}%", "%#{s}%") }

end
