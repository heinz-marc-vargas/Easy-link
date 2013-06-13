class CreateBankTransactions < ActiveRecord::Migration
  def self.up
    create_table :bank_transactions do |t|
      t.integer :sequence_id
      t.date :bank_date
      t.decimal :transaction_amt
      t.decimal :balance
      t.string :customer_notes
      t.string :filename
      t.string :order_ids
      t.integer :site_id
      t.datetime :status_change_date
      t.string :staff_comments
      t.integer :bank_id

      t.timestamps
    end
  end

  def self.down
    drop_table :bank_transactions
  end
end
