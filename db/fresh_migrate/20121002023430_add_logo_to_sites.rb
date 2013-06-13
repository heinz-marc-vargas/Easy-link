class AddLogoToSites < ActiveRecord::Migration
  def self.up
    add_column :sites, :logo, :string
  end

  def self.down
    remove_column :sites, :logo
  end
end
