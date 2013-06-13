class AddIndexToIscShipmentData < ActiveRecord::Migration
  def self.up
    add_index :isc_shipment_data, :order_id
    add_index :isc_shipment_data, :ext_product_id
    add_index :isc_shipment_data, :tracking_num
  end

  def self.down
  end
end
