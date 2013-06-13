class CreateIscOrderAddresses < ActiveRecord::Migration
  def self.up
    create_table :isc_order_addresses do |t|
      t.timestamps
    end
  end

  def self.down
    #drop_table :isc_order_addresses
  end
end
