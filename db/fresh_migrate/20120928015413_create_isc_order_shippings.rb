class CreateIscOrderShippings < ActiveRecord::Migration
  def self.up
    create_table :isc_order_shippings do |t|

      t.timestamps
    end
  end

  def self.down
    #drop_table :isc_order_shippings
  end
end
