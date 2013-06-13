class AddColumnToOrdersToSuppliers < ActiveRecord::Migration
  def self.up
    add_column :orders_to_suppliers, :order_processing_id, :integer
  end

  def self.down
  end
end
