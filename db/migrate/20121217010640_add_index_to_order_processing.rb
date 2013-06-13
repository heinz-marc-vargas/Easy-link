class AddIndexToOrderProcessing < ActiveRecord::Migration
  def self.up
    add_index :order_processings, :order_id
    add_index :order_processings, :oc_version
    add_index :order_processings, :site_id
    add_index :order_processings, :orderprodid
  end

  def self.down
  end
end
