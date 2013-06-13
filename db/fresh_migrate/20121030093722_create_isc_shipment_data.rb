class CreateIscShipmentData < ActiveRecord::Migration
  def self.up
    create_table :isc_shipment_data do |t|
      t.integer :order_id
      t.string :ship_flag
      t.string :ext_product_id
      t.integer :qty_shipped
      t.string :tracking_num
      t.datetime :ship_date
      t.string :file_name

      t.timestamps
    end
  end

  def self.down
    drop_table :isc_shipment_data
  end
end
