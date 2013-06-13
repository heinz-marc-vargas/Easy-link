class AddSitesIdColumnToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :sites_id, :string
  end

  def self.down
    remove_column :users, :sites_id
  end
end
