class AddColumnsToProductsTable < ActiveRecord::Migration
  def self.up
    add_column :products, :batch_code, :text
    add_column :products, :expiry_date, :text
    add_column :products, :notes, :string
  end

  def self.down
  end
end
