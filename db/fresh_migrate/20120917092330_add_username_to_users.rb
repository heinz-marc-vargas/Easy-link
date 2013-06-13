class AddUsernameToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :username, :string
  end

  def self.down
    
  end
end
