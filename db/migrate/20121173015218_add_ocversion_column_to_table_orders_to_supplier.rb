class AddOcversionColumnToTableOrdersToSupplier < ActiveRecord::Migration
  def self.up
    add_column :orders_to_suppliers, :oc_version, :integer, :null => true
  end

  def self.down
    remove_column :orders_to_suppliers, :oc_version
  end
end
