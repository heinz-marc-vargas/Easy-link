class AddOtherSalesChannelIdColumnToBankTransaction < ActiveRecord::Migration
  def self.up
    add_column :bank_transactions, :other_sales_channel_id, :integer
  end

  def self.down
    remove_column :bank_transactions, :other_sales_channel_id
  end
end
