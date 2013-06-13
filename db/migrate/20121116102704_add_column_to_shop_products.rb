class AddColumnToShopProducts < ActiveRecord::Migration
  def self.up
    add_column :shop_products, :default_supplier_id, :integer
  end

  def self.down
    remove_column :shop_products, :default_supplier_id
  end
end
