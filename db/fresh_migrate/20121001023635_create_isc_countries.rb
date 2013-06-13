class CreateIscCountries < ActiveRecord::Migration
  def self.up
    create_table :isc_countries do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :isc_countries
  end
end
