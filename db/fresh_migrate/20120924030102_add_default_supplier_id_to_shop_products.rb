class AddDefaultSupplierIdToShopProducts < ActiveRecord::Migration
  def self.up
    add_column :shop_products, :default_supplier_id, :integer, :null => true
  end

  def self.down
  end
end
