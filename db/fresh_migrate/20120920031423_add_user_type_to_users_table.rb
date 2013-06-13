class AddUserTypeToUsersTable < ActiveRecord::Migration
  def self.up
    add_column :users, :usertype, :string, :null => true
  end

  def self.down
    
  end
end
