class AddColumnsToOrderProcessings < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :isc_product_id, :integer
    add_column :order_processings, :item_name, :string
    add_column :order_processings, :item_sku, :string
    add_column :order_processings, :item_id, :integer
  end

  def self.down
    remove_column :order_processings, :item_id
    remove_column :order_processings, :item_sku
    remove_column :order_processings, :item_name
    remove_column :order_processings, :isc_product_id
  end
end
