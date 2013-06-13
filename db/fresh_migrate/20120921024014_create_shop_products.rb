class CreateShopProducts < ActiveRecord::Migration
  def self.up
    create_table :shop_products do |t|
      t.integer :supplier_id
      t.integer :product_id
      t.integer :site_id
      t.integer :isc_product_id
      t.integer :bundle_qty
      t.timestamps
    end
  end

  def self.down
    
  end
end
