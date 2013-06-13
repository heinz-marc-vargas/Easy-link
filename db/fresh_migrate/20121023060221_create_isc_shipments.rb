class CreateIscShipments < ActiveRecord::Migration
  def self.up
    create_table :isc_shipments do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :isc_shipments
  end
end
