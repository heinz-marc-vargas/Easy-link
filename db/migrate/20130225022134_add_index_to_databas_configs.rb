class AddIndexToDatabasConfigs < ActiveRecord::Migration
  def self.up
    add_index :database_configs, :site_id
  end

  def self.down
  end
end
