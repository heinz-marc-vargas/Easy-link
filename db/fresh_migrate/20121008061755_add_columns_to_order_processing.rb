class AddColumnsToOrderProcessing < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :parent_order_id, :string, :limit => 11, :null => true
    add_column :order_processings, :orderprodid, :string, :limit => 11
    add_column :order_processings, :product_id, :string, :limit => 11
    add_column :order_processings, :qty, :integer
    add_column :order_processings, :supplier_id, :string, :limit => 3
    add_column :order_processings, :split_by_val, :integer, :null => true
    add_column :order_processings, :site_id, :integer
  end

  def self.down
  end
end
