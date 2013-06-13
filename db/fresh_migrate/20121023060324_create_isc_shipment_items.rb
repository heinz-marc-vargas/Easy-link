class CreateIscShipmentItems < ActiveRecord::Migration
  def self.up
    create_table :isc_shipment_items do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :isc_shipment_items
  end
end
