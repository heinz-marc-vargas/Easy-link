class CreateSmGcTransactions < ActiveRecord::Migration
  def self.up
    create_table :sm_gc_transactions do |t|

      t.timestamps
    end
  end

  def self.down
    #drop_table :sm_gc_transactions
  end
end
