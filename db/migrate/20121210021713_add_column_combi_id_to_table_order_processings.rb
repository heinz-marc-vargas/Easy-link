class AddColumnCombiIdToTableOrderProcessings < ActiveRecord::Migration
  def self.up
    add_column :order_processings, :combi_id, :integer
    add_column :order_processings, :supplier_ids, :string
  end

  def self.down
  end
end
