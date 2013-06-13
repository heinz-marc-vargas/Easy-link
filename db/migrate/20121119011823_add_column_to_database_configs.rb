class AddColumnToDatabaseConfigs < ActiveRecord::Migration
  def self.up
    add_column :database_configs, :port, :integer
  end

  def self.down
    remove_column :database_configs, :port
  end
end
