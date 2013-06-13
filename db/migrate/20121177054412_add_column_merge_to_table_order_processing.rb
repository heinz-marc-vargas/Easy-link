class AddColumnMergeToTableOrderProcessing < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :merge_to, :integer, :null => true
  end

  def self.down
    remove_column :order_processings, :merge_to
  end
end
