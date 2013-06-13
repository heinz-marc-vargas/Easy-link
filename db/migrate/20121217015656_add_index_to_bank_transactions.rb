class AddIndexToBankTransactions < ActiveRecord::Migration
  def self.up
    add_index :bank_transactions, :bank_id
    add_index :bank_transactions, :site_id
    add_index :bank_transactions, :other_sales_channel_id
    add_index :bank_transactions, :bank_date
  end

  def self.down
  end
end
