require 'comment'
require 'user'

class TodoItem < ActiveRecord::Base

  #attr_accessible :boolean, :complete, :description, :string, :text, :title
  belongs_to :user
  has_many :comments
  has_many :commenters, class_name: User, through: :comments, source: :user
  belongs_to :comment # just so we can test an empty belongs_to relationship

  scope :find_string, ->(s) { where("title LIKE ? OR description LIKE ?", "%#{s}%", "%#{s}%") }

end
