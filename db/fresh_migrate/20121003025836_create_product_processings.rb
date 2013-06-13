class CreateProductProcessings < ActiveRecord::Migration
  def self.up
    create_table :product_processings do |t|
      t.integer :order_id
      t.integer :orderprodid
      t.integer :product_id
      t.integer :qty
      t.integer :supplier_id
      t.string :split_by_val
      t.integer :site_id

      t.timestamps
    end
  end

  def self.down
    drop_table :product_processings
  end
end
