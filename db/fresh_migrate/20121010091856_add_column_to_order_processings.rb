class AddColumnToOrderProcessings < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :split_flag, :string, :null => true
  end

  def self.down
  end
end
