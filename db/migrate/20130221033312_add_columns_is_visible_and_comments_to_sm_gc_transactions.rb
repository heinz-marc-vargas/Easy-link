class AddColumnsIsVisibleAndCommentsToSmGcTransactions < ActiveRecord::Migration
  def self.up
    #add_column :sm_gc_transaction, :is_visible, :boolean, :null => true
    #add_column :sm_gc_transaction, :notes, :text, :null => true
  end

  def self.down
  end
end
