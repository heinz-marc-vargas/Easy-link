class CreateOrdersToSuppliers < ActiveRecord::Migration
  def self.up
    create_table :orders_to_suppliers do |t|
      t.integer :site_id
      t.integer :order_id
      t.string :split_flag, :limit => 3
      t.string :supplier_ids, :limit => 512
      t.string :product_ids, :limit => 512
      t.string :order_string, :limit => 1024
      t.text :response_status
      t.integer :sent_to_wm, :limit => 4, :default => 0

      t.timestamps
    end
  end

  def self.down
  end
end
