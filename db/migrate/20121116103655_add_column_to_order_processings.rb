class AddColumnToOrderProcessings < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :parent_order_id, :integer
    add_column :order_processings, :orderprodid, :integer
    add_column :order_processings, :product_id, :string
    add_column :order_processings, :qty, :integer
    add_column :order_processings, :supplier_id, :string
    add_column :order_processings, :split_by_val, :integer
    add_column :order_processings, :site_id, :integer
    add_column :order_processings, :split_flag, :string
  end

  def self.down
    remove_column :order_processings, :split_flag
    remove_column :order_processings, :site_id
    remove_column :order_processings, :split_by_val
    remove_column :order_processings, :supplier_id
    remove_column :order_processings, :qty
    remove_column :order_processings, :product_id
    remove_column :order_processings, :orderprodid
    remove_column :order_processings, :parent_order_id
  end
end
