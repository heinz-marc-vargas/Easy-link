class AddColumnsToSuppliersTable < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :status, :boolean
  end

  def self.down
  end
end
