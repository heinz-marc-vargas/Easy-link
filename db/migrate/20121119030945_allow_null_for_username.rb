class AllowNullForUsername < ActiveRecord::Migration
  def self.up
    change_column :users, :username, :string, :null => true
    change_column :users, :first_name, :string, :null => true
    change_column :users, :last_name, :string, :null => true
  end

  def self.down
  end
end
