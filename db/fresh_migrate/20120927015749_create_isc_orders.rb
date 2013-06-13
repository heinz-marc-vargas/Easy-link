class CreateIscOrders < ActiveRecord::Migration
  def self.up
    create_table :isc_orders do |t|
      t.timestamps
    end
  end

  def self.down
    
  end
end
