class AddColumnsToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :firstname, :string, :null => true
    add_column :users, :lastname, :string, :null => true
    add_column :users, :mobileno, :string, :null => true
  end

  def self.down
  end
end
