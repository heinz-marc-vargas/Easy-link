class AlterTableShopProduct < ActiveRecord::Migration
  def self.up
    change_column :shop_products, :isc_product_id, :integer, :null => true
  end

  def self.down
  end
end
