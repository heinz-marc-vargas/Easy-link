class CreateDatabaseConfigs < ActiveRecord::Migration
  def self.up
    create_table :database_configs do |t|
      t.integer "site_id"
      t.string "host", :limit => "30", :null => false
      t.string "database", :limit => "30", :null => false
      t.string "username", :null => false
      t.string "password", :null => false
      t.string "adapter", :limit => "15", :null => false, :default => "mysql2"
      t.string "encoding", :limit => "15", :null => false, :default => "utf8"
      t.integer "pool", :null => false, :default => 5
      t.integer "timeout", :null => false, :default => 5000
      t.integer "port", :null => true
      t.timestamps
    end
  end

  def self.down
    
  end
end
