class CreateIscCustomers < ActiveRecord::Migration
  def self.up
    create_table :isc_customers do |t|
      t.timestamps
    end
  end

  def self.down
    #drop_table :isc_customers
  end
end
