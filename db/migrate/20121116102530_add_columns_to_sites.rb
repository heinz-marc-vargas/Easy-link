class AddColumnsToSites < ActiveRecord::Migration
  def self.up
    add_column :sites, :enabled, :boolean, :default => true
  end

  def self.down
    remove_column :sites, :enabled
  end
end
