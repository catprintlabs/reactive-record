class AddRememberCreatedAtToUsers < ActiveRecord::Migration
  def change
    # Devise's Rememberable
    add_column :users, :remember_created_at, :datetime
  end
end
