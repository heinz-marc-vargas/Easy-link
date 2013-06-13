class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.integer :supplier_id
      t.string  :ext_product_id
      t.integer :uid, :default => 0
      t.string  :name
      t.integer :stock
      t.integer :restock_threshold
      t.boolean :restock_notification_sent
      t.integer :creator_id, :null => true
      t.string  :creator_type, :null => true
      t.integer :site_id, :null => true
      t.timestamps
    end

    add_index :products, :supplier_id
    add_index :products, :ext_product_id

  end

  def self.down
    
  end
end
