class AddOcversionToOrderProcessing < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :oc_version, :integer, :default => 1
  end

  def self.down
    remove_column :order_processings, :oc_version
  end
end
