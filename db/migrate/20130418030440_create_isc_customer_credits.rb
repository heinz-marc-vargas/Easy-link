class CreateIscCustomerCredits < ActiveRecord::Migration
  def self.up
    create_table :isc_customer_credits do |t|
      t.timestamps
    end
  end

  def self.down
    #drop_table :isc_customer_credits
  end
end
