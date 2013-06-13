class CreateTempProductsStocks < ActiveRecord::Migration
  def self.up
    create_table :temp_products_stocks do |t|
      t.string :name
      t.integer :supplier_id
      t.string :ext_product_id
      t.integer :qty
      t.date :expiry_date
      t.string :batch_code
      t.string :filename

      t.timestamps
    end
  end

  def self.down
  end
end
