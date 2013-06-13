class AddIndexToTables < ActiveRecord::Migration
  def self.up
    add_index :shop_products, :isc_product_id
    add_index :shop_products, :site_id

    add_index :order_processings, :parent_order_id
    add_index :orders_to_suppliers, :site_id
  end

  def self.down
  end
end
