class CreateExternalSalesChannels < ActiveRecord::Migration
  def self.up
    create_table :external_sales_channels do |t|
      t.string :sales_channel_name

      t.timestamps
    end
  end

  def self.down
    drop_table :external_sales_channels
  end
end
