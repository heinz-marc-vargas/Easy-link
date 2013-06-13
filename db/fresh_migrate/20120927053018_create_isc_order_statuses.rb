class CreateIscOrderStatuses < ActiveRecord::Migration
  def self.up
    create_table :isc_order_statuses do |t|

      t.timestamps
    end
  end

  def self.down
    #drop_table :isc_order_statuses
  end
end