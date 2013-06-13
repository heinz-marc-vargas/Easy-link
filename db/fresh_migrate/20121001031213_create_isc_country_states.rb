class CreateIscCountryStates < ActiveRecord::Migration
  def self.up
    create_table :isc_country_states do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :isc_country_states
  end
end
