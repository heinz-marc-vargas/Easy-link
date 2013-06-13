class AddColumnsToOrdersToSuppliers < ActiveRecord::Migration
  def self.up
    add_column :orders_to_suppliers, :order_processing_id, :integer
    add_column :orders_to_suppliers, :asset_id, :integer
  end

  def self.down
    remove_column :orders_to_suppliers, :asset_id
    remove_column :orders_to_suppliers, :order_processing_id
  end
end
